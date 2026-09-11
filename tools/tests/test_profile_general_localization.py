import json
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
PREVIEW_KEYS = {
    "titleForSessionName": ("name", "Name"),
    "profileName": ("profile", "Profile"),
    "job": ("job", "Job"),
    "commandLine": ("job_and_arguments", "Job+Args"),
    "user": ("user", "User"),
    "host": ("host", "Host"),
}
PREFIX = "ui.settings.profile.title_preview."


class ProfileGeneralLocalizationTests(unittest.TestCase):
    def test_reviewed_help_uses_paired_chinese_quotes(self):
        catalog = json.loads((ROOT / "sources/Settings/PreferencePanel.xcstrings").read_text())["strings"]
        for key, label in (("q57-nJ-Jbz.ibShadowedToolTip", "会话"),
                           ("wgv-Ah-fFr.ibShadowedToolTip", "通用"),
                           ("KWy-PJ-O0E.ibShadowedToolTip", "正常")):
            with self.subTest(key=key):
                text = catalog[key]["localizations"]["zh-Hans"]["stringUnit"]["value"]
                self.assertIn("「" + label + "」", text)
                self.assertEqual(text.count("「"), text.count("」"))

    def test_labels_fit_native_font_without_moving_neighbors(self):
        with tempfile.TemporaryDirectory(prefix="iterm2-profile-labels-") as temporary:
            probe = Path(temporary) / "label-metrics"
            compiled = subprocess.run(
                ["xcrun", "swiftc", str(ROOT / "tests/profile_general_label_metrics.swift"),
                 "-o", str(probe)], capture_output=True, text=True, timeout=60
            )
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            result = subprocess.run([str(probe), str(ROOT)], capture_output=True,
                                    text=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            measurements = json.loads(result.stdout)
            self.assertEqual(len(measurements), 4)
            self.assertTrue(all(value["passed"] for value in measurements))

    def test_display_only_title_samples_are_localized(self):
        source = (ROOT / "sources/Settings/ProfilesGeneralPreferencesViewController.m").read_text()
        start = source.index("titleSettings.title = customName ?:")
        preview = source[start:source.index("isWindowTitle:NO];", start)]
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        for argument, (suffix, english) in PREVIEW_KEYS.items():
            key = PREFIX + suffix
            with self.subTest(argument=argument):
                self.assertRegex(preview, re.escape(argument) + r':\s*NSLocalizedStringWithDefaultValue\(@"' + re.escape(key) + r'"')
                entry = catalog[key]["localizations"]
                self.assertEqual(entry["en"]["stringUnit"]["value"], english)
                chinese = entry["zh-Hans"]["stringUnit"]["value"]
                self.assertTrue(chinese)
                self.assertNotEqual(chinese, english)
        # Real environment/protocol abbreviations remain unchanged.
        self.assertIn('pwd:@"PWD"', preview)
        self.assertIn('tty:@"TTY"', preview)
        self.assertIn('aiTitle:@"AI"', preview)


if __name__ == "__main__":
    unittest.main()
