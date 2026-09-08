"""Native shared-error and download-display excerpts, not live API/install tests."""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest

from tools import check_localizations as checker


ROOT = Path(__file__).resolve().parents[2]
IMPORT_MESSAGES = (
    "Another import is in progress. Please try again after it completes.",
    "Could not unzip archive: %@",
    "This script archive is corrupt and cannot be installed.",
    "This is not a valid iTerm2 script archive.",
    "Unknown error",
    "Could not find certificate after verficiation (nil data)",
    "Could not find certificate after verficiation (bad data)",
    "Installation canceled by user request.",
    "This archive was created by an older version of iTerm2. This kind of archive is no longer supported and cannot be installed.",
    "Archive does not contain a valid iTerm2 script",
    "Could not replace “%@”: the existing script could not be moved aside, so it was left unchanged.",
)


def method(source, signature):
    start = source.index(signature)
    opening = source.index("{", start)
    end = checker.objc_braced_block_end(source, opening)
    if end is None:
        raise AssertionError("Unbalanced production method")
    return source[start:end]


class APIDiagnosticLocalizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="iterm2-api-diagnostic-")
        cls.addClassCleanup(temporary.cleanup)
        cls.directory = Path(temporary.name)
        cls.importer = (ROOT / "sources/API/iTermScriptImporter.m").read_text()
        cls.download = (ROOT / "sources/API/iTermOptionalComponentDownloadWindowController.m").read_text()
        runtime = (ROOT / "sources/API/iTermPythonRuntimeDownloader.m").read_text()
        cls.runtime = runtime
        calls = []
        for start in re.finditer(r"\bcompletion\(", cls.importer):
            end = checker.swift_delimited_expression_end(cls.importer, start.end() - 1, "(", ")")
            if end is None:
                raise AssertionError("Unbalanced production callback")
            calls.append(cls.importer[start.start():end] + ";")
        rows = []
        cls.import_expected = []
        for original in IMPORT_MESSAGES:
            matches = [call for call in calls if original in call]
            if len(matches) != (2 if original == "Unknown error" else 1):
                raise AssertionError(f"Changed callback extraction: {original}")
            for call in matches:
                second = call.startswith("completion(nil,")
                consumer = "secondSnapshot(" if second else "firstSnapshot("
                rows.extend([
                    "error = " + ("nil;" if original == "Unknown error" else "externalError;"),
                    "[imports addObject:" + call[:-1].replace("completion(", consumer, 1) + "];",
                ])
                operand = "external 原文" if original.startswith("Could not unzip") else "synthetic 用户脚本"
                cls.import_expected.append(original.replace("%@", operand))
        message_start = cls.importer.index("NSString *message = canceled")
        message_end = cls.importer.index("completion(message, NO, nil);", message_start)
        assignment = cls.importer[message_start:message_end]
        for canceled, value, expected in (
                ("YES", "externalError", "Replacing “synthetic 用户脚本” was canceled. The existing script was kept."),
                ("NO", "nil", "The script could not be installed."),
                ("NO", "externalError", "external 原文")):
            rows.append("{ canceled = " + canceled + "; error = " + value + ";\n" + assignment +
                        "[imports addObject:snapshot(message)]; }")
            cls.import_expected.append(expected)
        log = re.search(r'DLog\(@"errorMessage=%@ quiet=%@ location=%@", errorMessage, @\(quiet\), location\);', cls.importer)
        if log is None:
            raise AssertionError("Shared callback logging changed")
        titles = re.findall(r'super initWithURL:url title:(.+) nextPhaseFactory:nextPhaseFactory', cls.download)
        if len(titles) != 2:
            raise AssertionError("Expected two phase title sources")
        uv = (ROOT / "sources/API/iTermUvProvisioner.swift").read_text()
        uv_title = re.search(r'self\.fetcher\.fetch\(url: url, title: ("[^"\n]+"), byteCount: entry.size\)', uv)
        if uv_title is None or "title: title," not in uv:
            raise AssertionError("Expected original uv title forwarded to the download phase")
        titles.append("@" + uv_title[1])
        installing_title = re.search(r'return \[\[iTermInstallingPhase alloc\] initWithURL:nil title:(.+) nextPhaseFactory:nil\];', runtime)
        if installing_title is None:
            raise AssertionError("Expected the original installing-phase initializer")
        titles.append(installing_title[1])
        display = re.search(r'_titleLabel\.stringValue = [^;]*phase\.title[^;]*;', cls.download)
        status = re.search(r'\[_downloadController showMessage:(.+)\];', runtime)
        if display is None or status is None:
            raise AssertionError("Download display consumer changed")
        helper_signature = "static NSString *iTermLocalizedPythonDownloadDisplayString(NSString *diagnostic)"
        helper = method(cls.download, helper_signature) if helper_signature in cls.download else ""
        includes = {
            "import-log.inc": log[0], "import-calls.inc": "\n".join(rows),
            "phase-init.inc": method(cls.download, "- (instancetype)initWithURL:"),
            "phase-description.inc": method(cls.download, "- (NSString *)description {"),
            "phase-titles.inc": ",\n".join(titles),
            "phase-display.inc": display[0],
            "show-message.inc": method(cls.download, "- (void)showMessage:(NSString *)message {"),
            "status-message.inc": "[display showMessage:" + status[1] + "];",
            "download-display-helper.inc": helper,
        }
        for name, source in includes.items():
            (cls.directory / name).write_text(source)
        cls.probe = cls.directory / "api-diagnostic-probe"
        result = subprocess.run(
            ["xcrun", "clang", "-fobjc-arc", "-Wall", "-Wextra", "-Werror", "-framework", "AppKit",
             "-I", str(cls.directory), str(ROOT / "tests/api_diagnostic_localization_probe.m"), "-o", str(cls.probe)],
            capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        cls.translations = {}
        for language in ("en", "zh-Hans"):
            resources = cls.directory / f"{language}.lproj"
            resources.mkdir()
            values = {key: entry["localizations"][language]["stringUnit"]["value"]
                      for key, entry in catalog.items() if key.startswith((
                          "ui.api.itermscriptimporter.", "ui.api.itermoptionalcomponentdownloadwindowcontroller.",
                          "ui.api.itermpythonruntimedownloader.", "ui.swift.api.itermuvprovisioner.downloading_uv."))}
            (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))
            cls.translations[language] = {
                entry["localizations"]["en"]["stringUnit"]["value"]: values[key]
                for key, entry in catalog.items() if key in values}

    def run_probe(self, language):
        result = subprocess.run([str(self.probe), str(self.directory / f"{language}.lproj")],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def check_import(self, language):
        rows = self.run_probe(language)["imports"]
        self.assertEqual(len(rows), 15)
        for row, expected in zip(rows, self.import_expected):
            with self.subTest(message=expected):
                self.assertEqual(row["message"], expected)
                self.assertEqual(row["log"], f"errorMessage={expected} quiet=0 location=(null)")

    def check_download(self, language):
        result = self.run_probe(language)
        originals = ("Finding latest version…", "Downloading Python runtime…", "Downloading uv…", "Download Finished")
        self.assertEqual(len(result["phases"]), len(originals))
        for row, expected in zip(result["phases"], originals):
            with self.subTest(title=expected):
                self.assertEqual(row["stored"], expected)
                self.assertIn(f"title={expected} nextPhaseFactory=", row["description"])
                self.assertEqual(row["displayed"], self.translations[language][expected])
        status = "✅ The Python runtime is up to date."
        self.assertEqual(result["status"]["log"], "message=" + status)
        self.assertEqual(result["status"]["displayed"], self.translations[language][status])
        passthrough = ("", "User-provided 用户内容", "Unknown future status")
        self.assertEqual(len(result["passthrough"]), len(passthrough))
        for row, original in zip(result["passthrough"], passthrough):
            self.assertEqual(row, {"displayed": original, "log": "message=" + original})

    def test_import_english(self):
        self.check_import("en")

    def test_import_chinese(self):
        self.check_import("zh-Hans")

    def test_download_english(self):
        self.check_download("en")

    def test_download_chinese(self):
        self.check_download("zh-Hans")

    def check_source(self, filename, source):
        with tempfile.TemporaryDirectory(prefix="iterm2-api-checker-") as directory:
            sources = Path(directory)
            path = sources / "API" / filename
            path.parent.mkdir()
            path.write_text(source)
            return (checker.check_hardcoded_english_objc_ui_literals(sources)
                    + checker.check_hardcoded_english_objc_localized_description_fallbacks(sources)
                    + checker.check_hardcoded_english_objc_script_completion_messages(sources))

    def test_checker_accepts_reviewed_import_diagnostics(self):
        self.assertEqual(self.check_source("iTermScriptImporter.m", self.importer), [])

    def test_checker_rejects_other_import_literals_and_consumers(self):
        variants = (
            self.importer.replace("Another import is in progress.", "Different import failure."),
            self.importer.replace("+ (void)reallyImportScriptFromURL:", "+ (void)otherMethod:"),
            self.importer.replace('DLog(@"errorMessage=%@ quiet=%@ location=%@", errorMessage, @(quiet), location);', ""),
            self.importer.replace('@"Another import is in progress. Please try again after it completes.", NO, nil)',
                                  '@"Another import is in progress. Please try again after it completes.", YES, nil)'),
            self.importer.replace('NSString *message = canceled', 'NSString *message = !canceled'),
            self.importer.replace('replacedScriptBackup:(NSString *)replacedScriptBackup',
                                  'otherBackup:(NSString *)replacedScriptBackup'),
            self.importer + '\n- (void)other { label.title = @"Unknown error"; }\n',
        )
        for index, variant in enumerate(variants):
            with self.subTest(variant=index):
                self.assertTrue(self.check_source("iTermScriptImporter.m", variant))
        self.assertTrue(self.check_source("OtherImporter.m", self.importer))

    def test_checker_accepts_delayed_download_display(self):
        self.assertEqual(self.check_source("iTermOptionalComponentDownloadWindowController.m", self.download), [])

    def test_checker_accepts_installing_phase_diagnostic_title(self):
        self.assertEqual(self.check_source("iTermPythonRuntimeDownloader.m", self.runtime), [])

    def test_checker_rejects_other_installing_titles(self):
        variants = (
            self.runtime.replace("- (void)checkForNewerVersionThan:", "- (void)otherCheck:"),
            self.runtime.replace("[[iTermInstallingPhase alloc] initWithURL:nil title:",
                                 "[[OtherPhase alloc] initWithURL:nil title:"),
            self.runtime.replace('title:@"Download Finished" nextPhaseFactory:nil',
                                 'title:@"Download Finished" nextPhaseFactory:other'),
            self.runtime.replace('title:@"Download Finished"', 'title:@"Different title"'),
            self.runtime.replace('[_downloadController beginPhase:manifestPhase];', ''),
            self.runtime + '\n- (void)other { label.title = @"Download Finished"; }\n',
        )
        for index, variant in enumerate(variants):
            with self.subTest(variant=index):
                self.assertTrue(self.check_source("iTermPythonRuntimeDownloader.m", variant))
        self.assertTrue(self.check_source("OtherDownloader.m", self.runtime))

    def test_checker_rejects_other_download_titles(self):
        variants = (
            self.download.replace("@implementation iTermManifestDownloadPhase", "@implementation OtherPhase"),
            self.download.replace("super initWithURL:url title:", "other initWithURL:url title:"),
            self.download.replace("Finding latest version…", "Different download title"),
            self.download.replace("iTermLocalizedPythonDownloadDisplayString(phase.title)", "phase.title"),
            self.download.replace("_title, _nextPhaseFactory", "@\"different\", _nextPhaseFactory"),
            self.download + '\n- (void)other { label.title = @"Finding latest version…"; }\n',
        )
        for index, variant in enumerate(variants):
            with self.subTest(variant=index):
                self.assertTrue(self.check_source("iTermOptionalComponentDownloadWindowController.m", variant))
        self.assertTrue(self.check_source("OtherDownload.m", self.download))


if __name__ == "__main__":
    unittest.main()
