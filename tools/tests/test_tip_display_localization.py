"""Native tip display excerpts; no App, actions, preferences, sharing or UI layout.

Real title setters/getters, attributed-string assembly and raw-title lookup run.
Font/layout controls are synthetic. Bundle lookups use temporary language data.
"""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest

from tools.tests.test_close_job_list_localization import method


ROOT = Path(__file__).resolve().parents[2]
TIPS = ROOT / "sources/TIps"
TITLES = [
    ("Learn More", "了解更多"), ("Dismiss Tip", "关闭提示"),
    ("Fewer Options", "收起选项"), ("More Options", "更多选项"),
    ("Show This Later", "稍后显示"), ("Disable Tips", "停用提示"),
    ("Enable Tips", "启用提示"), ("Show Next Tip", "下一条提示"),
    ("Show Previous Tip", "上一条提示"), ("Show Tips Weekly", "每周显示提示"),
    ("Show Tips Daily", "每天显示提示"), ("Share", "共享"),
]
UNKNOWN = ["", "User-defined 用户按钮", None]
BODY = "User tip 正文 %@"
SHORTCUT = "⌘⇧X"


class TipDisplayLocalizationTests(unittest.TestCase):
    def test_action_titles_ax_and_footer_preserve_raw_values(self):
        button = (TIPS / "iTermTipCardActionButton.m").read_text()
        card = (TIPS / "iTermTipCardViewController.m").read_text()
        window = (TIPS / "iTermTipWindowController.m").read_text()
        constants = re.findall(r'static NSString \*const k\w+Title = @"([^"]+)";', window)
        self.assertEqual(constants, [title for title, _ in TITLES])
        append = (ROOT / "sources/Categories/NSMutableAttributedString+iTerm.m").read_text()
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        body = method(card, "- (void)setBodyText:")
        start = body.index("[attributedString iterm_appendString:body")
        end = body.index("_body.attributedStringValue")
        signatures = ["- (id)accessibilityValue", "- (void)setTitle:", "- (void)updateTitle",
                      "- (void)setShortcut:", "- (NSString *)title {", "- (NSString *)shortcut {"]
        if "- (NSString *)displayTitle" in button:
            signatures.insert(0, "- (NSString *)displayTitle")
        with tempfile.TemporaryDirectory(prefix="iterm2-tip-display-") as temporary:
            root = Path(temporary)
            includes = {
                "button-methods.inc": "\n".join(method(button, item) for item in signatures),
                "card-lookup.inc": method(card, "- (iTermTipCardActionButton *)actionWithTitle:"),
                "footer-append.inc": body[start:end],
                "append-method.inc": method(append, "- (void)iterm_appendString:(NSString *)string withAttributes:"),
            }
            for name, contents in includes.items():
                (root / name).write_text(contents)
            cases = [title for title, _ in TITLES] + UNKNOWN
            (root / "cases.json").write_text(json.dumps(cases))
            probe = root / "probe"
            compiled = subprocess.run(
                ["xcrun", "clang", "-fobjc-arc", "-Wall", "-Werror", "-framework", "Foundation",
                 "-I", str(root), str(ROOT / "tests/tip_display_probe.m"), "-o", str(probe)],
                capture_output=True, text=True, timeout=45)
            self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
            for language in ("en", "zh-Hans"):
                bundle = root / f"{language}.lproj"
                bundle.mkdir()
                values = {key: entry["localizations"][language]["stringUnit"]["value"]
                          for key, entry in catalog.items()
                          if key.startswith("ui.tips.display.")}
                (bundle / "Localizable.strings").write_bytes(plistlib.dumps(values))
                result = subprocess.run([str(probe), str(bundle), str(root / "cases.json"), BODY, SHORTCUT],
                                        capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stderr)
                actual = json.loads(result.stdout)
                self.assertEqual(len(actual["buttons"]), len(cases))
                for index, (raw, row) in enumerate(zip(cases, actual["buttons"])):
                    display = TITLES[index][int(language == "zh-Hans")] if index < len(TITLES) else raw
                    expected = dict(stored=raw, shortcut=SHORTCUT, ax=display,
                                    text=(display or "") + "\t" + SHORTCUT,
                                    rawLookup=raw is not None,
                                    displayLookup=display is not None and display == raw)
                    with self.subTest(language=language, title=raw):
                        self.assertEqual(row, expected)
                signature = "iTerm2 tip of the day" if language == "en" else "iTerm2 每日提示"
                with self.subTest(language=language, footer=True):
                    self.assertEqual(actual["footer"], dict(text=BODY + "\n" + signature,
                                                           bodyStyle="body", signatureStyle="signature"))


if __name__ == "__main__":
    unittest.main()
