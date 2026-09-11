"""Compile all background-runner title sources and both real log descriptions.

Only localization bundle lookup is redirected. This is a native excerpt test,
not a real session/command-execution test; no shell or user settings are touched.
"""
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class PTYTriggerDiagnosticLocalizationTests(unittest.TestCase):
    call_sites = {
        "smart": ("sources/TerminalView/PTYTextView+ARC.m",
                  "runCommandInBackground:(NSString *)command {",
                  "ui.terminalview.ptytextview_arc.smart_selection_action"),
        "url": ("sources/SemanticHistory/iTermURLActionHelper.m",
                "- (void)launchURLHandlerCommand:(NSString *)command {",
                "ui.semantichistory.itermurlactionhelper.url_handler"),
    }
    titles = {"trigger": "Run Command Trigger", "smart": "Smart Selection Action", "url": "URL Handler"}
    notification_keys = {
        "trigger": "ui.ptysession.ptysession.run_command_trigger_failed_notification_title",
        "smart": "ui.terminalview.ptytextview_arc.smart_selection_action_failed_notification_title",
        "url": "ui.semantichistory.itermurlactionhelper.url_handler_command_failed_notification_title",
    }

    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="iterm2-trigger-diagnostic-")
        cls.addClassCleanup(temporary.cleanup)
        cls.directory = Path(temporary.name)
        source = (ROOT / "sources/PTYSession/PTYSession.m").read_text(encoding="utf-8")
        method = source.split("- (void)triggerSideEffectRunBackgroundCommand:", 1)[1].split("\n}", 1)[0]
        start = method.index("runner.command =")
        end = method.index("runner.shell =", start)
        (cls.directory / "trigger-title.inc").write_text(method[start:end], encoding="utf-8")
        for lane, (path, signature, _) in cls.call_sites.items():
            caller = (ROOT / path).read_text(encoding="utf-8")
            body = caller.split(signature, 1)[1].split("\n}", 1)[0]
            title = body.split("title:", 1)[1].split("];", 1)[0]
            (cls.directory / f"{lane}-title.inc").write_text(title, encoding="utf-8")
            notification = body[body.index("runner.notificationTitle ="):body.index("[runner run];")]
            (cls.directory / f"{lane}-notification.inc").write_text(notification, encoding="utf-8")
        backend = (ROOT / "sources/CommandExecution/iTermBackgroundCommandRunner.m").read_text(encoding="utf-8")
        initializer = "- (instancetype)initWithCommand:" + backend.split(
            "- (instancetype)initWithCommand:", 1)[1].split("\n}", 1)[0] + "\n}\n"
        (cls.directory / "runner-init.inc").write_text(initializer, encoding="utf-8")
        for selector, filename in (("description", "runner-description.inc"),
                                   ("redactedDescription", "runner-redacted-description.inc")):
            signature = f"- (NSString *){selector} {{"
            body = backend.split(signature, 1)[1].split("\n}", 1)[0]
            (cls.directory / filename).write_text(signature + body + "\n}\n", encoding="utf-8")
        cls.probe = cls.directory / "trigger-title-probe"
        compiled = subprocess.run(
            ["xcrun", "clang", "-fobjc-arc", "-Wall", "-Wextra", "-Werror",
             "-framework", "Foundation", "-I", str(cls.directory),
             str(ROOT / "tests/pty_trigger_title_probe.m"), "-o", str(cls.probe)],
            capture_output=True, text=True, timeout=60,
        )
        if compiled.returncode:
            raise AssertionError(compiled.stdout + compiled.stderr)
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text(encoding="utf-8"))["strings"]
        cls.notifications = {}
        prefixes = ("ui.ptysession.ptysession.run_command_trigger",
                    *(site[2] for site in cls.call_sites.values()))
        for language in ("en", "zh-Hans"):
            resources = cls.directory / f"{language}.lproj"
            resources.mkdir()
            values = {
                key: entry["localizations"][language]["stringUnit"]["value"]
                for key, entry in catalog.items()
                if key.startswith(prefixes)
            }
            (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))
            cls.notifications[language] = {lane: values[key] for lane, key in cls.notification_keys.items()}

    def check_language(self, language, lane="trigger"):
        result = subprocess.run(
            [str(self.probe), str(self.directory / f"{language}.lproj"), lane],
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        actual = json.loads(result.stdout)
        self.assertEqual(actual["notificationTitle"], self.notifications[language][lane])
        if language == "zh-Hans":
            self.assertNotEqual(actual["notificationTitle"], self.notifications["en"][lane])
        self.assertEqual(actual["command"], "synthetic command payload; never executed")
        for key in ("description", "redactedDescription"):
            self.assertIn(f"title={self.titles[lane]} path=", actual[key])
        self.assertEqual(actual["title"], self.titles[lane])

    def test_english_diagnostic_title(self):
        self.check_language("en")

    def test_chinese_diagnostic_title(self):
        self.check_language("zh-Hans")

    def test_english_smart_selection_diagnostic_title(self):
        self.check_language("en", "smart")

    def test_chinese_smart_selection_diagnostic_title(self):
        self.check_language("zh-Hans", "smart")

    def test_english_url_handler_diagnostic_title(self):
        self.check_language("en", "url")

    def test_chinese_url_handler_diagnostic_title(self):
        self.check_language("zh-Hans", "url")


if __name__ == "__main__":
    unittest.main()
