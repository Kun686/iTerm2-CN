"""Keep shared PTY diagnostics stable; they are not display-only UI strings.

The native probe compiles the production error-construction excerpt, not a
rewritten model. It does not launch the app, fork a shell, or send notifications.
"""
import errno
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
EXPECTED = "Unable to fork child process: you may have too many processes already running."


class PTYDiagnosticLocalizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="iterm2-pty-diagnostic-")
        cls.addClassCleanup(temporary.cleanup)
        cls.directory = Path(temporary.name)
        source = (ROOT / "sources/Tasks/PTYTask.m").read_text(encoding="utf-8")
        case = source.split("case iTermJobManagerForkAndExecStatusFailedToFork: {", 1)[1]
        cls.failure_case = case.split("\n            break;", 1)[0]
        start = cls.failure_case.index("NSString *error =")
        end = cls.failure_case.index("[[iTermNotificationController sharedInstance] notify:", start)
        (cls.directory / "fork-error.inc").write_text(cls.failure_case[start:end], encoding="utf-8")
        cls.probe = cls.directory / "fork-error-probe"
        compiled = subprocess.run(
            ["xcrun", "clang", "-fobjc-arc", "-Wall", "-Wextra", "-Werror",
             "-framework", "Foundation", "-I", str(cls.directory),
             str(ROOT / "tests/pty_fork_error_probe.m"), "-o", str(cls.probe)],
            capture_output=True, text=True, timeout=60,
        )
        if compiled.returncode:
            raise AssertionError(compiled.stdout + compiled.stderr)
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text(encoding="utf-8"))["strings"]
        for language in ("en", "zh-Hans"):
            resources = cls.directory / f"{language}.lproj"
            resources.mkdir()
            values = {
                key: entry["localizations"][language]["stringUnit"]["value"]
                for key, entry in catalog.items()
                if key.startswith("ui.tasks.ptytask.")
            }
            (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))

    def check_diagnostic(self, language, error_code):
        result = subprocess.run(
            [str(self.probe), str(self.directory / f"{language}.lproj"),
             "none" if error_code is None else str(error_code)],
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        expected = EXPECTED
        if error_code is not None:
            expected += " The system error was: " + os.strerror(error_code)
        self.assertEqual(result.stdout, expected + "\n")

    def test_english_without_errno(self):
        self.check_diagnostic("en", None)

    def test_english_with_errno(self):
        self.check_diagnostic("en", errno.EAGAIN)

    def test_chinese_without_errno(self):
        self.check_diagnostic("zh-Hans", None)

    def test_chinese_with_errno(self):
        self.check_diagnostic("zh-Hans", errno.EAGAIN)

    def test_shared_diagnostic_still_reaches_original_consumers(self):
        self.assertIn("withDescription:error];", self.failure_case)
        self.assertIn("[self.delegate taskDiedWithError:error];", self.failure_case)
        session = (ROOT / "sources/PTYSession/PTYSession.m").read_text(encoding="utf-8")
        delegate = session.split("- (void)taskDiedWithError:(NSString *)error {", 1)[1].split("\n}", 1)[0]
        self.assertIn("@selector(brokenPipeWithError:) withObject:error", delegate)
        broken_pipe = session.split("- (void)brokenPipeWithError:(NSString *)message {", 1)[1].split("\n}", 1)[0]
        self.assertIn('RLog(@"  brokenPipe %@ task=%@ message=%@\\n%@", self, self.shell, message,', broken_pipe)
        self.assertIn("[self appendBrokenPipeMessage:message];", broken_pipe)


if __name__ == "__main__":
    unittest.main()
