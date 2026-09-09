"""Native scheme-error constructors, navigation log, and error-page display copy.

Does not run WebKit or prove its callback scheduling. Exercises the actual
NSError expressions, log statement and display helper with isolated resources.
"""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest

from tools import check_localizations as checker
from tools.tests.test_uv_shared_error_localization import member


ROOT = Path(__file__).resolve().parents[2]
PATHS = (
    "sources/Browser/Core/iTermBrowserManager.swift",
    "sources/Browser/Bookmarks/iTermBrowserBookmarkViewHandler.swift",
    "sources/Browser/LocalPages/iTermBrowserErrorHandler.swift",
)
EXPECTED = (
    ("iTermBrowserManager", "Invalid URL", "URL 无效"),
    *(("iTermBrowserManager", "Unknown URL scheme", "未知 URL 方案"),) * 3,
    ("iTermBrowserBookmarkViewHandler", "Failed to encode HTML", "无法编码 HTML"),
    ("iTermBrowserManager", "Failed to encode HTML", "无法编码 HTML"),
)


class BrowserNavigationErrorLocalizationTests(unittest.TestCase):
    def test_scheme_failures_preserve_diagnostics_and_localize_display_copy(self):
        sources = [(ROOT / path).read_text() for path in PATHS]
        errors = []
        for source in sources:
            for match in re.finditer(r'NSError\(domain: "(?:iTermBrowserManager|iTermBrowserBookmarkViewHandler)", code: -1,', source):
                end = checker.swift_delimited_expression_end(source, match.start() + len("NSError"), "(", ")")
                self.assertIsNotNone(end)
                errors.append(source[match.start():end])
        self.assertEqual(len(errors), 6)
        log = re.findall(r'^\s*RLog\("🔌 didFailNavigation: .*$', sources[0], re.M)
        self.assertEqual(len(log), 1)
        signature = "private func localizedNavigationErrorDescription("
        helper = member(sources[2], signature) if signature in sources[2] else ""
        display_method = member(sources[2], "private func errorTitleAndMessage(")
        if helper:
            self.assertIn("let displayDescription = localizedNavigationErrorDescription(error)", display_method)
            self.assertEqual(display_method.count("displayDescription"), 3)
            self.assertNotIn("error.localizedDescription", display_method)
        template = (ROOT / "tests/browser_navigation_error_probe.swift").read_text()
        for marker, source in {
            "// SCHEME-ERROR-CONSTRUCTORS": "return [" + ",\n".join(errors) + "]",
            "// NAVIGATION-ERROR-LOG": log[0],
            "// NAVIGATION-DISPLAY-HELPER": helper,
            "// NAVIGATION-DISPLAY-CALL": "return localizedNavigationErrorDescription(error)" if helper else "return error.localizedDescription",
        }.items():
            self.assertEqual(template.count(marker), 1)
            template = template.replace(marker, source)
        template = template.replace("bundle: .main", "bundle: probeBundle")
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        with tempfile.TemporaryDirectory(prefix="iterm2-browser-navigation-error-") as directory:
            root = Path(directory)
            swift = root / "main.swift"
            swift.write_text(template)
            probe = root / "probe"
            compiled = subprocess.run(
                ["xcrun", "swiftc", "-warnings-as-errors", str(swift), "-o", str(probe)],
                capture_output=True, text=True, timeout=45)
            self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
            for language in ("en", "zh-Hans"):
                resources = root / f"{language}.lproj"
                resources.mkdir()
                values = {key: entry["localizations"][language]["stringUnit"]["value"]
                          for key, entry in catalog.items() if key.startswith((
                              "ui.swift.browser.core.itermbrowsermanager.",
                              "ui.swift.browser.bookmarks.itermbrowserbookmarkviewhandler.",
                              "ui.swift.browser.localpages.itermbrowsererrorhandler."))}
                (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))
                run = subprocess.run([str(probe), str(resources)],
                                     capture_output=True, text=True, timeout=5)
                self.assertEqual(run.returncode, 0, run.stderr)
                snapshot = json.loads(run.stdout)
                self.assertEqual(len(snapshot["known"]), len(EXPECTED))
                for index, (row, (domain, raw, chinese)) in enumerate(zip(snapshot["known"], EXPECTED)):
                    for field, value in {
                        "domain": domain, "code": -1,
                        "userInfo": {"NSLocalizedDescription": raw},
                        "log": [f"🔌 didFailNavigation: domain={domain} code=-1 — {raw}"],
                        "displayed": raw if language == "en" else chinese,
                    }.items():
                        with self.subTest(language=language, constructor=index, field=field):
                            self.assertEqual(row[field], value)
                self.assertEqual(len(snapshot["unknown"]), 5)
                for row in snapshot["unknown"]:
                    with self.subTest(language=language, unknown=row["raw"]):
                        self.assertEqual(row["displayed"], row["raw"])


if __name__ == "__main__":
    unittest.main()
