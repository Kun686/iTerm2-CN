"""Native help display with stable backreferences, interpolation names, and URL."""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest

from tools.tests.test_uv_shared_error_localization import member


ROOT = Path(__file__).resolve().parents[2]
PREFIX = "ui.settings.itermsemantichistoryprefscontroller.help."
SHORT_KEYS = {2: "url", 4: "command_file", 5: "command_text", 6: "coprocess", 7: "send_text"}


class SemanticHistoryHelpLocalizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="iterm2-semantic-help-")
        cls.addClassCleanup(temporary.cleanup)
        cls.directory = Path(temporary.name)
        source = (ROOT / "sources/Settings/iTermSemanticHistoryPrefsController.m").read_text()
        action = member(source, "- (IBAction)actionChanged:")
        cases = re.findall(r"case (\d+): \{.*?(NSString \*text\s*=.*?;)\s*"
                           r"caveat_\.attributedStringValue", action, re.S)
        if [int(tag) for tag, _ in cases] != list(SHORT_KEYS):
            raise AssertionError("Expected the five actual help display cases")
        link = member(source, "- (NSAttributedString *)attributedStringWithLearnMoreLinkAfterText:")
        expressions = re.findall(r"attributedStringWithLinkToURL:(.*?) string:(.*?)\];", link, re.S)
        if len(expressions) != 1:
            raise AssertionError("Expected the actual help link constructor")
        template = (ROOT / "tests/semantic_history_help_probe.m").read_text()
        for marker, content in {
            "// HELP-DETAIL-METHOD": member(source, "- (NSString *)detailTextForCurrentMode"),
            "// HELP-SHORT-CASES": "\n".join(f"case {tag}: {{ {body} return text; }}"
                                              for tag, body in cases),
            "/* HELP-LINK-URL */": expressions[0][0],
            "/* HELP-LINK-TITLE */": expressions[0][1],
        }.items():
            if template.count(marker) != 1:
                raise AssertionError("Expected one template marker: " + marker)
            template = template.replace(marker, content)
        probe_source = cls.directory / "probe.m"
        probe_source.write_text(template.replace("NSBundle.mainBundle", "probeBundle"))
        cls.probe = cls.directory / "semantic-help-probe"
        result = subprocess.run(
            ["xcrun", "clang", "-fobjc-arc", "-Wall", "-Wextra", "-Werror", "-framework",
             "Foundation", str(probe_source), "-o", str(cls.probe)],
            capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        cls.translations = {}
        for language in ("en", "zh-Hans"):
            resources = cls.directory / f"{language}.lproj"
            resources.mkdir()
            values = {key: entry["localizations"][language]["stringUnit"]["value"]
                      for key, entry in catalog.items() if key.startswith(PREFIX)}
            cls.translations[language] = values
            (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))

    def check_language(self, language):
        result = subprocess.run([str(self.probe), str(self.directory / f"{language}.lproj")],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        values = self.translations[language]
        self.assertEqual(len(values), 9)
        self.assertEqual(data["linkURL"], "iterm2-private://semantic-history-learn-more/")
        self.assertEqual(len(data["rows"]), 7)
        for tag, row in enumerate(data["rows"], 1):
            with self.subTest(language=language, tag=tag):
                self.assertEqual(row["tag"], tag)
                if tag in (1, 3):
                    self.assertEqual(row["short"], "")
                    self.assertEqual(row["detail"], "")
                    continue
                key = PREFIX + SHORT_KEYS[tag]
                self.assertEqual(row["short"], values[key])
                self.assertEqual(re.findall(r"\\[1-5]", row["short"]),
                                 [f"\\{number}" for number in range(1, 3 if tag == 2 else 6)])
                mode = "any_click" if tag == 5 else "existing_file"
                self.assertEqual(row["detail"], values[PREFIX + mode] + values[PREFIX + "substitutions"])
                self.assertEqual(re.findall(r"\\\(semanticHistory\.([A-Za-z]+)\)", row["detail"]),
                                 ["path", "lineNumber", "columnNumber", "prefix", "suffix", "workingDirectory"])
        self.assertEqual(data["linkTitle"], values[PREFIX + "learn_more"])

    def test_english_help_and_parameters(self):
        self.check_language("en")

    def test_chinese_help_and_parameters(self):
        self.check_language("zh-Hans")


if __name__ == "__main__":
    unittest.main()
