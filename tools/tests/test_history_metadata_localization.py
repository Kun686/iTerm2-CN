"""Check the real history metadata formatters without App startup or user data."""
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
PREFIX = "ui.categories.history_metadata."


class HistoryMetadataLocalizationTests(unittest.TestCase):
    def test_composer_history_detail_uses_selected_language(self):
        source = (ROOT / "sources/StatusBar/Components/iTermStatusBarLargeComposerViewController.m").read_text()
        signature = "- (NSArray<iTermCompletionItem *> *)historySuggestionsForPrefix:"
        self.assertEqual(source.count(signature), 1)
        method = source.split(signature, 1)[1].split("\n}", 1)[0]
        self.assertEqual(method.count("detail:"), 1)
        self.assertEqual(method.count("kind:iTermCompletionItemKindHistory"), 1)
        expression = method.split("detail:", 1)[1].split("kind:iTermCompletionItemKindHistory", 1)[0].strip()
        date_source = (ROOT / "sources/Categories/NSDateFormatterExtras.m").read_text()
        date_signature = "+ (NSString *)dateDifferenceStringFromDate:(NSDate *)date\n"
        self.assertEqual(date_source.count(date_signature), 1)
        date_method = date_signature + date_source.split(date_signature, 1)[1].split("\n}", 1)[0] + "\n}\n"
        self.assertEqual(date_method.count("[NSDate date]"), 1)
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        key = "ui.statusbar.large_composer.history_last_used"
        with tempfile.TemporaryDirectory(prefix="iterm2-composer-detail-") as temporary:
            directory = Path(temporary)
            (directory / "history-composer-detail.inc").write_text("return " + expression + ";\n")
            (directory / "history-date-methods.inc").write_text(date_method.replace("[NSDate date]", "probeNow"))
            probe = directory / "probe"
            compiled = subprocess.run(
                ["xcrun", "clang", "-fobjc-arc", "-Wall", "-Werror", "-DCN_TEST_COMPOSER_DETAIL",
                 "-framework", "Foundation", "-framework", "AppKit", "-I", str(directory),
                 "-I", str(ROOT / "sources/Categories"),
                 str(ROOT / "tests/history_metadata_localization_probe.m"), "-o", str(probe)],
                capture_output=True, text=True, timeout=45)
            self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
            for language in ("en", "zh-Hans"):
                resources = directory / f"{language}.lproj"
                resources.mkdir()
                values = {name: entry["localizations"][language]["stringUnit"]["value"]
                          for name, entry in catalog.items() if name.startswith(PREFIX) or name == key}
                (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))
                run = subprocess.run([str(probe), str(resources)], capture_output=True,
                                     text=True, timeout=5)
                self.assertEqual(run.returncode, 0, run.stderr)
                with self.subTest(language=language):
                    self.assertEqual(json.loads(run.stdout)["details"],
                                     ["上次使用：刚刚", "上次使用：2 分钟前"] if language == "zh-Hans"
                                     else ["Last used moments ago", "Last used 2 minutes ago"])

    def test_history_metadata_uses_selected_language_and_preserves_english(self):
        date_source = (ROOT / "sources/Categories/NSDateFormatterExtras.m").read_text()
        byte_source = (ROOT / "sources/Categories/NSStringITerm.m").read_text()

        def method(source, signature):
            self.assertEqual(source.count(signature), 1)
            return signature + source.split(signature, 1)[1].split("\n}", 1)[0] + "\n}\n"

        wrapper = method(date_source, "+ (NSString *)dateDifferenceStringFromDate:(NSDate *)date {")
        dated = method(date_source, "+ (NSString *)dateDifferenceStringFromDate:(NSDate *)date\n")
        # The clock is the only substituted system boundary. No formatting logic is replaced.
        self.assertEqual(dated.count("[NSDate date]"), 1)
        dated = dated.replace("[NSDate date]", "probeNow")
        byte_method = method(byte_source, "+ (NSString *)it_formatBytes:(double)bytes {")
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]

        with tempfile.TemporaryDirectory(prefix="iterm2-history-metadata-") as temporary:
            directory = Path(temporary)
            (directory / "history-date-methods.inc").write_text(wrapper + dated)
            (directory / "history-bytes-method.inc").write_text(byte_method)
            probe = directory / "probe"
            compiled = subprocess.run(
                ["xcrun", "clang", "-fobjc-arc", "-Wall", "-Werror",
                 "-framework", "Foundation", "-framework", "AppKit",
                 "-I", str(directory), "-I", str(ROOT / "sources/Categories"),
                 str(ROOT / "tests/history_metadata_localization_probe.m"), "-o", str(probe)],
                capture_output=True, text=True, timeout=45)
            self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)

            english = ["Moments ago", "1 minute ago", "2 minutes ago", "1 hour ago",
                       "2 hours ago", "Yesterday", "2 days ago", "One week ago",
                       "Last week", "2 weeks ago"]
            chinese = ["刚刚", "1 分钟前", "2 分钟前", "1 小时前", "2 小时前",
                       "昨天", "2 天前", "一周前", "上周", "2 周前"]
            for language in ("en", "zh-Hans"):
                resources = directory / f"{language}.lproj"
                resources.mkdir()
                values = {key: entry["localizations"][language]["stringUnit"]["value"]
                          for key, entry in catalog.items() if key.startswith(PREFIX)}
                (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))
                run = subprocess.run([str(probe), str(resources)], capture_output=True,
                                     text=True, timeout=5)
                self.assertEqual(run.returncode, 0, run.stderr)
                result = json.loads(run.stdout)
                expected = chinese if language == "zh-Hans" else english
                with self.subTest(language=language, component="relative dates"):
                    self.assertEqual([row["upper"] for row in result["dates"]], expected)
                    self.assertEqual([row["lower"] for row in result["dates"]],
                                     [text.lower() for text in expected])
                with self.subTest(language=language, component="size"):
                    self.assertEqual(result["sizes"],
                                     (["0 字节", "90 字节", "999 字节"] if language == "zh-Hans"
                                      else ["0 bytes", "90 bytes", "999 bytes"])
                                     + ["1.0 kB", "10 kB", "1.0 MB"])


if __name__ == "__main__":
    unittest.main()
