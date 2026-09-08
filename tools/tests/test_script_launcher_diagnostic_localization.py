"""Native launcher caller -> shared history -> display excerpts, not a launch E2E."""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest

from tools import check_localizations as checker


ROOT = Path(__file__).resolve().parents[2]
RECOVERIES = (
    "The Apple Silicon runtime could not be downloaded. Check your network connection and try again.",
    "Its setup.cfg could not be read, so it cannot be rebuilt automatically.",
    "Its environment is intact; turn off the uv advanced setting to rebuild it for Apple Silicon.",
    "The Apple Silicon runtime could not be downloaded. Check your network connection and try again.",
)
PASSTHROUGH = ("Unknown recovery 用户数据 %@", "")
BASE = "“%@” uses an Intel-only Python environment, which cannot run on this version of macOS because Rosetta is not available."


def method(source, signature):
    start = source.index(signature)
    opening = source.index("{", start)
    end = checker.objc_braced_block_end(source, opening)
    if end is None:
        raise AssertionError("Unbalanced production method")
    return source[start:end]


class ScriptLauncherDiagnosticLocalizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="iterm2-launcher-diagnostic-")
        cls.addClassCleanup(temporary.cleanup)
        cls.directory = Path(temporary.name)
        cls.source = (ROOT / "sources/API/iTermAPIScriptLauncher.m").read_text()
        show = method(cls.source, "+ (void)showIntelOnlyUnrunnableErrorForScript:")
        recoveries = re.findall(r'recovery:(NSLocalizedStringWithDefaultValue\([^\n]+\)|@"[^"\n]+")\]', cls.source)
        if len(recoveries) != 4:
            raise AssertionError("Expected four production recovery expressions")
        history = '[[iTermScriptHistoryEntry globalEntry] addOutput:[NSString stringWithFormat:@"%@ %@\\n", base, recovery] completion:^{}];'
        if history not in show or "dispatch_async(dispatch_get_main_queue(), ^{" not in show:
            raise AssertionError("Shared history or presentation queue changed")
        helper = "static NSString *iTermLocalizedScriptRecoveryDisplayString(NSString *diagnostic)"
        includes = {
            "launcher-recovery-callers.inc": ",\n".join(recoveries) + ",",
            "launcher-show-error.inc": show,
            "launcher-display-helper.inc": method(cls.source, helper) if helper in cls.source else "",
        }
        for name, contents in includes.items():
            (cls.directory / name).write_text(contents)
        cls.probe = cls.directory / "launcher-probe"
        result = subprocess.run(
            ["xcrun", "clang", "-fobjc-arc", "-Wall", "-Wextra", "-Werror", "-framework", "AppKit",
             "-I", str(cls.directory), str(ROOT / "tests/script_launcher_diagnostic_probe.m"), "-o", str(cls.probe)],
            capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        cls.translations = {}
        for language in ("en", "zh-Hans"):
            resources = cls.directory / f"{language}.lproj"
            resources.mkdir()
            values = {key: entry["localizations"][language]["stringUnit"]["value"]
                      for key, entry in catalog.items() if key.startswith("ui.api.itermapiscriptlauncher.")}
            (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))
            cls.translations[language] = {entry["localizations"]["en"]["stringUnit"]["value"]: values[key]
                                          for key, entry in catalog.items() if key in values}

    def check_language(self, language):
        result = subprocess.run([str(self.probe), str(self.directory / f"{language}.lproj")],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = json.loads(result.stdout)
        self.assertEqual(len(rows), 12)
        expected = [(name, recovery) for name in ("用户 Demo.py", "") for recovery in (*RECOVERIES, *PASSTHROUGH)]
        for row, (name, recovery) in zip(rows, expected):
            with self.subTest(language=language, name=name, recovery=recovery):
                self.assertEqual(row["recovery"], recovery)
                self.assertEqual(row["history"], BASE.replace("%@", name) + " " + recovery + "\n")
                self.assertEqual(row["title"], self.translations[language]["Script Cannot Run"])
                self.assertEqual(row["body"], self.translations[language][BASE].replace("%@", name) + " "
                                 + self.translations[language].get(recovery, recovery))

    def test_english_history_and_display(self):
        self.check_language("en")

    def test_chinese_history_and_display(self):
        self.check_language("zh-Hans")

    def check_source(self, source, filename="iTermAPIScriptLauncher.m"):
        with tempfile.TemporaryDirectory(prefix="iterm2-launcher-checker-") as directory:
            sources = Path(directory)
            path = sources / "API" / filename
            path.parent.mkdir()
            path.write_text(source)
            return checker.check_hardcoded_english_objc_ui_literals(sources)

    def test_checker_accepts_original_recovery_at_delayed_display_boundary(self):
        self.assertEqual(self.check_source(self.source), [])

    def test_checker_rejects_unreviewed_recovery_literals_and_consumers(self):
        variants = (
            self.source.replace("+ (void)reallyUpgradeFullEnvironmentScriptAt:", "+ (void)otherUpgrade:"),
            self.source.replace("+ (void)upgradeIfNeededFullEnvironmentScriptAt:", "+ (void)otherMigration:"),
            self.source.replace("+ (void)refetchArm64StandardRuntimeThenLaunch:", "+ (void)otherRefetch:"),
            self.source.replace('[self showIntelOnlyUnrunnableErrorForScript:fullPath',
                                '[other showIntelOnlyUnrunnableErrorForScript:fullPath'),
            self.source.replace('forScript:fullPath', 'forScript:otherPath'),
            self.source.replace('addOutput:[NSString stringWithFormat:@"%@ %@\\n", base, recovery]',
                                'addOutput:[NSString stringWithFormat:@"%@ %@\\n", base, @"changed"]'),
            self.source.replace('iTermLocalizedScriptRecoveryDisplayString(recovery)', 'recovery'),
            self.source.replace('return diagnostic;', 'return @"not translated";'),
            self.source.replace('recovery:@"Its setup.cfg could not be read, so it cannot be rebuilt automatically."',
                                'recovery:@"Different runtime failure."'),
            self.source + '\n- (void)other { label.title = @"Its setup.cfg could not be read, so it cannot be rebuilt automatically."; }\n',
        )
        for index, variant in enumerate(variants):
            with self.subTest(variant=index):
                self.assertTrue(self.check_source(variant))
        self.assertTrue(self.check_source(self.source, "OtherLauncher.m"))


if __name__ == "__main__":
    unittest.main()
