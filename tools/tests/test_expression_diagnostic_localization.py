"""Real error constructors, response fields, console copy and table formatter.

No expression evaluation, live RPC, session movement, diagnostic-log backend or
App is started. Native excerpts execute against synthetic data and temp bundles.
"""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest

from tools import check_localizations as checker
from tools.tests.test_close_job_list_localization import method
from tools.tests.test_uv_shared_error_localization import member


ROOT = Path(__file__).resolve().parents[2]
COLOR = "invalid 用户 %@"
ERRORS = (
    ("com.iterm2.with-alpha", 1, "with_alpha requires a color string and a numeric alpha"),
    ("com.iterm2.with-alpha", 2, f"with_alpha could not parse color “{COLOR}”"),
    ("com.iterm2.move-session", 1, "Invalid argument"),
    ("com.iterm2.move-session", 2, "Invalid session ID"),
    ("com.iterm2.move-session", 3, "Sessions are not compatible"),
    ("com.iterm2.move-session", 5, "Session has no tab"),
    ("com.iterm2.move-session", 6, "Can't move locked session"),
)
HEADERS = ["Min Time", "Distribution", "Max Time", "# Samples", "Mean Time",
           "P50", "P95", "Total Time", ""]
SAMPLE = ["0.00 µs", "##", "2.00 µs", "3", "1.00 µs", "1.00 µs", "2.00 µs",
          "3.00 µs", "Synthetic trigger 用户"]


class ExpressionDiagnosticLocalizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="iterm2-expression-diagnostics-")
        cls.addClassCleanup(temporary.cleanup)
        root = Path(temporary.name)
        expressions = []
        for name in ("ColorAlphaBuiltInFunction.swift", "MoveSessionBuiltInFunction.swift"):
            source = (ROOT / "sources/Language/BuiltInFunctions" / name).read_text()
            for match in re.finditer(r'NSError\(domain: "com\.iterm2\.(?:with-alpha|move-session)",', source):
                end = checker.swift_delimited_expression_end(source, match.start() + len("NSError"), "(", ")")
                if end is None:
                    raise AssertionError("Unbalanced NSError constructor")
                expressions.append(source[match.start():end])
        if len(expressions) != len(ERRORS):
            raise AssertionError("Expected seven actual built-in error constructors")
        template = (ROOT / "tests/expression_diagnostic_probe.swift").read_text()
        histogram = (ROOT / "sources/Metrology/iTermHistogram.swift").read_text()
        replacements = {
            "// ERROR-CONSTRUCTORS": "return [" + ",\n".join(expressions) + "]",
            "// TABLE-FORMATTER": (ROOT / "sources/Formatting/TabularFormatter.swift").read_text(),
            "// HISTOGRAM-FORMATTER": member(histogram, "static var tabularFormatterTime:"),
        }
        for marker, body in replacements.items():
            if template.count(marker) != 1:
                raise AssertionError(f"Ambiguous fixture marker {marker}")
            template = template.replace(marker, body)
        (root / "main.swift").write_text(template.replace("bundle: .main", "bundle: probeBundle"))
        parser = (ROOT / "sources/Language/iTermParsedExpression.m").read_text()
        api = (ROOT / "sources/API/iTermAPIHelper.m").read_text()
        report = method(api, "+ (void)reportFunctionCallError:")
        console = re.search(r'\[entry addOutput:(\[NSString stringWithFormat:@"An error occurred .*?\])\s+completion:\^\{\}\];', report, re.S)
        if console is None:
            raise AssertionError("Script-console output expression changed")
        (root / "parser-error.inc").write_text(method(parser, "- (instancetype)initWithErrorCode:"))
        (root / "api-response.inc").write_text(method(api, "- (void)functionInvocationDidCompleteWithObject:"))
        (root / "script-console.inc").write_text("NSString *consoleMessage = " + console[1] + ";")
        for command in (
            ["xcrun", "swiftc", "-warnings-as-errors", str(root / "main.swift"), "-o", str(root / "swift-probe")],
            ["xcrun", "clang", "-fobjc-arc", "-Wall", "-Werror", "-framework", "Foundation",
             "-I", str(root), str(ROOT / "tests/expression_api_diagnostic_probe.m"), "-o", str(root / "objc-probe")],
        ):
            compiled = subprocess.run(command, capture_output=True, text=True, timeout=45)
            if compiled.returncode:
                raise AssertionError(compiled.stdout + compiled.stderr)
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        cls.snapshots = {}
        for language in ("en", "zh-Hans"):
            resources = root / f"{language}.lproj"
            resources.mkdir()
            values = {key: entry["localizations"][language]["stringUnit"]["value"]
                      for key, entry in catalog.items() if key.startswith((
                          "ui.swift.language.builtinfunctions.coloralphabuiltinfunction.",
                          "ui.swift.language.builtinfunctions.movesessionbuiltinfunction.",
                          "ui.language.itermparsedexpression.", "ui.swift.metrology.itermhistogram."))}
            (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))
            swift = subprocess.run([str(root / "swift-probe"), str(resources)],
                                   capture_output=True, text=True, timeout=5)
            if swift.returncode:
                raise AssertionError(swift.stderr)
            payload = root / "errors.json"
            payload.write_text(swift.stdout)
            objc = subprocess.run([str(root / "objc-probe"), str(resources), str(payload)],
                                  capture_output=True, text=True, timeout=5)
            if objc.returncode:
                raise AssertionError(objc.stderr)
            cls.snapshots[language] = (json.loads(swift.stdout), json.loads(objc.stdout))

    def check_error(self, row, domain, code, reason):
        self.assertEqual(row, {
            "domain": domain, "code": code, "userInfo": {"NSLocalizedDescription": reason},
            "apiReason": reason, "failed": True,
            "console": f"An error occurred while running the function invocation “iterm2.synthetic()”:\n{reason}\n\nTraceback:\nsynthetic traceback",
        })

    def test_builtin_errors_keep_raw_api_and_console_text(self):
        for language, (native, consumer) in self.snapshots.items():
            self.assertEqual(len(native["errors"]), 7)
            self.assertEqual(len(consumer["builtins"]), 7)
            for index, (row, expected) in enumerate(zip(consumer["builtins"], ERRORS)):
                with self.subTest(language=language, constructor=index):
                    self.check_error(row, *expected)

    def test_parser_fallback_and_supplied_reason_keep_raw_text(self):
        for language, (_, consumer) in self.snapshots.items():
            self.assertEqual(len(consumer["parser"]), 3)
            for index, (row, reason) in enumerate(zip(consumer["parser"], ("Unknown error", "", "Supplied 用户 %@"))):
                with self.subTest(language=language, case=index):
                    self.check_error(row, "com.iterm2.parser", 7, reason)

    def test_histogram_diagnostic_table_preserves_english_header_and_alignment(self):
        widths = [max(len(label), len(value)) for label, value in zip(HEADERS, SAMPLE)]
        def formatted(row):
            return "  ".join(value.ljust(width) if index in (1, 8) else value.rjust(width)
                             for index, (value, width) in enumerate(zip(row, widths)))
        expected = formatted(HEADERS) + "\n" + formatted(SAMPLE)
        for language, (native, _) in self.snapshots.items():
            with self.subTest(language=language):
                self.assertEqual(native["table"], expected)


if __name__ == "__main__":
    unittest.main()
