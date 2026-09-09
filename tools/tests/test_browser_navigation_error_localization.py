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
        self.check_scheme_errors(PATHS, [(domain, -1, raw, chinese)
                                        for domain, raw, chinese in EXPECTED])

    def test_local_page_failures_preserve_diagnostics_and_localize_display_copy(self):
        path = "/synthetic/用户 空格/100%.txt"
        self.check_scheme_errors((
            "sources/Browser/History/iTermBrowserHistoryViewHandler.swift",
            "sources/Browser/LocalPages/iTermBrowserFileHandler.swift",
            "sources/Browser/LocalPages/iTermBrowserLocalPageManager.swift",
        ), (
            ("iTermBrowserHistoryViewHandler", -1, "Failed to encode HTML", "无法编码 HTML"),
            ("iTermBrowserManager", -1, "No path specified", "未指定路径"),
            ("iTermBrowserManager", -1, "Failed to encode HTML", "无法编码 HTML"),
            ("NSCocoaErrorDomain", 4, f"File not found: {path}", f"找不到文件：{path}"),
            ("iTermBrowserLocalPageManager", -1, "Unknown iterm2-about URL", "未知的 iterm2-about URL"),
        ), local_pages=True)

    def test_onboarding_failures_preserve_diagnostics_and_localize_display_copy(self):
        self.check_scheme_errors((
            "sources/Browser/LocalPages/iTermBrowserOnboardingHandler.swift",
            "sources/Browser/LocalPages/iTermBrowserStaticPageHandler.swift",
            "sources/Browser/LocalPages/iTermBrowserWelcomePageHandler.swift",
        ), (
            ("iTermBrowserOnboardingHandler", -1, "Failed to encode HTML", "无法编码 HTML"),
            ("iTermBrowserStaticPageHandler", -1, "Failed to encode HTML", "无法编码 HTML"),
            ("iTermBrowserWelcomePageHandler", -1, "Failed to encode redirect HTML", "无法编码重定向 HTML"),
            ("iTermBrowserWelcomePageHandler", -1, "Failed to encode HTML", "无法编码 HTML"),
        ), onboarding=True)

    def check_scheme_errors(self, paths, expected, local_pages=False, onboarding=False):
        sources = [(ROOT / path).read_text() for path in paths]
        errors = []
        for source in sources:
            pattern = (r'NSError\(domain: (?:"(?:iTermBrowserManager|iTermBrowserBookmarkViewHandler|'
                       r'iTermBrowserHistoryViewHandler|iTermBrowserLocalPageManager|'
                       r'iTermBrowserOnboardingHandler|iTermBrowserStaticPageHandler|'
                       r'iTermBrowserWelcomePageHandler)"|NSCocoaErrorDomain),\s+'
                       r'code: (?:-1|NSFileNoSuchFileError),')
            for match in re.finditer(pattern, source):
                end = checker.swift_delimited_expression_end(source, match.start() + len("NSError"), "(", ")")
                self.assertIsNotNone(end)
                errors.append(source[match.start():end])
        self.assertEqual(len(errors), len(expected))
        manager = (ROOT / PATHS[0]).read_text()
        display_source = (ROOT / PATHS[2]).read_text()
        local_manager = (ROOT / "sources/Browser/LocalPages/iTermBrowserLocalPageManager.swift").read_text()
        log = re.findall(r'^\s*RLog\("🔌 didFailNavigation: .*$', manager, re.M)
        self.assertEqual(len(log), 1)
        file_log = ""
        if local_pages:
            lines = re.findall(r'^\s*NSLog\("iTermBrowserFileHandler.start: error generating HTML: .*$', sources[1], re.M)
            self.assertEqual(len(lines), 1)
            file_log = lines[0]
        signature = "private func localizedNavigationErrorDescription("
        helper = member(display_source, signature) if signature in display_source else ""
        display_method = member(display_source, "private func errorTitleAndMessage(")
        if helper:
            self.assertIn("let displayDescription = localizedNavigationErrorDescription(error)", display_method)
            self.assertEqual(display_method.count("displayDescription"), 3)
            self.assertNotIn("error.localizedDescription", display_method)
        template = (ROOT / "tests/browser_navigation_error_probe.swift").read_text()
        for marker, source in {
            "// BROWSER-SCHEME-DECLARATIONS": member(local_manager, "struct iTermBrowserSchemes"),
            "// SCHEME-ERROR-CONSTRUCTORS": "return [" + ",\n".join(errors) + "]",
            "// NAVIGATION-ERROR-LOG": log[0],
            "// LOCAL-PAGE-ERROR-LOG": file_log,
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
                              "ui.swift.browser.localpages.itermbrowsererrorhandler.",
                              "ui.swift.browser.history.itermbrowserhistoryviewhandler.",
                              "ui.swift.browser.localpages.itermbrowserfilehandler.",
                              "ui.swift.browser.localpages.itermbrowserlocalpagemanager.",
                              "ui.swift.browser.localpages.itermbrowseronboardinghandler.",
                              "ui.swift.browser.localpages.itermbrowserstaticpagehandler.",
                              "ui.swift.browser.localpages.itermbrowserwelcomepagehandler."))}
                (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))
                mode = ["onboarding"] if onboarding else (["local-pages"] if local_pages else [])
                arguments = [str(probe), str(resources)] + mode
                run = subprocess.run(arguments,
                                     capture_output=True, text=True, timeout=5)
                self.assertEqual(run.returncode, 0, run.stderr)
                snapshot = json.loads(run.stdout)
                self.assertEqual(len(snapshot["known"]), len(expected))
                for index, (row, (domain, code, raw, chinese)) in enumerate(zip(snapshot["known"], expected)):
                    for field, value in {
                        "domain": domain, "code": code,
                        "userInfo": {"NSLocalizedDescription": raw},
                        "log": [f"🔌 didFailNavigation: domain={domain} code={code} — {raw}"],
                        "displayed": raw if language == "en" else chinese,
                    }.items():
                        with self.subTest(language=language, constructor=index, field=field):
                            self.assertEqual(row[field], value)
                    if local_pages:
                        with self.subTest(language=language, constructor=index, field="fileLog"):
                            self.assertEqual(len(row["fileLog"]), 1)
                            self.assertIn(raw, row["fileLog"][0])
                self.assertEqual(len(snapshot["unknown"]), 6 if onboarding else (8 if local_pages else 5))
                for row in snapshot["unknown"]:
                    with self.subTest(language=language, unknown=row["raw"]):
                        self.assertEqual(row["displayed"], row["raw"])


if __name__ == "__main__":
    unittest.main()
