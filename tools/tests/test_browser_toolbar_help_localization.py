"""Actual toolbar help copy in both languages; no app or browser-data access."""
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

from tools.tests.test_uv_shared_error_localization import member


ROOT = Path(__file__).resolve().parents[2]
KEY = "ui.browser.toolbar.dev_null_help"
ENGLISH = """## /dev/null Mode

Your browsing activity is not being saved. No history, bookmarks, or other data will be stored.

This mode is set in the browser’s Profile under **Settings > Profile > Web > Privacy**.

## 🙈 🙉 🙊"""
CHINESE = """## /dev/null 模式

不会保存你的浏览活动，也不会存储历史记录、书签或其他数据。

此模式可在浏览器的配置文件中设置，位置为 **设置 > 配置文件 > 网页 > 隐私**。

## 🙈 🙉 🙊"""


class BrowserToolbarHelpLocalizationTests(unittest.TestCase):
    def test_dev_null_help_localizes_and_preserves_english_markdown(self):
        source = (ROOT / "sources/Browser/UI/iTermBrowserToolbar.swift").read_text()
        self.assertIn("devNullIndicator.action = #selector(devNullIndicatorTapped)", source)
        self.assertIn("showDevNullInfoPopover()",
                      member(source, "@objc private func devNullIndicatorTapped()"))
        template = (ROOT / "tests/browser_toolbar_help_probe.swift").read_text()
        marker = "// TOOLBAR-HELP-METHOD"
        self.assertEqual(template.count(marker), 1)
        template = template.replace(marker, member(source, "private func showDevNullInfoPopover()"))
        template = template.replace("bundle: .main", "bundle: probeBundle")
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        with tempfile.TemporaryDirectory(prefix="iterm2-browser-toolbar-help-") as directory:
            root = Path(directory)
            swift = root / "main.swift"
            swift.write_text(template)
            probe = root / "probe"
            compiled = subprocess.run(
                ["xcrun", "swiftc", "-warnings-as-errors", str(swift), "-o", str(probe)],
                capture_output=True, text=True, timeout=45)
            self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
            for language, expected in (("en", ENGLISH), ("zh-Hans", CHINESE)):
                resources = root / f"{language}.lproj"
                resources.mkdir()
                values = {KEY: catalog[KEY]["localizations"][language]["stringUnit"]["value"]} if KEY in catalog else {}
                (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))
                run = subprocess.run([str(probe), str(resources)],
                                     capture_output=True, text=True, timeout=5)
                self.assertEqual(run.returncode, 0, run.stderr)
                with self.subTest(language=language):
                    self.assertEqual(json.loads(run.stdout), [expected])


if __name__ == "__main__":
    unittest.main()
