"""Real Swift NSError factories -> Objective-C import callback/log excerpts.

The native probe redirects only bundle lookups and log destinations. It does
not perform installation, recovery, real logging or network operations.
"""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest

from tools import check_localizations as checker


ROOT = Path(__file__).resolve().parents[2]
PREFIX = "ui.swift.api.itermuvprovisioner."
EXPECTED = (
    "The uv manifest is not valid JSON (a hosting problem, not a macOS-version problem).",
    "The uv manifest lists no usable entries (a hosting or manifest problem).",
    "uv is not available for macOS 14.0.0.",
    "The offered uv version (0.11.0) is older than the minimum required (0.12.0).",
    "The uv manifest declares an implausible download size (0 bytes).",
    "The download was canceled.",
)


def member(source, signature):
    start = source.index(signature)
    opening = source.index("{", start)
    end = checker.swift_braced_block_end(source, opening)
    if end is None:
        raise AssertionError("Unbalanced production member: " + signature)
    return source[start:end]


class UvSharedErrorLocalizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="iterm2-uv-shared-error-")
        cls.addClassCleanup(temporary.cleanup)
        cls.directory = Path(temporary.name)
        source = (ROOT / "sources/API/iTermUvProvisioner.swift").read_text()
        members = [member(source, signature) for signature in (
            "static func selectedEntry(", "static func error(", "static func cancelError(")]
        if "static func diagnosticDescription(" in source:
            members.append(member(source, "static func diagnosticDescription("))
        for name in ("errorDomain", "cancelErrorCode", "maxTarballBytes", "minimumUvVersion"):
            declarations = re.findall(r"^.*static let " + name + r" = .+$", source, re.M)
            if len(declarations) != 1:
                raise AssertionError("Expected one constant: " + name)
            members += declarations
        log = re.search(r'^\s*RLog\("uv: background module upgrade for the .*$', source, re.M)
        if log is None:
            raise AssertionError("Missing production Swift log consumer")
        template = (ROOT / "tests/uv_shared_error_probe.swift").read_text()
        upgrade = member(source, "@objc func userRequestedUpgradeCheck(")
        unavailable = re.search(r'completion\(false, (.+)\) \}', upgrade)
        messages = re.findall(r'^\s*message = (.+)$', upgrade, re.M)
        if unavailable is None or len(messages) != 3 or messages[-1] != "failureMessage":
            raise AssertionError("Changed user-upgrade result switch")
        probe = template.replace("// UV-PRODUCTION-MEMBERS", "\n".join(members)).replace(
            "// UV-PRODUCTION-LOG", log[0]).replace(
                "// UV-UPGRADE-MESSAGES", "return [" + ",\n".join([unavailable[1], *messages[:2]]) + "]"
            ).replace("bundle: .main", "bundle: probeBundle")
        swift_path = cls.directory / "main.swift"
        swift_path.write_text(probe)
        importer = (ROOT / "sources/API/iTermScriptImporter.m").read_text()
        consumers = {
            "uv-import-install-log.inc": 'RLog(@"Install finished with %@", error);',
            "uv-import-completion-log.inc": 'DLog(@"errorMessage=%@ quiet=%@ location=%@", errorMessage, @(quiet), location);',
            "uv-import-forward.inc": 'completion(error.localizedDescription, NO, location);',
        }
        for name, statement in consumers.items():
            if importer.count(statement) != 1:
                raise AssertionError("Changed production consumer: " + statement)
            (cls.directory / name).write_text(statement)
        delegate = (ROOT / "sources/AppKit/iTermApplicationDelegate.m").read_text()
        callback = delegate.split("userRequestedUpgradeCheckWithCompletion:", 1)[1].split("[alert runModal];", 1)[0]
        history = '[[iTermScriptHistoryEntry globalEntry] addOutput:[message stringByAppendingString:@"\\n"] completion:^{}];'
        display = "alert.informativeText = message;"
        for name, statement in (("uv-upgrade-history.inc", history), ("uv-upgrade-display.inc", display)):
            if callback.count(statement) != 1:
                raise AssertionError("Changed shared upgrade consumer: " + statement)
            (cls.directory / name).write_text(statement)
        header = cls.directory / "bridge.h"
        header.write_text('#import <Foundation/Foundation.h>\nNSDictionary * _Nonnull UVImportSnapshot(NSError * _Nonnull error);\n'
                          'NSDictionary * _Nonnull UVUpgradeMessageSnapshot(NSString * _Nonnull message);\n')
        obj = cls.directory / "consumer.o"
        cls.probe = cls.directory / "uv-probe"
        commands = (
            ["xcrun", "clang", "-c", "-fobjc-arc", "-Wall", "-Wextra", "-Werror", "-I", str(cls.directory),
             str(ROOT / "tests/uv_shared_error_consumer_probe.m"), "-o", str(obj)],
            ["xcrun", "swiftc", "-warnings-as-errors", "-import-objc-header", str(header),
             "-framework", "AppKit", str(swift_path), str(ROOT / "sources/API/iTermUvManifest.swift"),
             str(obj), "-o", str(cls.probe)],
        )
        for command in commands:
            result = subprocess.run(command, capture_output=True, text=True, timeout=60)
            if result.returncode:
                raise AssertionError(result.stdout + result.stderr)
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        for language in ("en", "zh-Hans"):
            resources = cls.directory / f"{language}.lproj"
            resources.mkdir()
            values = {key: entry["localizations"][language]["stringUnit"]["value"]
                      for key, entry in catalog.items() if key.startswith(PREFIX)}
            (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))

    def result(self, language):
        fixtures = []
        for version, minimum, size in (("0.13.0", "26.0", 42), ("0.11.0", "13.0", 42),
                                       ("0.13.0", "13.0", 0)):
            fixtures.append(json.dumps([{"uv_version": version, "minimum_macos_version": minimum,
                                         "size": size, "signature": "synthetic",
                                         "url": "https://example.invalid/synthetic.tar.gz"}]))
        result = subprocess.run([str(self.probe), str(self.directory / f"{language}.lproj"), *fixtures],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def rows(self, language):
        rows = self.result(language)["errors"]
        self.assertEqual(len(rows), 7)
        return rows

    def test_upgrade_callback_retains_script_history_text(self):
        originals = ("uv is not installed.", "uv 0.12.0 is up to date.",
                     "Upgraded uv 0.12.0 to 0.13.0. Updated the Python modules in shared environments.")
        for language in ("en", "zh-Hans"):
            rows = self.result(language)["updates"]
            self.assertEqual(len(rows), 3)
            for row, original in zip(rows, originals):
                with self.subTest(language=language, message=original):
                    self.assertEqual(row, {"history": original + "\n", "displayed": original})

    def check_shared_error(self, language):
        for index, (row, expected) in enumerate(zip(self.rows(language), EXPECTED)):
            with self.subTest(language=language, error=index):
                self.assertEqual(row["domain"], "com.googlecode.iterm2.uv")
                self.assertEqual(row["code"], -2 if index == 5 else -1)
                self.assertEqual(row["userInfo"], {"NSLocalizedDescription": expected})
                self.assertEqual(row["objc"]["forwarded"], expected)
                self.assertEqual(row["objc"]["completionLog"],
                                 f"errorMessage={expected} quiet=0 location=(null)")
                self.assertIn(expected, row["objc"]["installLog"])
                self.assertEqual(row["swiftLog"],
                                 f"uv: background module upgrade for the 3.12 venv failed: {expected}")

    def test_shared_error_english(self):
        self.check_shared_error("en")

    def test_shared_error_chinese(self):
        self.check_shared_error("zh-Hans")

    def test_objc_shared_consumers_keep_original_text(self):
        for language in ("en", "zh-Hans"):
            for row, expected in zip(self.rows(language), EXPECTED):
                with self.subTest(language=language, message=expected):
                    self.assertEqual(row["objc"]["forwarded"], expected)
                    self.assertEqual(row["objc"]["completionLog"],
                                     f"errorMessage={expected} quiet=0 location=(null)")
                    self.assertIn(expected, row["objc"]["installLog"])

    def test_external_error_preserves_original_log_operand(self):
        for language in ("en", "zh-Hans"):
            with self.subTest(language=language):
                row = self.rows(language)[-1]
                self.assertEqual(row["domain"], "external.synthetic")
                self.assertEqual(row["code"], 42)
                self.assertEqual(row["userInfo"], {"NSLocalizedDescription": "External 原文",
                                                    "NSDebugDescription": "Different diagnostic detail"})
                self.assertEqual(row["swiftLog"],
                                 "uv: background module upgrade for the 3.12 venv failed: External 原文")


if __name__ == "__main__":
    unittest.main()
