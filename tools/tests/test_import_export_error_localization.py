"""Real plist failure -> export diagnostic and localized display, without user data."""
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

from tools.tests.test_uv_shared_error_localization import member


ROOT = Path(__file__).resolve().parents[2]
PREFIX = "ui.swift.settings.importexport."
REASON_KEY = PREFIX + "failed_to_serialize_user_defaults.095521de"
MESSAGE_KEY = PREFIX + "a_bug_was_encountered_0_please_report_this.6f760c45"


class ImportExportErrorLocalizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="iterm2-export-error-")
        cls.addClassCleanup(temporary.cleanup)
        cls.directory = Path(temporary.name)
        source = (ROOT / "sources/Settings/ImportExport.swift").read_text()
        flow = member(source, "fileprivate static func performExportFlow()")
        template = (ROOT / "tests/import_export_error_probe.swift").read_text()
        for marker, content in {
            "// EXPORT-ERROR-ENUM": member(source, "private enum ImportExportError:"),
            "// PROPERTY-LIST-WRITER": member(source, "fileprivate extension Dictionary"),
            "// EXPORT-OUTCOME": member(source, "fileprivate enum ExportOutcome"),
            "// EXPORT-CATCH": member(flow, "catch {"),
        }.items():
            if template.count(marker) != 1:
                raise AssertionError("Expected one template marker: " + marker)
            template = template.replace(marker, content)
        swift_path = cls.directory / "main.swift"
        swift_path.write_text(template.replace("bundle: .main", "bundle: probeBundle"))
        cls.probe = cls.directory / "export-error-probe"
        result = subprocess.run(
            ["xcrun", "swiftc", "-warnings-as-errors", str(swift_path), "-o", str(cls.probe)],
            capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        cls.translations = {}
        for language in ("en", "zh-Hans"):
            resources = cls.directory / f"{language}.lproj"
            resources.mkdir()
            values = {key: entry["localizations"][language]["stringUnit"]["value"]
                      for key, entry in catalog.items() if key.startswith(PREFIX)}
            cls.translations[language] = values
            (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))

    def check_language(self, language):
        output = self.directory / f"output-{language}"
        output.mkdir()
        result = subprocess.run(
            [str(self.probe), str(self.directory / f"{language}.lproj"), str(output)],
            capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = json.loads(result.stdout)
        self.assertEqual([row["name"] for row in rows],
                         ["valid", "invalid", "write-failure", "unknown-bug"])
        self.assertEqual(rows[0], {"name": "valid", "outcome": "success", "logs": []})
        self.assertEqual(plistlib.loads((output / "valid.plist").read_bytes()),
                         {"original-key": "原文", "number": 42, "enabled": True})
        self.assertFalse((output / "invalid.plist").exists())
        self.assertFalse((output / "absent").exists())
        values = self.translations[language]
        self.assertEqual(rows[1]["outcome"], "failure")
        self.assertEqual(rows[1]["message"],
                         values[MESSAGE_KEY].replace("%1$@", values[REASON_KEY]))
        self.assertEqual(rows[1]["logs"],
                         ['Failed: bug("Failed to serialize user defaults")'])
        self.assertEqual(rows[2]["outcome"], "failure")
        self.assertEqual(len(rows[2]["logs"]), 1)
        self.assertTrue(rows[2]["logs"][0].startswith("Failed: failedToSaveFile("))
        self.assertEqual(rows[3]["message"],
                         values[MESSAGE_KEY].replace("%1$@", "Synthetic 原文"))
        self.assertEqual(rows[3]["logs"], ['Failed: bug("Synthetic 原文")'])

    def test_english_export_error_boundary(self):
        self.check_language("en")

    def test_chinese_export_error_boundary(self):
        self.check_language("zh-Hans")


if __name__ == "__main__":
    unittest.main()
