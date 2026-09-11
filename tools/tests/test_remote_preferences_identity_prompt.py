"""Native manual-upload help follows the app or isolated suite, not the official ID."""
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

from tools.tests.test_uv_shared_error_localization import member


ROOT = Path(__file__).resolve().parents[2]
KEY = "ui.settings.itermremotepreferences.to_make_it_available_first_quit_iterm2_and.e177c2bb"
ORIGINAL_PATH = "~/Library/Preferences/com.googlecode.iterm2.plist"
DOMAINS = ("com.googlecode.iterm2", "com.kun686.iterm2-cn",
           "cn-isolated-synthetic", "cn.测试.synthetic")


class RemotePreferencesIdentityPromptTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="iterm2-remote-prefs-prompt-")
        cls.addClassCleanup(temporary.cleanup)
        cls.directory = Path(temporary.name)
        source = (ROOT / "sources/Settings/iTermRemotePreferences.m").read_text()
        flow = member(source, "- (void)saveLocalUserDefaultsToRemotePrefsInteractive:(BOOL)interactive\n{")
        branch = member(flow, "if ([folder stringIsUrlLike])")
        if branch.count("NSAlert *alert =") != 1 or branch.count("alert.informativeText = informativeText;") != 1:
            raise AssertionError("Expected the actual URL-upload alert consumer")
        construction = branch[branch.index("{") + 1:branch.index("NSAlert *alert =")]
        construction = construction.replace("[[NSBundle mainBundle] bundleIdentifier]",
                                            "[ProbeIdentity bundleIdentifier]")
        construction = construction.replace("NSBundle.mainBundle", "probeBundle")
        template = (ROOT / "tests/remote_preferences_identity_prompt_probe.m").read_text()
        marker = "// REMOTE-UPLOAD-PROMPT"
        if template.count(marker) != 1:
            raise AssertionError("Expected one prompt insertion point")
        probe_source = cls.directory / "probe.m"
        probe_source.write_text(template.replace(marker, construction))
        cls.probe = cls.directory / "remote-prefs-prompt-probe"
        result = subprocess.run(
            ["xcrun", "clang", "-fobjc-arc", "-Wall", "-Wextra", "-Werror", "-framework",
             "Foundation", str(probe_source), "-o", str(cls.probe)],
            capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        entry = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"][KEY]
        cls.templates = {}
        for language in ("en", "zh-Hans"):
            resources = cls.directory / f"{language}.lproj"
            resources.mkdir()
            value = entry["localizations"][language]["stringUnit"]["value"]
            cls.templates[language] = value.replace(ORIGINAL_PATH, "{path}").replace(
                "%1$@", "{path}").replace("%@", "{path}")
            if cls.templates[language].count("{path}") != 1:
                raise AssertionError("Expected one manual-upload path in " + language)
            (resources / "Localizable.strings").write_bytes(plistlib.dumps({KEY: value}))

    def check_language(self, language):
        result = subprocess.run([str(self.probe), str(self.directory / f"{language}.lproj")],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = json.loads(result.stdout)
        self.assertEqual(len(rows), len(DOMAINS))
        for domain, message in zip(DOMAINS, rows):
            with self.subTest(language=language, domain=domain):
                path = f"~/Library/Preferences/{domain}.plist"
                self.assertEqual(message, self.templates[language].format(path=path))

    def test_english_manual_upload_identity(self):
        self.check_language("en")

    def test_chinese_manual_upload_identity(self):
        self.check_language("zh-Hans")


if __name__ == "__main__":
    unittest.main()
