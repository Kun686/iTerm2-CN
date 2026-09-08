"""Execute real Swift plugin-spec -> diagnostic/UI expressions without I/O.

Bundle lookup and the log sink are redirected. Only the spec declarations,
error enum, verification-error constructor expressions and two log statements
are extracted; networking, installation, signature checks and permissions never
execute. This is not live plugin installation or pairing acceptance.
"""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest

from tools.tests.test_uv_shared_error_localization import member


ROOT = Path(__file__).resolve().parents[2]
PREFIX = "ui.swift.companion.companionplugininstaller."
PLUGINS = (
    ("AI plugin", "https://iterm2.com/downloads/ai-plugin/iTermAI-1.1.zip",
     "com.googlecode.iterm2.iTermAI"),
    ("companion plugin", "https://iterm2.com/downloads/companion-plugin/iTermCompanion-1.0.zip",
     "com.googlecode.iterm2.iTermCompanion"),
)


class CompanionPluginNameLocalizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="iterm2-companion-plugin-name-")
        cls.addClassCleanup(temporary.cleanup)
        cls.directory = Path(temporary.name)
        source = (ROOT / "sources/Companion/CompanionPluginInstaller.swift").read_text()
        specs = source.split("enum CompanionPluginInstaller {", 1)[1].split(
            "    /// Download, install, register, and verify the AI plugin.", 1)[0]
        logs = re.findall(r'^\s*RLog\("Companion installer: (?:downloading|installed) .*$', source, re.M)
        if len(logs) != 2:
            raise AssertionError("Expected both actual plugin-name diagnostic consumers")
        replacements = {
            "// PLUGIN-ERROR-ENUM": member(source, "enum CompanionPluginInstallerError:"),
            "// PLUGIN-SPECS": specs,
            "// PLUGIN-LOG-CONSUMERS": "\n".join(logs),
        }
        for marker, function in (("AI", "installAIPlugin"), ("COMPANION", "installCompanionPlugin")):
            body = member(source, f"static func {function}(")
            errors = re.findall(r"throw (CompanionPluginInstallerError\.verificationFailed\(.+\))", body)
            if len(errors) != 1:
                raise AssertionError("Expected one production verification error in " + function)
            replacements[f"// PLUGIN-{marker}-ERROR"] = "error = " + errors[0]
        template = (ROOT / "tests/companion_plugin_name_probe.swift").read_text()
        for marker, replacement in replacements.items():
            template = template.replace(marker, replacement)
        template = template.replace("bundle: .main", "bundle: probeBundle")
        swift_path = cls.directory / "main.swift"
        swift_path.write_text(template)
        cls.probe = cls.directory / "plugin-name-probe"
        compiled = subprocess.run(
            ["xcrun", "swiftc", "-warnings-as-errors", str(swift_path), "-o", str(cls.probe)],
            capture_output=True, text=True, timeout=60)
        if compiled.returncode:
            raise AssertionError(compiled.stdout + compiled.stderr)
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        cls.names = {}
        cls.verification_templates = {}
        for language in ("en", "zh-Hans"):
            resources = cls.directory / f"{language}.lproj"
            resources.mkdir()
            values = {key: entry["localizations"][language]["stringUnit"]["value"]
                      for key, entry in catalog.items() if key.startswith(PREFIX)}
            (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))
            cls.names[language] = {
                entry["localizations"]["en"]["stringUnit"]["value"]: values[key]
                for key, entry in catalog.items() if key in values
            }
            cls.verification_templates[language] = values[PREFIX + "the_0_did_not_load_after_installation.8d90e8e2"]
            if cls.verification_templates[language].count("%1$@") != 1:
                raise AssertionError("Expected one positional plugin-name placeholder")

    def check_language(self, language):
        result = subprocess.run([str(self.probe), str(self.directory / f"{language}.lproj")],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(len(data["plugins"]), 2)
        for row, (raw, url, bundle_id) in zip(data["plugins"], PLUGINS):
            expected_display = self.verification_templates[language].replace("%1$@", self.names[language][raw])
            expectations = {
                "name": raw, "storedErrorName": raw, "url": url, "bundleID": bundle_id,
                "logs": [f"Companion installer: downloading {raw} from {url}",
                         f"Companion installer: installed {raw} at /synthetic/Plugins/Example.app; LSRegisterURL status 0"],
                "displayed": expected_display,
            }
            for field, expected in expectations.items():
                with self.subTest(language=language, plugin=raw, field=field):
                    self.assertEqual(row[field], expected)
        self.assertEqual([row["name"] for row in data["unknown"]],
                         ["", "User plugin 用户 %@", "AI and companion plugins"])
        for row in data["unknown"]:
            with self.subTest(language=language, unknown=row["name"]):
                expected = self.verification_templates[language].replace("%1$@", row["name"])
                self.assertEqual(row["displayed"], expected)

    def test_english_diagnostics_and_display(self):
        self.check_language("en")

    def test_chinese_diagnostics_and_display(self):
        self.check_language("zh-Hans")


if __name__ == "__main__":
    unittest.main()
