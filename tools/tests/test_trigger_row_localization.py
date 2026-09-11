"""Run real row construction/binding and save expressions with native AppKit.

Only the visualization/layout tail and unrelated trigger fields are omitted.
No trigger executes and no settings are read or written. Bundle lookups use
temporary catalog-derived resources, not the installed app's preferences.
"""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class TriggerRowLocalizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="iterm2-trigger-rows-")
        cls.addClassCleanup(temporary.cleanup)
        cls.directory = Path(temporary.name)
        source = (ROOT / "sources/Settings/iTermAddTriggerViewController.m").read_text()
        start = source.index("- (NSView *)createRowWithLabelText:")
        end = source.index("    // Add visualization button if needed", start)
        construction = source[start:end] + "    return row;\n}\n"
        calls = re.findall(r"\[self createRowWithLabelText:.*? hasVisualizationButton:(?:YES|NO)\]", source)
        if len(calls) != 3:
            raise AssertionError("Expected the three actual trigger row call sites")
        save = source[source.index("- (IBAction)ok:"):]
        expressions = []
        for field in ("Regex", "Name", "Job"):
            match = re.search(r"kTrigger" + field + r"Key: (.+?)(?:,| \} mutableCopy\];)", save)
            if not match:
                raise AssertionError(f"Missing actual {field} save expression")
            expressions.append('@"' + field.lower() + '": ' + match.group(1))
        includes = {
            "trigger-row-construction.inc": construction,
            "trigger-row-calls.inc": "return @[" + ",\n".join(calls) + "];",
            "trigger-row-save.inc": "return @{" + ",\n".join(expressions) + "};",
        }
        for name, value in includes.items():
            (cls.directory / name).write_text(value)
        cls.probe = cls.directory / "trigger-row-probe"
        compiled = subprocess.run(
            ["xcrun", "clang", "-fobjc-arc", "-Wall", "-Werror", "-framework", "AppKit",
             "-I", str(cls.directory), str(ROOT / "tests/trigger_row_localization_probe.m"),
             "-o", str(cls.probe)], capture_output=True, text=True, timeout=60)
        if compiled.returncode:
            raise AssertionError(compiled.stdout + compiled.stderr)
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        for language in ("en", "zh-Hans"):
            resources = cls.directory / f"{language}.lproj"
            resources.mkdir()
            values = {key: entry["localizations"][language]["stringUnit"]["value"]
                      for key, entry in catalog.items()
                      if key.startswith("ui.settings.itermaddtriggerviewcontroller.")}
            (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))

    def check_language(self, language):
        result = subprocess.run([str(self.probe), str(self.directory / f"{language}.lproj")],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        snapshot = json.loads(result.stdout)
        labels = (["Regular Expression:", "Name:", "Job:"] if language == "en"
                  else ["正则表达式：", "名称：", "作业："])
        for index, label in enumerate(labels):
            with self.subTest(language=language, field=label):
                self.assertEqual(snapshot["labels"][index], label)
                self.assertTrue(snapshot["bound"][index])
        expected_help = ("Trigger enabled only for this job (e.g., emacs)" if language == "en"
                         else "仅对此作业启用触发器（例如 emacs）")
        with self.subTest(language=language, placeholder=True):
            self.assertEqual(snapshot["jobPlaceholder"], expected_help)
        for row in snapshot["rows"]:
            with self.subTest(language=language, input=row["input"], event=row["event"]):
                self.assertNotIn("exception", row)
                value = row["input"]
                self.assertEqual(row["saved"], {"regex": "" if row["event"] else value,
                                               "name": value, "job": value or None})
        self.assertEqual(snapshot["unknownLabel"], "Synthetic 用户 %@:")

    def test_english_labels_bind_and_preserve_input(self):
        self.check_language("en")

    def test_chinese_labels_bind_and_preserve_input(self):
        self.check_language("zh-Hans")


if __name__ == "__main__":
    unittest.main()
