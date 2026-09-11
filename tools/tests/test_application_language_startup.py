"""Exercise real startup localization in fresh macOS processes, before caching."""

import pathlib
import plistlib
import subprocess
import sys
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]


@unittest.skipUnless(sys.platform == "darwin", "requires macOS Foundation")
class ApplicationLanguageStartupTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="iterm2-cn-language-startup-")
        cls.addClassCleanup(cls.temporary.cleanup)
        contents = pathlib.Path(cls.temporary.name) / "LanguageProbe.app" / "Contents"
        cls.executable = contents / "MacOS" / "LanguageProbe"
        cls.executable.parent.mkdir(parents=True)
        (contents / "Info.plist").write_bytes(plistlib.dumps({
            "CFBundleExecutable": "LanguageProbe",
            "CFBundleIdentifier": "com.iterm2.tests.language-startup-probe",
            "CFBundlePackageType": "APPL",
            "CFBundleDevelopmentRegion": "en",
            "CFBundleLocalizations": ["en", "zh-Hans"],
            "iTermCNCommunityBuild": True,
        }))
        for language, marker in (("en", "EN"), ("zh-Hans", "ZH")):
            resource = contents / "Resources" / f"{language}.lproj" / "Localizable.strings"
            resource.parent.mkdir(parents=True)
            resource.write_text(f'"probe" = "{marker}";\n', encoding="utf-8")
        result = subprocess.run([
            "xcrun", "clang", "-fobjc-arc", "-Wall", "-Wextra", "-Werror",
            "-framework", "Foundation",
            "-I", str(ROOT / "sources/Settings"),
            "-I", str(ROOT / "sources/Categories"),
            str(ROOT / "tests/application_language_startup_probe.m"),
            str(ROOT / "sources/Settings/iTermApplicationLanguageController.m"),
            str(ROOT / "sources/Categories/NSBundle+iTerm.m"),
            "-o", str(cls.executable),
        ], capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)

    def check_language(self, selected, initial, expected):
        # The initial process language makes the premature-cache regression
        # deterministic without modifying any global or real-app preferences.
        result = subprocess.run([
            str(self.executable), selected, expected,
            "-AppleLanguages", f"({initial})",
        ], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_saved_english_overrides_initial_chinese_before_bundle_lookup(self):
        self.check_language("en", "zh-Hans", "EN")

    def test_saved_chinese_overrides_initial_english_before_bundle_lookup(self):
        self.check_language("zh-Hans", "en", "ZH")

    def test_unknown_saved_selection_falls_back_to_english_before_bundle_lookup(self):
        self.check_language("removed-language", "zh-Hans", "EN")


if __name__ == "__main__":
    unittest.main()
