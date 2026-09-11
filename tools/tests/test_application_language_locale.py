"""Compare real locale inference before/after CN language startup, in fresh processes."""

import json
import pathlib
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]


@unittest.skipUnless(sys.platform == "darwin", "requires macOS Foundation and UNIX locales")
class ApplicationLanguageLocaleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="iterm2-cn-locale-input-")
        cls.addClassCleanup(cls.temporary.cleanup)
        directory = pathlib.Path(cls.temporary.name)
        include = ["-I", str(ROOT / "sources/Settings"), "-I", str(ROOT / "sources/Categories")]
        objects = []
        for source in ("tests/application_language_locale_probe.m",
                       "sources/Settings/iTermApplicationLanguageController.m",
                       "sources/Categories/NSBundle+iTerm.m"):
            obj = directory / (pathlib.Path(source).stem + ".o")
            cls.run_compiler(["xcrun", "clang", "-fobjc-arc", "-Wall", "-Wextra", "-Werror",
                              *include,
                              "-c", str(ROOT / source), "-o", str(obj)])
            objects.append(str(obj))
        executable = directory / "LocaleProbe"
        cls.run_compiler(["xcrun", "swiftc", "-swift-version", "5", "-warnings-as-errors", *include,
                          "-import-objc-header", str(ROOT / "tests/application_language_locale_probe.h"),
                          str(ROOT / "tests/application_language_locale_probe.swift"),
                          str(ROOT / "sources/Locale/iTermLocaleGuesser.swift"),
                          *objects, "-o", str(executable)])
        cls.executables = {}
        for edition in ("upstream", "cn"):
            contents = directory / (edition + ".app") / "Contents"
            binary = contents / "MacOS" / "LocaleProbe"
            binary.parent.mkdir(parents=True)
            shutil.copy2(executable, binary)
            (contents / "Info.plist").write_bytes(plistlib.dumps({
                "CFBundleExecutable": "LocaleProbe",
                "CFBundleIdentifier": "com.iterm2.tests.locale-input-probe." + edition,
                "CFBundlePackageType": "APPL",
                "CFBundleDevelopmentRegion": "en",
                "CFBundleLocalizations": ["en", "zh-Hans"],
                "iTermCNCommunityBuild": edition == "cn",
            }))
            resources = contents / "Resources"
            for language, marker in (("en", "EN"), ("zh-Hans", "ZH")):
                resource = resources / f"{language}.lproj" / "Localizable.strings"
                resource.parent.mkdir(parents=True)
                resource.write_text(f'"probe" = "{marker}";\n', encoding="utf-8")
            shutil.copy2(ROOT / "plists/EncodingsWithLowerCase.plist", resources)
            cls.executables[edition] = binary

    @classmethod
    def run_compiler(cls, command):
        result = subprocess.run(command, capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)

    def run_probe(self, edition, selection, languages, locale, encoding=4, fixture=None):
        if fixture is None:
            fixture = {"AppleLanguages": languages, "AppleLocale": locale}
        apple_languages = "(" + ",".join(json.dumps(item) for item in languages) + ")"
        result = subprocess.run([
            str(self.executables[edition]), selection, json.dumps(fixture), str(encoding),
            "-AppleLanguages", apple_languages, "-AppleLocale", locale,
        ], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        data = json.loads(result.stdout)
        self.assertTrue(data["globalUnchanged"], data)
        self.assertTrue(data["environmentUnchanged"], data)
        if edition == "cn" and selection != "system":
            self.assertEqual(data["localized"], "ZH" if selection == "zh-Hans" else "EN", data)
        return {key: data[key] for key in ("lang", "ctype")}

    def test_ui_language_does_not_change_default_locale(self):
        fixtures = [
            (["zh-Hans-JP", "ja-JP", "en-US"], "zh-Hans_JP"),
            (["en-US"], "en_US"),
            (["zh-Hans-CN", "en-US"], "zh-Hans_CN"),
            (["ja-JP", "en-US"], "ja_JP"),
            (["de-DE", "en-US"], "de_DE"),
            (["fr-CA", "en-CA"], "fr_CA"),
        ]
        for languages, locale in fixtures:
            baseline = self.run_probe("upstream", "system", languages, locale)
            for selection in ("en", "zh-Hans", "system", "removed-language"):
                with self.subTest(locale=locale, selection=selection):
                    self.assertEqual(self.run_probe("cn", selection, languages, locale), baseline)

    def test_non_utf8_encoding_selection_is_unchanged(self):
        for encoding in (1, 5, 8, 30):
            baseline = self.run_probe("upstream", "system", ["ja-JP"], "ja_JP", encoding)
            for selection in ("en", "zh-Hans", "system"):
                with self.subTest(encoding=encoding, selection=selection):
                    self.assertEqual(self.run_probe("cn", selection, ["ja-JP"], "ja_JP", encoding),
                                     baseline)

    def test_app_region_override_does_not_replace_system_region(self):
        fixture = {"AppleLanguages": ["en-GB", "en-US"], "AppleLocale": "en_GB"}
        baseline = self.run_probe("upstream", "system", fixture["AppleLanguages"], "en_GB")
        for selection in ("en", "zh-Hans", "system"):
            with self.subTest(selection=selection):
                self.assertEqual(self.run_probe("cn", selection, ["ja-JP"], "ja_JP", fixture=fixture),
                                 baseline)

    def test_absent_or_malformed_preferences_do_not_fall_back_to_ui_language(self):
        fixtures = [{}, {"AppleLanguages": "en-US", "AppleLocale": 7},
                    {"AppleLanguages": [7], "AppleLocale": "en_US"}]
        for fixture in fixtures:
            for selection in ("en", "zh-Hans", "system"):
                with self.subTest(fixture=fixture, selection=selection):
                    result = self.run_probe("cn", selection, ["en-US"], "en_US", fixture=fixture)
                    self.assertIsNone(result["lang"])
                    self.assertEqual(result["ctype"], {"LC_CTYPE": "UTF-8"})

    def test_missing_region_preserves_language_based_fallback(self):
        fixture = {"AppleLanguages": ["en-US"], "AppleLocale": 7}
        for selection in ("en", "zh-Hans", "system"):
            with self.subTest(selection=selection):
                result = self.run_probe("cn", selection, ["ja-JP"], "ja_JP", fixture=fixture)
                self.assertEqual(result["lang"], "en_US.UTF-8")


if __name__ == "__main__":
    unittest.main()
