"""Native close-alert excerpts: display text, raw names and generic diagnostics.

The real grouping, sorting, joining and message branches execute in AppKit.
Bundle lookup alone is redirected to catalog-derived temporary language bundles.
This does not exercise job discovery, the actual sheet, or session lifecycle.
The third-party AX getter is characterized, not claimed localized or operable.
"""
from collections import Counter
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

from tools import check_localizations as checker


ROOT = Path(__file__).resolve().parents[2]


def method(source, signature):
    start = source.index(signature)
    end = checker.objc_braced_block_end(source, source.index("{", start))
    if end is None:
        raise AssertionError(f"Unbalanced production method: {signature}")
    return source[start:end]


def joined(values, conjunction):
    if len(values) < 2:
        return "".join(values)
    if len(values) == 2:
        return f" {conjunction} ".join(values)
    return ", ".join(values[:-1]) + f", {conjunction} " + values[-1]


class CloseJobListLocalizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="iterm2-close-list-")
        cls.addClassCleanup(temporary.cleanup)
        cls.directory = Path(temporary.name)
        array = (ROOT / "sources/Categories/NSArray+iTerm.m").read_text()
        common = (ROOT / "sources/Common/NSArray+CommonAdditions.m").read_text()
        terminal = (ROOT / "sources/TerminalView/PseudoTerminal.m").read_text()
        start = terminal.index("    NSString *message;", terminal.index("additionalMessage:(NSString *)additionalMessage"))
        end = terminal.index("    // The PseudoTerminal might close", start)
        psm = (ROOT / "ThirdParty/PSMTabBarControl/source/PSMTabBarCell.m").read_text()
        psm = psm[psm.index("@implementation PSMTabCloseButtonAccessibilityElement"):]
        includes = {
            "close-list-message.inc": terminal[start:end],
            "close-label-getter.inc": method(psm, "- (NSString *)accessibilityLabel"),
            "close-list-helpers.inc": "\n".join([
                method(common, "- (instancetype)mapWithBlock:"),
                *(method(array, signature) for signature in (
                    "- (NSDictionary<id, NSArray *> *)classifyWithBlock:",
                    "- (NSArray *)countedInstancesStrings",
                    "- (NSString *)componentsJoinedWithOxfordComma {",
                    "- (NSString *)componentsJoinedWithOxfordCommaAndConjunction:")),
            ]),
        }
        for name, contents in includes.items():
            (cls.directory / name).write_text(contents)
        cls.probe = cls.directory / "close-list-probe"
        compiled = subprocess.run(
            ["xcrun", "clang", "-fobjc-arc", "-Wall", "-Werror", "-framework", "AppKit",
             "-I", str(cls.directory), str(ROOT / "tests/close_job_list_localization_probe.m"),
             "-o", str(cls.probe)], capture_output=True, text=True, timeout=60)
        if compiled.returncode:
            raise AssertionError(compiled.stdout + compiled.stderr)
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        for language in ("en", "zh-Hans"):
            resources = cls.directory / f"{language}.lproj"
            resources.mkdir()
            values = {key: entry["localizations"][language]["stringUnit"]["value"]
                      for key, entry in catalog.items() if "localizations" in entry
                      and language in entry["localizations"]
                      and "stringUnit" in entry["localizations"][language]}
            (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))

    def snapshot(self, language):
        result = subprocess.run([str(self.probe), str(self.directory / f"{language}.lproj")],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def check_language(self, language):
        rows = self.snapshot(language)["rows"]
        self.assertEqual(len(rows), 22)
        for row in rows:
            with self.subTest(language=language, names=row["names"], additional=row["additional"]):
                counts = Counter(row["names"])
                # Mixed-name fixtures are ASCII; Unicode fixtures have one unique key.
                keys = sorted(counts, key=str.casefold)
                values = [name if counts[name] == 1 else (
                    f'{counts[name]} instances of "{name}"' if language == "en"
                    else f"{counts[name]} 个“{name}”实例") for name in keys]
                listing = joined(values, "and" if language == "en" else "和")
                if not values:
                    expected = "Synthetic Window will be closed." if language == "en" else "将关闭Synthetic Window。"
                elif len(values) == 1:
                    expected = (f"Synthetic Window is running {listing}." if language == "en"
                                else f"Synthetic Window正在运行 {listing}。")
                else:
                    expected = (f"Synthetic Window is running the following jobs: {listing}" if language == "en"
                                else f"Synthetic Window正在运行以下作业：{listing}")
                    if len(values) > 10:
                        remaining = len(values) - 10
                        expected += (f", plus {remaining} " + ("other" if remaining == 1 else "others")
                                     if language == "en" else f"，另外还有 {remaining} 个其他作业")
                    expected += "." if language == "en" else "。"
                if row["additional"]:
                    expected += "\n\n" + row["additional"]
                self.assertEqual(row["body"], expected)
                self.assertEqual(row["genericJoined"], joined(row["names"], "and"))

    def test_english_close_messages_and_raw_joiner(self):
        self.check_language("en")

    def test_chinese_close_messages_and_raw_joiner(self):
        self.check_language("zh-Hans")

    def test_third_party_ax_getter_ignores_inherited_label_setter(self):
        for language in ("en", "zh-Hans"):
            with self.subTest(language=language):
                snapshot = self.snapshot(language)
                self.assertEqual(snapshot["axBefore"], "Close Tab")
                self.assertEqual(snapshot["axAfter"], "Close Tab")


if __name__ == "__main__":
    unittest.main()
