"""Exercise production error expressions, not a translated error-factory model.

These are construction probes, not live transfer tests. FileTransferManager's
actual callback and fallback paths are covered by the native XCTest class.
"""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class FileTransferDiagnosticLocalizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="iterm2-transfer-diagnostic-")
        cls.addClassCleanup(temporary.cleanup)
        cls.directory = Path(temporary.name)
        cls.terminal = (ROOT / "sources/FileTransfer/TerminalFile.m").read_text(encoding="utf-8")
        cls.scp = (ROOT / "sources/FileTransfer/SCPFile.m").read_text(encoding="utf-8")
        # Bound extraction to the existing single-line call sites. Assert counts
        # so a refactor cannot silently turn this into an empty passing test.
        terminal_errors = re.findall(
            r'\[self errorWithDescription:((?:@"|NSLocalizedStringWithDefaultValue\().+?)\](?=[;\]])',
            cls.terminal,
        )
        scp_errors = re.findall(r'SCPFileError\((.+)\)(?=[;\]])', cls.scp)
        scp_fallbacks = re.findall(
            r'\[NSError errorWithDomain:@"[^"\n]+"\s+code:-?\d+\s+userInfo:[^\n]+?\](?=;)',
            cls.scp,
        )
        if (len(terminal_errors), len(scp_errors), len(scp_fallbacks)) != (4, 6, 2):
            raise AssertionError("Transfer error call sites changed; review the extraction boundary")
        terminal_factory = "- (NSError *)errorWithDescription:(NSString *)description {"
        terminal_factory += cls.terminal.split(terminal_factory, 1)[1].split("\n}", 1)[0] + "\n}\n"
        scp_factory = "static NSError *SCPFileError(NSString *description) {"
        scp_factory += cls.scp.split(scp_factory, 1)[1].split("\n}", 1)[0] + "\n}\n"
        domain = re.search(r'^static NSString \*const kSCPFileErrorDomain = .*;$', cls.scp, re.M)
        if domain is None:
            raise AssertionError("Missing production SCP error domain")
        includes = {
            "terminal-error-factory.inc": terminal_factory,
            "scp-error-factory.inc": domain[0] + "\n" + scp_factory,
            "terminal-error-expressions.inc": ",\n".join(
                "[self errorWithDescription:" + expression + "]" for expression in terminal_errors),
            "scp-error-expressions.inc": ",\n".join(
                ["SCPFileError(" + expression + ")" for expression in scp_errors] + scp_fallbacks),
        }
        for name, source in includes.items():
            (cls.directory / name).write_text(source, encoding="utf-8")
        cls.probe = cls.directory / "transfer-error-probe"
        compiled = subprocess.run(
            ["xcrun", "clang", "-fobjc-arc", "-Wall", "-Wextra", "-Werror",
             "-framework", "Foundation", "-I", str(cls.directory),
             str(ROOT / "tests/file_transfer_error_probe.m"), "-o", str(cls.probe)],
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
                if key.startswith(("ui.filetransfer.terminalfile.", "ui.filetransfer.scpfile."))
            }
            (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))

    def check_errors(self, language, transfer_type):
        result = subprocess.run(
            [str(self.probe), str(self.directory / f"{language}.lproj"), transfer_type],
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        if transfer_type == "terminal":
            messages = ["Canceled.", "No data received.",
                        "File corrupted (not valid base64).", "Failed to set quarantine."]
            expected = [dict(domain="com.googlecode.iterm2.TerminalFile", code=1, message=text)
                        for text in messages]
        else:
            messages = ["Invalid filename", "Downloads folder not writable", "Download failed",
                        "Upload failed", "Canceled by user", "Canceled by user"]
            expected = [dict(domain="com.googlecode.iterm2.SCPFile", code=1, message=text)
                        for text in messages]
            expected.extend([
                dict(domain="com.googlecode.iterm2", code=-1, message="Could not connect."),
                dict(domain="com.googlecode.iterm2.SCPFile", code=0, message="Authentication failed."),
            ])
        self.assertEqual(json.loads(result.stdout), expected)

    def test_terminal_english(self):
        self.check_errors("en", "terminal")

    def test_terminal_chinese(self):
        self.check_errors("zh-Hans", "terminal")

    def test_scp_english(self):
        self.check_errors("en", "scp")

    def test_scp_chinese(self):
        self.check_errors("zh-Hans", "scp")

    def test_shared_error_consumers_remain_present(self):
        manager = (ROOT / "sources/FileTransfer/FileTransferManager.m").read_text(encoding="utf-8")
        self.assertIn('RLog(@"Transfer finished. error=%@", error);', manager)
        self.assertIn("NSString *errorMessage = error.localizedDescription;", manager)
        self.assertIn("transferrableFile.completionBlock(success, errorMessage);", manager)
        # The SCP display wrapper is separate from the shared NSError. Keep it
        # translated, including the existing security/authentication UI labels.
        self.assertIn('self.error = NSLocalizedStringWithDefaultValue(@"'
                      'ui.filetransfer.scpfile.quarantine_error.', self.scp)
        self.assertIn('ui.filetransfer.scpfile.remote_host_identification_has_changed_', self.scp)
        self.assertIn('ui.filetransfer.terminalfile.save_terminal_initiated_download.', self.terminal)


if __name__ == "__main__":
    unittest.main()
