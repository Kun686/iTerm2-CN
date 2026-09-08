"""Compile actual trigger title assignments and both real log descriptions.

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
        backend = (ROOT / "sources/CommandExecution/iTermBackgroundCommandRunner.m").read_text(encoding="utf-8")
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
        for language in ("en", "zh-Hans"):
            resources = cls.directory / f"{language}.lproj"
            resources.mkdir()
            values = {
                key: entry["localizations"][language]["stringUnit"]["value"]
                for key, entry in catalog.items()
                if key.startswith("ui.ptysession.ptysession.run_command_trigger")
            }
            (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))
            cls.notifications[language] = values["ui.ptysession.ptysession.run_command_trigger_failed_notification_title"]

    def check_language(self, language):
        result = subprocess.run(
            [str(self.probe), str(self.directory / f"{language}.lproj")],
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        actual = json.loads(result.stdout)
        self.assertEqual(actual["notificationTitle"], self.notifications[language])
        if language == "zh-Hans":
            self.assertNotEqual(actual["notificationTitle"], self.notifications["en"])
        self.assertEqual(actual["command"], "synthetic command payload; never executed")
        for key in ("description", "redactedDescription"):
            self.assertIn("title=Run Command Trigger path=", actual[key])
        self.assertEqual(actual["title"], "Run Command Trigger")

    def test_english_diagnostic_title(self):
        self.check_language("en")

    def test_chinese_diagnostic_title(self):
        self.check_language("zh-Hans")


if __name__ == "__main__":
    unittest.main()
