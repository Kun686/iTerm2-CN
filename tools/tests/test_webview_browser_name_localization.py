"""Execute the wrapper's real name getter and button-title expression.

Launch Services and application-name metadata are synthetic; no installed
browser, user preferences, network, App instance or rendered view is accessed.
"""
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

from tools.tests.test_close_job_list_localization import method


ROOT = Path(__file__).resolve().parents[2]
PREFIX = "ui.infrastructure.views.itermwebviewwrapperviewcontroller."


class WebViewBrowserNameLocalizationTests(unittest.TestCase):
    def test_browser_name_fallback_and_original_button_expression(self):
        source = (ROOT / "sources/Infrastructure/Views/iTermWebViewWrapperViewController.m").read_text()
        title_lines = [line for line in method(source, "- (void)loadView").splitlines()
                       if "[button setTitle:" in line]
        self.assertEqual(len(title_lines), 1)
        self.assertIn("[self browserName]", title_lines[0])
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        with tempfile.TemporaryDirectory(prefix="iterm2-browser-name-") as directory:
            root = Path(directory)
            (root / "browser-name.inc").write_text(method(source, "- (NSString *)browserName"))
            (root / "browser-button-title.inc").write_text(title_lines[0])
            probe = root / "probe"
            compiled = subprocess.run(
                ["xcrun", "clang", "-fobjc-arc", "-Wall", "-Werror", "-framework", "AppKit",
                 "-I", str(root), str(ROOT / "tests/webview_browser_name_probe.m"), "-o", str(probe)],
                capture_output=True, text=True, timeout=45)
            self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
            for language in ("en", "zh-Hans"):
                resources = root / f"{language}.lproj"
                resources.mkdir()
                values = {key: entry["localizations"][language]["stringUnit"]["value"]
                          for key, entry in catalog.items() if key.startswith(PREFIX)}
                (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))
                run = subprocess.run([str(probe), str(resources)],
                                     capture_output=True, text=True, timeout=5)
                self.assertEqual(run.returncode, 0, run.stderr)
                rows = json.loads(run.stdout)
                self.assertEqual(len(rows), 5)
                fallback = "Default Browser" if language == "en" else "默认浏览器"
                for index, row in enumerate(rows):
                    expected_name = fallback if index < 3 else ("Synthetic %@ 中文 Browser" if index == 3 else "")
                    expected_title = (f"Open in {expected_name}" if language == "en"
                                      else f"在 {expected_name} 中打开")
                    with self.subTest(language=language, case=index):
                        self.assertEqual(row, {
                            "name": expected_name, "title": expected_title,
                            "query": "http://example.com" if index == 0 else "https://example.invalid/raw?q=%25%40",
                            "role": True,
                        })


if __name__ == "__main__":
    unittest.main()
