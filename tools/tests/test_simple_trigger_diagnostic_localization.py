"""Compile real trigger title/description methods and the matched-log format.

Only Foundation formatting is exercised. The temporary classes omit Trigger's
session state and actions; this is not a live matcher or emitted-log test.
"""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class SimpleTriggerDiagnosticLocalizationTests(unittest.TestCase):
    fixtures = {
        "StopTrigger": ("Stop Processing Triggers", "停止处理触发器"),
        "iTermShellPromptTrigger": ("Prompt Detected", "检测到提示符"),
    }

    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="iterm2-simple-trigger-")
        cls.addClassCleanup(temporary.cleanup)
        cls.directory = Path(temporary.name)
        for name in cls.fixtures:
            source = (ROOT / f"sources/Triggers/{name}.m").read_text()
            methods = []
            for signature in ("+ (NSString *)title {", "- (NSString *)description {"):
                if source.count(signature) != 1:
                    raise AssertionError(f"Expected one {name} {signature}")
                body = source.split(signature, 1)[1].split("\n}", 1)[0]
                methods.append(signature + body + "\n}\n")
            (cls.directory / f"{name}.inc").write_text("\n".join(methods))
        trigger = (ROOT / "sources/Triggers/Trigger.m").read_text()
        matches = re.findall(r'DLog\((@"Trigger %@ matched string %@", self, s)\);', trigger)
        if len(matches) != 2:
            raise AssertionError("Expected both original matched-trigger log operands")
        (cls.directory / "trigger-matched-log.inc").write_text(
            "return [NSString stringWithFormat:" + matches[0] + "];\n")
        cls.probe = cls.directory / "trigger-description-probe"
        compiled = subprocess.run(
            ["xcrun", "clang", "-fobjc-arc", "-Wall", "-Wextra", "-Werror",
             "-framework", "Foundation", "-I", str(cls.directory),
             str(ROOT / "tests/trigger_description_probe.m"), "-o", str(cls.probe)],
            capture_output=True, text=True, timeout=60)
        if compiled.returncode:
            raise AssertionError(compiled.stdout + compiled.stderr)
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        prefixes = ("ui.triggers.stoptrigger.", "ui.triggers.itermshellprompttrigger.")
        for language in ("en", "zh-Hans"):
            resources = cls.directory / f"{language}.lproj"
            resources.mkdir()
            values = {key: entry["localizations"][language]["stringUnit"]["value"]
                      for key, entry in catalog.items() if key.startswith(prefixes)}
            if len(values) != 2:
                raise AssertionError("Expected both real action-title resources")
            (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))

    def check_language(self, language):
        result = subprocess.run([str(self.probe), str(self.directory / f"{language}.lproj")],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = json.loads(result.stdout)
        self.assertEqual({row["class"] for row in rows}, set(self.fixtures))
        for row in rows:
            original, chinese = self.fixtures[row["class"]]
            with self.subTest(trigger=row["class"], field="title"):
                self.assertEqual(row["title"], chinese if language == "zh-Hans" else original)
            with self.subTest(trigger=row["class"], field="description"):
                self.assertEqual(row["description"], original)
            with self.subTest(trigger=row["class"], field="matchedLog"):
                self.assertEqual(row["matchedLog"], f"Trigger {original} matched string synthetic")

    def test_english_diagnostics_and_titles(self):
        self.check_language("en")

    def test_chinese_diagnostics_and_titles(self):
        self.check_language("zh-Hans")


if __name__ == "__main__":
    unittest.main()
