"""Execute the real rich-stat display block without a Git poller or NSApplication.

Counts are synthetic; Foundation formatting and the original array join run.
Font/color creation is a stand-in, not an AppKit rendering or layout test.
"""
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

from tools.tests.test_close_job_list_localization import method


ROOT = Path(__file__).resolve().parents[2]
FIELDS = ("filesAdded", "filesModified", "filesDeleted", "linesInserted", "linesDeleted")
CASES = [
    ((1, 0, 0, 0, 0), "+1 files", "+1 个文件"),
    ((0, 0, 1, 0, 0), "-1 files", "-1 个文件"),
    ((2, 0, 3, 0, 0), "+2/-3 files", "+2/-3 个文件"),
    ((0, 0, 0, 1, 0), "+1 lines", "+1 行"),
    ((0, 0, 0, 0, 1), "-1 lines", "-1 行"),
    ((0, 0, 0, 4, 5), "+4/-5 lines", "+4/-5 行"),
    ((1234567, 9, 20, 3456789, 40), "+1234567/-20 files +3456789/-40 lines",
     "+1234567/-20 个文件 +3456789/-40 行"),
    ((0, 7, 0, 0, 0), "", ""),
    ((0, 0, 0, 0, 0), None, None),
]


class GitStatsLocalizationTests(unittest.TestCase):
    def test_rich_stat_labels_and_counts_in_both_languages(self):
        source = (ROOT / "sources/iTermGitStringMaker.m").read_text()
        display = method(source, "- (nullable NSAttributedString *)attributedStringValueForBranch:")
        start = display.index("    const NSInteger filesAdded")
        end = display.index("    // Minimal: the legacy adds/deletes indicator")
        array = (ROOT / "sources/Categories/NSArray+iTerm.m").read_text()
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        cases = [dict(zip(FIELDS, row[0])) for row in CASES]
        with tempfile.TemporaryDirectory(prefix="iterm2-git-stats-") as temporary:
            root = Path(temporary)
            (root / "rich-stats.inc").write_text(display[start:end])
            (root / "join-method.inc").write_text(method(
                array, "- (NSAttributedString *)attributedComponentsJoinedByAttributedString:"))
            (root / "cases.json").write_text(json.dumps(cases))
            probe = root / "probe"
            compiled = subprocess.run(
                ["xcrun", "clang", "-fno-objc-arc", "-Wall", "-Werror", "-framework", "Foundation",
                 "-I", str(root), str(ROOT / "tests/git_stats_localization_probe.m"), "-o", str(probe)],
                capture_output=True, text=True, timeout=45)
            self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
            for language in ("en", "zh-Hans"):
                bundle = root / f"{language}.lproj"
                bundle.mkdir()
                values = {key: entry["localizations"][language]["stringUnit"]["value"]
                          for key, entry in catalog.items() if key.startswith("ui.itermgitstringmaker.")}
                (bundle / "Localizable.strings").write_bytes(plistlib.dumps(values))
                result = subprocess.run([str(probe), str(bundle), str(root / "cases.json")],
                                        capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stderr)
                rows = json.loads(result.stdout)
                self.assertEqual(len(rows), len(CASES))
                for index, row in enumerate(rows):
                    with self.subTest(language=language, counts=cases[index]):
                        self.assertEqual(row["text"], CASES[index][1 + int(language == "zh-Hans")])
                        self.assertEqual(row["counts"], cases[index])


if __name__ == "__main__":
    unittest.main()
