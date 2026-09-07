#!/usr/bin/env python3

import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "check_localizations.py"


class LocalizationCheckCLITests(unittest.TestCase):
    def setUp(self):
        self._temporary_directory = tempfile.TemporaryDirectory()
        self.project_root = Path(self._temporary_directory.name)
        self.sources = self.project_root / "sources"
        (self.sources / "Base.lproj").mkdir(parents=True)
        (self.sources / "Settings").mkdir()
        (self.project_root / "iTerm2.xcodeproj").mkdir()
        (self.project_root / "iTerm2.xcodeproj" / "project.pbxproj").write_text(
            "// minimal localization checker fixture\n", encoding="utf-8"
        )
        self._write_registry(("zh-Hans", "en", "system"))
        self._write_catalog(
            "Localizable.xcstrings",
            {
                "fixture.greeting": {
                    "en": "Hello, %@!",
                    "zh-Hans": "你好，%@！",
                }
            },
        )
        self._write_catalog(
            "InfoPlist.xcstrings",
            {
                "NSCameraUsageDescription": {
                    "en": "Camera access",
                    "zh-Hans": "摄像头访问",
                }
            },
        )

    def tearDown(self):
        self._temporary_directory.cleanup()

    def _write_registry(self, identifiers, registered_identifiers=None):
        constant_names = {
            identifier: f"Fixture{index}"
            for index, identifier in enumerate(identifiers)
        }
        declarations = "\n".join(
            f'iTermApplicationLanguageIdentifier const {constant_names[identifier]} = @"{identifier}";'
            for identifier in identifiers
        )
        if registered_identifiers is None:
            registered_identifiers = identifiers
        entries = "\n".join(
            "            @{\n"
            "                iTermApplicationLanguageRegistryIdentifierKey:\n"
            f"                    {constant_names.get(identifier, identifier)},\n"
            "            },"
            for identifier in registered_identifiers
        )
        registry = (
            "\n\nstatic NSArray *iTermApplicationLanguageRegistry(void) {\n"
            "    NSArray *registry = @[\n"
            f"{entries}\n"
            "    ];\n"
            "    return registry;\n"
            "}\n"
        )
        path = self.sources / "Settings" / "iTermApplicationLanguageController.m"
        path.write_text(declarations + registry, encoding="utf-8")

    def _write_catalog(self, relative_path, entries):
        strings = {}
        for key, localizations in entries.items():
            strings[key] = {
                "localizations": {
                    language: {
                        "stringUnit": {
                            "state": "translated",
                            "value": value,
                        }
                    }
                    for language, value in localizations.items()
                }
            }
        path = self.sources / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(
                {
                    "sourceLanguage": "en",
                    "strings": strings,
                    "version": "1.0",
                },
                ensure_ascii=False,
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

    def _run_checker(self, project_root=None):
        return subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--project-root",
                str(project_root or self.project_root),
            ],
            capture_output=True,
            text=True,
            check=False,
        )

    def _write_tip_data(self, omitted_runtime_marker=None):
        tip_directory = self.sources / "TIps"
        tip_directory.mkdir(exist_ok=True)
        runtime_markers = (
            '@"ui.tips.data.%@.%@"',
            "localizedStringForKey:key",
            'iTermLocalizedTipValue(identifier, @"title"',
            'iTermLocalizedTipValue(identifier, @"body"',
        )
        source = "\n".join(
            marker
            for marker in runtime_markers
            if marker != omitted_runtime_marker
        )
        source += (
            '\n@"000": @{ kTipTitleKey: @"Tip of the Day",\n'
            '           kTipBodyKey: @"Learn a useful feature." };\n'
        )
        (tip_directory / "iTermTipData.m").write_text(source, encoding="utf-8")

    def _write_tip_catalog(self, english_title="Tip of the Day"):
        self._write_catalog(
            "TIps/iTermTipData.xcstrings",
            {
                "ui.tips.data.000.title": {
                    "en": english_title,
                    "zh-Hans": "每日提示",
                },
                "ui.tips.data.000.body": {
                    "en": "Learn a useful feature.",
                    "zh-Hans": "了解一个实用功能。",
                },
            },
        )

    def _write_source_plist(self, name, values):
        path = self.project_root / "plists" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(plistlib.dumps(values))
        return path

    def test_valid_resources_pass(self):
        result = self._run_checker()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Localization check passed", result.stdout)

    def _write_advanced_settings_fixture(self):
        (self.sources / "Settings/iTermAdvancedSettingsModel.m").write_text(
            '#define SECTION_BADGE @"Badge: "\n'
            'DEFINE_STRING(badgeFont, @".AppleSystemUIFont", SECTION_BADGE '
            '@"Font to use for the badge.\\nLeave empty for the default.");\n'
            'DEFINE_INT_ENUM(badgeMode, 1, (@[ @"Never", @"Always" ]), '
            'SECTION_BADGE @"Badge mode.");\n', encoding="utf-8"
        )

    def test_advanced_settings_missing_dynamic_resources_fail(self):
        self._write_advanced_settings_fixture()
        result = self._run_checker()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("ui.advanced.setting.BadgeFont.description", result.stderr)
        self.assertIn("ui.advanced.group.Badge", result.stderr)
        self.assertIn("ui.advanced.setting.BadgeMode.option.1", result.stderr)

    def _write_valid_advanced_settings_resources(self):
        self._write_advanced_settings_fixture()
        self._write_catalog("Localizable.xcstrings", {
            "ui.advanced.group.Badge": {"en": "Badge", "zh-Hans": "徽标"},
            "ui.advanced.setting.BadgeFont.description": {
                "en": "Font to use for the badge.\nLeave empty for the default.",
                "zh-Hans": "徽标字体。\n留空使用默认值。"},
            "ui.advanced.setting.BadgeMode.description": {"en": "Badge mode.", "zh-Hans": "徽标模式。"},
            "ui.advanced.setting.BadgeMode.option.0": {"en": "Never", "zh-Hans": "从不"},
            "ui.advanced.setting.BadgeMode.option.1": {"en": "Always", "zh-Hans": "始终"},
        })
        self._advanced_runtime = self.sources / "Settings/iTermAdvancedSettingsViewController.m"
        self._advanced_runtime.write_text('\n'.join((
            '@"ui.advanced.group.%@"', '@"ui.advanced.setting.%@.description"',
            '@"ui.advanced.setting.%@.option.%lu"', 'localizedStringForKey:key',
            'temp[kAdvancedSettingDescription] = iTermAdvancedSettingsLocalizedDescription(dict, remainder)',
            'iTermAdvancedSettingsLocalizedGroup(groupName)',
            'iTermAdvancedSettingsSearchText(dict)',
            'iTermAdvancedSettingsLocalizedOption(identifier, index, title)',
        )), encoding="utf-8")

    def test_advanced_settings_valid_dynamic_resources_pass(self):
        self._write_valid_advanced_settings_resources()
        result = self._run_checker()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_advanced_settings_english_source_drift_fails(self):
        self._write_valid_advanced_settings_resources()
        model = self.sources / "Settings/iTermAdvancedSettingsModel.m"
        model.write_text(model.read_text().replace("Badge mode.", "New badge mode."), encoding="utf-8")
        result = self._run_checker()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("English fallback differs", result.stderr)

    def test_advanced_settings_missing_runtime_lookup_fails(self):
        self._write_valid_advanced_settings_resources()
        self._advanced_runtime.write_text("// iTermAdvancedSettingsLocalizedGroup(groupName)", encoding="utf-8")
        result = self._run_checker()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("localization runtime is missing", result.stderr)

    def test_advanced_settings_missing_enum_option_fails(self):
        self._write_valid_advanced_settings_resources()
        catalog = self.sources / "Localizable.xcstrings"
        data = json.loads(catalog.read_text())
        del data["strings"]["ui.advanced.setting.BadgeMode.option.1"]
        catalog.write_text(json.dumps(data), encoding="utf-8")
        result = self._run_checker()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("ui.advanced.setting.BadgeMode.option.1", result.stderr)

    def test_advanced_settings_extracts_adjacent_literals_not_defaults_or_deprecated(self):
        self._write_valid_advanced_settings_resources()
        model = self.sources / "Settings/iTermAdvancedSettingsModel.m"
        model.write_text(
            model.read_text().replace('@"Font to use for the badge.\\nLeave empty for the default."',
                                     '@"Font to use for the badge.\\n" @"Leave empty for the default."') +
            '\nDEFINE_DEPRECATED_STRING(oldBadge, @"old default", SECTION_BADGE @"No longer displayed");\n' +
            '#define DEFINE_FIXTURE(name) \\\nDEFINE_STRING(name, @"default", @"macro body");\n', encoding="utf-8")
        result = self._run_checker()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_advanced_settings_unparseable_display_fails_closed(self):
        self._write_valid_advanced_settings_resources()
        model = self.sources / "Settings/iTermAdvancedSettingsModel.m"
        model.write_text(model.read_text().replace('SECTION_BADGE @"Badge mode."', 'makeDescription()'), encoding="utf-8")
        result = self._run_checker()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unknown advanced settings section", result.stderr)

    def test_about_product_name_must_match_cn_identity(self):
        self._write_catalog(
            "AboutWindow/AboutWindow.xcstrings",
            {
                "U4n-GV-8aZ.title": {
                    "en": "iTerm2",
                    "zh-Hans": "iTerm2-CN",
                }
            },
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "AboutWindow.xcstrings: U4n-GV-8aZ.title[en]: expected CN "
            "product name 'iTerm2-CN', found 'iTerm2'",
            result.stderr,
        )

    def test_declared_but_unregistered_localization_fails(self):
        self._write_registry(
            ("zh-Hans", "en", "system", "fr"),
            registered_identifiers=("zh-Hans", "en", "system"),
        )
        self._write_catalog(
            "Localizable.xcstrings",
            {
                "fixture.greeting": {
                    "en": "Hello",
                    "zh-Hans": "你好",
                    "fr": "Bonjour",
                }
            },
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("localization 'fr' is not registered", result.stderr)

    def test_registered_literal_identifier_is_supported(self):
        self._write_registry(
            ("zh-Hans", "en", "system"),
            registered_identifiers=("zh-Hans", "en", '@"system"'),
        )

        result = self._run_checker()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_unknown_registry_constant_fails(self):
        self._write_registry(
            ("zh-Hans", "en", "system"),
            registered_identifiers=(
                "zh-Hans",
                "en",
                "system",
                "MissingLanguageIdentifier",
            ),
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "unresolved language registry identifier 'MissingLanguageIdentifier'",
            result.stderr,
        )

    def test_duplicate_registry_identifier_fails(self):
        self._write_registry(
            ("zh-Hans", "en", "system"),
            registered_identifiers=("zh-Hans", "en", "system", "en"),
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate language registry identifier 'en'", result.stderr)

    def test_missing_localization_fails(self):
        self._write_catalog(
            "Localizable.xcstrings",
            {"fixture.greeting": {"en": "Hello"}},
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "fixture.greeting: missing localization 'zh-Hans'", result.stderr
        )

    def test_empty_translation_fails(self):
        self._write_catalog(
            "Localizable.xcstrings",
            {
                "fixture.greeting": {
                    "en": "Hello",
                    "zh-Hans": "   ",
                }
            },
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "fixture.greeting[zh-Hans]: translation is empty", result.stderr
        )

    def test_nontranslated_chinese_unit_fails(self):
        path = self.sources / "Localizable.xcstrings"
        document = json.loads(path.read_text(encoding="utf-8"))
        document["strings"]["fixture.greeting"]["localizations"]["zh-Hans"][
            "stringUnit"
        ]["state"] = "new"
        path.write_text(
            json.dumps(document, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "fixture.greeting[zh-Hans]: translation state is 'new'",
            result.stderr,
        )

    def test_nonplural_variation_paths_must_match(self):
        path = self.sources / "Localizable.xcstrings"
        document = json.loads(path.read_text(encoding="utf-8"))
        entry = document["strings"]["fixture.greeting"]
        entry["localizations"] = {
            "en": {
                "variations": {
                    "device": {
                        "mac": {
                            "stringUnit": {
                                "state": "translated",
                                "value": "Hello, %@!",
                            }
                        },
                        "other": {
                            "stringUnit": {
                                "state": "translated",
                                "value": "Hello, %@!",
                            }
                        },
                    }
                }
            },
            "zh-Hans": {
                "variations": {
                    "device": {
                        "mac": {
                            "stringUnit": {
                                "state": "translated",
                                "value": "你好，%@！",
                            }
                        }
                    }
                }
            },
        }
        path.write_text(
            json.dumps(document, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "fixture.greeting[zh-Hans]: variation structure differs",
            result.stderr,
        )

    def test_locale_specific_plural_categories_may_differ(self):
        path = self.sources / "Localizable.xcstrings"
        document = json.loads(path.read_text(encoding="utf-8"))
        entry = document["strings"]["fixture.greeting"]
        entry["localizations"] = {
            "en": {
                "variations": {
                    "plural": {
                        "one": {
                            "stringUnit": {
                                "state": "translated",
                                "value": "%ld item",
                            }
                        },
                        "other": {
                            "stringUnit": {
                                "state": "translated",
                                "value": "%ld items",
                            }
                        },
                    }
                }
            },
            "zh-Hans": {
                "variations": {
                    "plural": {
                        "other": {
                            "stringUnit": {
                                "state": "translated",
                                "value": "%ld 项",
                            }
                        }
                    }
                }
            },
        }
        path.write_text(
            json.dumps(document, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_nontranslatable_structural_whitespace_is_ignored(self):
        self._write_catalog(
            "Localizable.xcstrings",
            {"fixture.spacer": {"en": " ", "zh-Hans": " "}},
        )
        path = self.sources / "Localizable.xcstrings"
        document = json.loads(path.read_text(encoding="utf-8"))
        entry = document["strings"]["fixture.spacer"]
        entry["shouldTranslate"] = False
        path.write_text(
            json.dumps(document, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_missing_format_placeholder_fails(self):
        self._write_catalog(
            "Localizable.xcstrings",
            {
                "fixture.greeting": {
                    "en": "Hello, %@!",
                    "zh-Hans": "你好！",
                }
            },
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "fixture.greeting[zh-Hans]: format placeholders differ",
            result.stderr,
        )

    def test_format_placeholder_type_mismatch_fails(self):
        self._write_catalog(
            "Localizable.xcstrings",
            {
                "fixture.count": {
                    "en": "%1$ld item",
                    "zh-Hans": "%1$@ 项",
                }
            },
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fixture.count[zh-Hans]: format placeholders differ", result.stderr)

    def test_plain_percentage_phrase_is_not_a_format_placeholder(self):
        self._write_catalog(
            "Localizable.xcstrings",
            {
                "fixture.percentage": {
                    "en": "% of screen width",
                    "zh-Hans": "屏幕宽度百分比",
                }
            },
        )

        result = self._run_checker()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_positional_placeholders_may_be_reordered(self):
        self._write_catalog(
            "Localizable.xcstrings",
            {
                "fixture.reordered": {
                    "en": "%1$@ on %2$@",
                    "zh-Hans": "%2$@ 上的 %1$@",
                }
            },
        )

        result = self._run_checker()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_railroad_label_with_dsl_delimiter_fails(self):
        self._write_catalog(
            "Localizable.xcstrings",
            {
                "ui.swift.regexvisualization.icuregextorailroadconverter.fixture": {
                    "en": "safe label",
                    "zh-Hans": "不安全`标签",
                }
            },
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "railroad label contains a DSL delimiter",
            result.stderr,
        )

    def test_duplicate_catalog_key_fails(self):
        path = self.sources / "Localizable.xcstrings"
        path.write_text(
            """{
  "sourceLanguage": "en",
  "strings": {
    "fixture.duplicate": {
      "localizations": {
        "en": {"stringUnit": {"state": "translated", "value": "One"}},
        "zh-Hans": {"stringUnit": {"state": "translated", "value": "一"}}
      }
    },
    "fixture.duplicate": {
      "localizations": {
        "en": {"stringUnit": {"state": "translated", "value": "Two"}},
        "zh-Hans": {"stringUnit": {"state": "translated", "value": "二"}}
      }
    }
  },
  "version": "1.0"
}
""",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate key 'fixture.duplicate'", result.stderr)

    def test_damaged_catalog_fails(self):
        (self.sources / "Localizable.xcstrings").write_text("{", encoding="utf-8")

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("invalid string catalog", result.stderr)

    def test_unregistered_localization_fails(self):
        self._write_catalog(
            "Localizable.xcstrings",
            {
                "fixture.greeting": {
                    "en": "Hello",
                    "zh-Hans": "你好",
                    "fr": "Bonjour",
                }
            },
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("localization 'fr' is not registered", result.stderr)

    def test_unregistered_lproj_directory_fails(self):
        (self.sources / "fr.lproj").mkdir()

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("localization directory 'fr.lproj' is not registered", result.stderr)

    def test_missing_resource_directory_fails(self):
        result = self._run_checker(self.project_root / "missing-project")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("resource directory does not exist", result.stderr)

    def test_missing_info_catalog_fails(self):
        (self.sources / "InfoPlist.xcstrings").unlink()

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "InfoPlist.xcstrings: required Info.plist catalog is missing",
            result.stderr,
        )

    def test_source_plist_usage_description_present_in_catalog_passes(self):
        self._write_source_plist(
            "iTerm2.plist",
            {"NSCameraUsageDescription": "Camera access"},
        )

        result = self._run_checker()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_source_plist_usage_description_missing_from_catalog_fails(self):
        source_plist = self._write_source_plist(
            "iTerm2.plist",
            {"NSMicrophoneUsageDescription": "Microphone access"},
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "missing privacy usage description key 'NSMicrophoneUsageDescription'",
            result.stderr,
        )
        self.assertIn(str(source_plist), result.stderr)

    def test_missing_base_localization_directory_fails(self):
        (self.sources / "Base.lproj").rmdir()

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Base localization directory is missing", result.stderr)

    def test_catalog_without_english_source_language_fails(self):
        path = self.sources / "Localizable.xcstrings"
        document = json.loads(path.read_text(encoding="utf-8"))
        document["sourceLanguage"] = "fr"
        path.write_text(
            json.dumps(document, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("sourceLanguage must be 'en'", result.stderr)

    def test_newline_structure_mismatch_fails(self):
        self._write_catalog(
            "Localizable.xcstrings",
            {
                "fixture.multiline": {
                    "en": "First line\nSecond line",
                    "zh-Hans": "第一行，第二行",
                }
            },
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fixture.multiline[zh-Hans]: control structure differs", result.stderr)

    def test_malformed_strings_file_fails(self):
        path = self.sources / "en.lproj" / "Localizable.strings"
        path.parent.mkdir()
        path.write_text('"fixture.greeting" = ;\n', encoding="utf-8")

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("invalid .strings file", result.stderr)

    def test_malformed_stringsdict_file_fails(self):
        path = self.sources / "en.lproj" / "Plural.stringsdict"
        path.parent.mkdir()
        path.write_text("<plist><dict>", encoding="utf-8")

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("invalid .stringsdict file", result.stderr)

    def test_duplicate_strings_key_fails(self):
        path = self.sources / "en.lproj" / "Localizable.strings"
        path.parent.mkdir()
        path.write_text(
            '"fixture.duplicate" = "One";\n'
            '"fixture.duplicate" = "Two";\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate key 'fixture.duplicate'", result.stderr)

    def test_strings_key_sets_must_match(self):
        english = self.sources / "en.lproj" / "Legacy.strings"
        chinese = self.sources / "zh-Hans.lproj" / "Legacy.strings"
        english.parent.mkdir()
        chinese.parent.mkdir()
        english.write_text(
            '"fixture.first" = "First";\n"fixture.second" = "Second";\n',
            encoding="utf-8",
        )
        chinese.write_text(
            '"fixture.first" = "第一";\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Legacy.strings[zh-Hans]: missing key 'fixture.second'",
            result.stderr,
        )

    def test_duplicate_stringsdict_key_fails(self):
        path = self.sources / "en.lproj" / "Plural.stringsdict"
        path.parent.mkdir()
        path.write_text(
            """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>fixture.duplicate</key><string>One</string>
  <key>fixture.duplicate</key><string>Two</string>
</dict>
</plist>
""",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate key 'fixture.duplicate'", result.stderr)

    def test_stringsdict_key_sets_must_match(self):
        english = self.sources / "en.lproj" / "Plural.stringsdict"
        chinese = self.sources / "zh-Hans.lproj" / "Plural.stringsdict"
        english.parent.mkdir()
        chinese.parent.mkdir()
        english.write_bytes(
            plistlib.dumps(
                {
                    "fixture.first": {"NSStringLocalizedFormatKey": "%#@first@"},
                    "fixture.second": {"NSStringLocalizedFormatKey": "%#@second@"},
                }
            )
        )
        chinese.write_bytes(
            plistlib.dumps(
                {"fixture.first": {"NSStringLocalizedFormatKey": "%#@first@"}}
            )
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Plural.stringsdict[zh-Hans]: missing key 'fixture.second'",
            result.stderr,
        )

    def test_stringsdict_format_metadata_paths_must_match(self):
        english = self.sources / "en.lproj" / "Plural.stringsdict"
        chinese = self.sources / "zh-Hans.lproj" / "Plural.stringsdict"
        english.parent.mkdir()
        chinese.parent.mkdir()
        english.write_bytes(
            plistlib.dumps(
                {
                    "fixture.items": {
                        "NSStringLocalizedFormatKey": "%#@items@",
                        "items": {
                            "NSStringFormatSpecTypeKey": "NSStringPluralRuleType",
                            "NSStringFormatValueTypeKey": "ld",
                            "other": "%ld items",
                        },
                    }
                }
            )
        )
        chinese.write_bytes(
            plistlib.dumps(
                {
                    "fixture.items": {
                        "NSStringLocalizedFormatKey": "%#@items@",
                        "items": {
                            "NSStringFormatSpecTypeKey": "NSStringPluralRuleType",
                            "other": "%ld 项",
                        },
                    }
                }
            )
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "missing format metadata path items.NSStringFormatValueTypeKey",
            result.stderr,
        )

    def test_hard_coded_chinese_source_string_fails(self):
        (self.sources / "Feature.swift").write_text(
            'let buttonTitle = "硬编码按钮"\n', encoding="utf-8"
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Feature.swift:1: hard-coded Chinese text", result.stderr)

    def test_hard_coded_english_swift_tooltip_fails(self):
        (self.sources / "Feature.swift").write_text(
            'let button = Button(tooltip: "Reveal embedded command")\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.swift:1: hard-coded English text in Swift UI sink 'tooltip'",
            result.stderr,
        )

    def test_hard_coded_english_swift_mixed_action_labels_fail(self):
        (self.sources / "Feature.swift").write_text(
            'warning.actionLabels = [String(localized: "fixture.greeting"), "Cancel"]\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.swift:1: hard-coded English text in Swift action label",
            result.stderr,
        )

    def test_hard_coded_english_swift_multiline_cancel_label_fails(self):
        (self.sources / "Feature.swift").write_text(
            'warning.cancelLabel =\n    "Cancel"\n', encoding="utf-8"
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.swift:1: hard-coded English text in Swift action label",
            result.stderr,
        )

    def test_hard_coded_english_swift_localized_interpolation_fallback_fails(self):
        (self.sources / "Feature.swift").write_text(
            'func message(arguments: [String]) -> String {\n'
            '    return String(localized: "fixture.greeting", '
            'defaultValue: "Run \\(arguments.first ?? "command")", '
            'bundle: .main, comment: "UI")\n'
            '}\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.swift:2: hard-coded English text in Swift localized "
            "interpolation fallback",
            result.stderr,
        )

    def test_hard_coded_english_swift_trigger_provider_fails(self):
        triggers = self.sources / "Triggers"
        triggers.mkdir()
        (triggers / "FeatureTrigger.swift").write_text(
            "final class FeatureTrigger: Trigger {\n"
            "    override var description: String {\n"
            '        return "Display Message"\n'
            "    }\n"
            "}\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "FeatureTrigger.swift:3: hard-coded English text returned by "
            "Swift UI provider 'description'",
            result.stderr,
        )

    def test_hard_coded_english_swift_status_bar_provider_fails(self):
        components = self.sources / "StatusBar" / "Components"
        components.mkdir(parents=True)
        (components / "FeatureComponent.swift").write_text(
            "final class FeatureComponent: iTermStatusBarBaseComponent {\n"
            "    override func statusBarComponentDetailedDescription() -> String {\n"
            '        return "Shows current activity."\n'
            "    }\n"
            "}\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "FeatureComponent.swift:3: hard-coded English text returned by "
            "Swift UI provider 'statusBarComponentDetailedDescription'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_alert_text_fails(self):
        (self.sources / "Feature.m").write_text(
            'alert.messageText = @"Debug Logging Enabled";\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:1: hard-coded English text in Objective-C UI sink 'messageText'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_progress_message_fails(self):
        (self.sources / "Feature.m").write_text(
            '[progress showWithMessage:@"Setting up the Python environment…"];\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:1: hard-coded English text in Objective-C UI sink "
            "'showWithMessage'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_recovery_message_fails(self):
        (self.sources / "Feature.m").write_text(
            '[self showErrorForScript:path recovery:@"Check your network and try again."];\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:1: hard-coded English text in Objective-C UI sink "
            "'recovery'",
            result.stderr,
        )

    def test_hard_coded_english_script_import_completion_message_fails(self):
        api = self.sources / "API"
        api.mkdir()
        (api / "iTermScriptImporter.m").write_text(
            'completion([NSString stringWithFormat:@"Could not unzip archive: %@", '
            'error.localizedDescription], NO, nil);\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "iTermScriptImporter.m:1: hard-coded English text in "
            "Objective-C script completion message",
            result.stderr,
        )

    def test_hard_coded_english_assigned_script_import_completion_message_fails(self):
        api = self.sources / "API"
        api.mkdir()
        (api / "iTermScriptImporter.m").write_text(
            "- (void)finish:(BOOL)canceled completion:(void (^)(NSString *))completion {\n"
            "    NSString *message = canceled\n"
            '        ? [NSString stringWithFormat:@"Replacing “%@” was canceled.", name]\n'
            "        : error.localizedDescription;\n"
            "    completion(message);\n"
            "}\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "iTermScriptImporter.m:3: hard-coded English text assigned to "
            "'message' for Objective-C script completion message",
            result.stderr,
        )

    def test_hard_coded_english_script_export_completion_message_fails(self):
        api = self.sources / "API"
        api.mkdir()
        (api / "iTermScriptExporter.m").write_text(
            'completion(@"Failed to create zip file.", nil);\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "iTermScriptExporter.m:1: hard-coded English text in "
            "Objective-C script completion message",
            result.stderr,
        )

    def test_generic_objective_c_completion_text_is_not_assumed_to_be_ui(self):
        (self.sources / "Feature.m").write_text(
            'completion(@"Protocol diagnostic", nil);\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_hard_coded_english_objective_c_warning_heading_fails(self):
        (self.sources / "Feature.m").write_text(
            'warning.heading = @"Python API Permissions Reset";\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:1: hard-coded English text in Objective-C UI sink 'heading'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_notification_title_fails(self):
        (self.sources / "Feature.m").write_text(
            'runner.notificationTitle = @"Command Failed";\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:1: hard-coded English text in Objective-C UI sink "
            "'notificationTitle'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_indirect_notification_title_fails(self):
        (self.sources / "Feature.m").write_text(
            '- (void)runCommand {\n'
            '    NSString *title = @"Command Failed";\n'
            '    runner.notificationTitle = title;\n'
            '}\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:2: hard-coded English text assigned to 'title' for "
            "Objective-C UI sink 'notificationTitle'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_formatted_indirect_warning_fails(self):
        (self.sources / "Feature.m").write_text(
            "- (void)showWarning {\n"
            '    NSString *namesSentence = @"Profiles already exist.";\n'
            "    [iTermWarning showWarningWithTitle:"
            '[NSString stringWithFormat:@"%@", namesSentence] actions:@[]];\n'
            "}\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:2: hard-coded English text assigned to 'namesSentence' "
            "for Objective-C UI sink 'showWarningWithTitle'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_multilevel_indirect_warning_fails(self):
        (self.sources / "Feature.m").write_text(
            "- (void)showWarning {\n"
            '    NSString *namesSentence = @"Profiles already exist.";\n'
            "    NSString *punctuated = "
            '[namesSentence stringByAppendingString:@"."];\n'
            "    NSString *title = "
            '[NSString stringWithFormat:@"%@", punctuated];\n'
            "    [iTermWarning showWarningWithTitle:title actions:@[]];\n"
            "}\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:2: hard-coded English text assigned to 'title' for "
            "Objective-C UI sink 'showWarningWithTitle'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_multiline_alert_text_fails(self):
        (self.sources / "Feature.m").write_text(
            'alert.messageText =\n    @"Debug Logging Enabled";\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:1: hard-coded English text in Objective-C UI sink 'messageText'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_warning_format_fails(self):
        (self.sources / "Feature.m").write_text(
            '[iTermWarning showWarningWithTitle:'
            '[NSString stringWithFormat:@"While loading %@: %@", path, error] '
            'actions:@[]];\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:1: hard-coded English text in Objective-C UI sink "
            "'showWarningWithTitle'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_announcement_title_fails(self):
        (self.sources / "Feature.m").write_text(
            '[iTermAnnouncementViewController '
            'announcementWithTitle:@"File transfer failed" actions:@[]];\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:1: hard-coded English text in Objective-C UI sink "
            "'announcementWithTitle'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_toast_format_fails(self):
        (self.sources / "Feature.m").write_text(
            '[ToastWindowController showToastWithMessage:'
            '[NSString stringWithFormat:@"Pasting at up to %@/sec", rate]];\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:1: hard-coded English text in Objective-C UI sink "
            "'showToastWithMessage'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_localized_description_fallback_fails(self):
        (self.sources / "Feature.m").write_text(
            "- (void)showError:(NSError *)error {\n"
            "    completion(nil, error.localizedDescription "
            '?: @"Unknown error");\n'
            "}\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:2: hard-coded English fallback after localizedDescription",
            result.stderr,
        )

    def test_hard_coded_english_bracketed_localized_description_fallback_fails(self):
        (self.sources / "Feature.m").write_text(
            "- (void)showError:(NSError *)error {\n"
            "    completion(nil, [error localizedDescription] "
            "?: @\"Unknown error\");\n"
            "}\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:2: hard-coded English fallback after localizedDescription",
            result.stderr,
        )

    def test_objective_c_localized_description_log_fallback_is_not_ui_copy(self):
        (self.sources / "Feature.m").write_text(
            "- (void)logError:(NSError *)error {\n"
            '    RLog(@"Request failed: %@", '
            'error.localizedDescription ?: @"Unknown error");\n'
            "}\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_objective_c_assigned_log_only_fallback_is_not_ui_copy(self):
        (self.sources / "Feature.m").write_text(
            "- (void)logError:(NSError *)error {\n"
            "    NSString *reason = error.localizedDescription "
            "?: @\"Unknown error\";\n"
            "    RLog(@\"Request failed: %@\", reason);\n"
            "}\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def _write_shared_transfer_fallback(self, relative="FileTransfer/FileTransferManager.m", *,
                                        message="File transfer failed with an unknown error",
                                        method="transferrableFile", sink="didFailWithError", log=True):
        path = self.sources / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            f'- (void){method}:(TransferrableFile *)transferrableFile\n'
            '    didFinishTransmissionWithError:(NSError *)error {\n'
            '    if (error) {\n'
            f'        [transferrableFile {sink}:error.localizedDescription ?: @"{message}"];\n'
            '    }\n}\n', encoding="utf-8"
        )
        consumer = self.sources / "FileTransfer" / "TransferrableFile.m"
        consumer.parent.mkdir(parents=True, exist_ok=True)
        consumer.write_text(
            '- (void)didFailWithError:(NSString *)error {\n'
            + ('    RLog(@"didFailWithError:%@", error);\n' if log else '')
            + '    [controller notify:error];\n}\n', encoding="utf-8"
        )

    def test_shared_transfer_fallback_is_not_display_only_copy(self):
        self._write_shared_transfer_fallback()
        result = self._run_checker()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_shared_transfer_fallback_rule_does_not_cover_other_files(self):
        self._write_shared_transfer_fallback("Feature.m")
        result = self._run_checker()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("hard-coded English fallback", result.stderr)

    def test_shared_transfer_fallback_rule_does_not_cover_other_methods(self):
        self._write_shared_transfer_fallback(method="showErrorForFile")
        result = self._run_checker()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("hard-coded English fallback", result.stderr)

    def test_shared_transfer_fallback_rule_does_not_cover_other_sinks(self):
        self._write_shared_transfer_fallback(sink="setTitle")
        result = self._run_checker()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("hard-coded English fallback", result.stderr)

    def test_shared_transfer_fallback_rule_does_not_cover_new_text(self):
        self._write_shared_transfer_fallback(message="Please try again")
        result = self._run_checker()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("hard-coded English fallback", result.stderr)

    def test_shared_transfer_fallback_rule_requires_log_consumer(self):
        self._write_shared_transfer_fallback(log=False)
        result = self._run_checker()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("hard-coded English fallback", result.stderr)

    def test_hard_coded_english_objective_c_confirmation_argument_fails(self):
        (self.sources / "Feature.m").write_text(
            '[self closeTabs:tabs confirmWith:@"Close these tabs?" '
            'skippingPinned:YES];\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:1: hard-coded English text in Objective-C UI sink "
            "'confirmWith'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_indirect_warning_fails(self):
        (self.sources / "Feature.m").write_text(
            '- (void)showWarning {\n'
            '    NSString *title = [NSString stringWithFormat:'
            '@"Delete profile %@?", name];\n'
            '    [iTermWarning showWarningWithTitle:title actions:@[]];\n'
            '}\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:2: hard-coded English text assigned to 'title' for "
            "Objective-C UI sink 'showWarningWithTitle'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_async_indirect_warning_fails(self):
        (self.sources / "Feature.m").write_text(
            '- (void)showWarning {\n'
            '    NSString *title = [NSString stringWithFormat:'
            '@"Allow loading URLs from %@?", domain];\n'
            '    [iTermWarning asyncShowWarningWithTitle:title actions:@[]];\n'
            '}\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:2: hard-coded English text assigned to 'title' for "
            "Objective-C UI sink 'asyncShowWarningWithTitle'",
            result.stderr,
        )

    def test_localized_objective_c_indirect_warning_passes(self):
        (self.sources / "Feature.m").write_text(
            '- (void)showWarning {\n'
            '    NSString *title = NSLocalizedStringWithDefaultValue('
            '@"fixture.greeting", nil, NSBundle.mainBundle, @"Hello", @"UI");\n'
            '    [iTermWarning showWarningWithTitle:title actions:@[]];\n'
            '}\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_hard_coded_english_objective_c_indirect_drawn_string_fails(self):
        (self.sources / "Feature.m").write_text(
            '- (void)drawRect:(NSRect)dirtyRect {\n'
            '    NSString *string;\n'
            '    string = self.isEnabled ? @"Click to Set" : @"";\n'
            '    [string drawInRect:frame withAttributes:attributes];\n'
            '}\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:3: hard-coded English text assigned to 'string' for "
            "Objective-C UI sink 'drawInRect'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_shortcut_purpose_fails(self):
        (self.sources / "Feature.m").write_text(
            'shortcut.purpose = @"as a hotkey";\n', encoding="utf-8"
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:1: hard-coded English text in Objective-C UI sink 'purpose'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_indirect_heading_fails(self):
        (self.sources / "Feature.m").write_text(
            '- (void)showWarning {\n'
            '    NSString *heading = @"Replace existing file?";\n'
            '    [iTermWarning showWarningWithTitle:title actions:@[] '
            'heading:heading];\n'
            '}\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:2: hard-coded English text assigned to 'heading' for "
            "Objective-C UI sink 'heading'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_indirect_property_fails(self):
        (self.sources / "Feature.m").write_text(
            '- (void)showError {\n'
            '    NSString *message = @"Connection failed.";\n'
            '    alert.informativeText = message;\n'
            '}\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:2: hard-coded English text assigned to 'message' for "
            "Objective-C UI sink 'informativeText'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_notification_description_fails(self):
        (self.sources / "Feature.m").write_text(
            '- (void)notifyUser {\n'
            '    NSString *description = @"Session became idle.";\n'
            '    [controller notify:title withDescription:description];\n'
            '}\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:2: hard-coded English text assigned to 'description' for "
            "Objective-C UI sink 'withDescription'",
            result.stderr,
        )

    def _write_shared_fork_diagnostic(self, relative="Tasks/PTYTask.m", *,
                                      forward=True, sink="withDescription",
                                      message=None):
        if message is None:
            message = "Unable to fork child process: you may have too many processes already running."
        path = self.sources / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            '- (void)didForkAndExec:(NSString *)progpath withStatus:(int)status '
            'optionalErrorCode:(NSNumber *)optionalErrorCode {\n'
            '    switch (status) {\n'
            '        case iTermJobManagerForkAndExecStatusFailedToFork: {\n'
            f'            NSString *error = @"{message}";\n'
            '            if (optionalErrorCode) {\n'
            '                error = [NSString stringWithFormat:@"%@ The system error was: %s", '
            'error, strerror(optionalErrorCode.intValue)];\n'
            '            }\n'
            f'            [controller notify:title {sink}:error];\n'
            + ('            [self.delegate taskDiedWithError:error];\n' if forward else '')
            + '            break;\n        }\n    }\n}\n', encoding="utf-8"
        )

    def test_shared_fork_diagnostic_is_not_display_only_copy(self):
        self._write_shared_fork_diagnostic()
        result = self._run_checker()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_shared_fork_diagnostic_rule_does_not_cover_other_files(self):
        self._write_shared_fork_diagnostic("Feature.m")
        result = self._run_checker()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("hard-coded English text assigned to 'error'", result.stderr)

    def test_shared_fork_diagnostic_rule_requires_non_ui_consumer(self):
        self._write_shared_fork_diagnostic(forward=False)
        result = self._run_checker()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("hard-coded English text assigned to 'error'", result.stderr)

    def test_shared_fork_diagnostic_rule_does_not_cover_other_ui_sinks(self):
        self._write_shared_fork_diagnostic(sink="heading")
        result = self._run_checker()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Objective-C UI sink 'heading'", result.stderr)

    def test_shared_fork_diagnostic_rule_does_not_cover_new_text(self):
        self._write_shared_fork_diagnostic(message="Please select a different profile.")
        result = self._run_checker()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("hard-coded English text assigned to 'error'", result.stderr)

    def test_hard_coded_english_objective_c_direct_notification_fails(self):
        (self.sources / "Feature.m").write_text(
            '[controller notify:@"Idle" withDescription:@"Session became idle."];\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:1: hard-coded English text in Objective-C UI sink 'notify'",
            result.stderr,
        )
        self.assertIn(
            "Feature.m:1: hard-coded English text in Objective-C UI sink "
            "'withDescription'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_custom_ui_factories_fail(self):
        (self.sources / "Feature.m").write_text(
            "- (void)buildUI {\n"
            "    id knob = [[iTermStatusBarComponentKnob alloc] "
            'initWithLabelText:@"Show Count" type:0 placeholder:nil '
            "defaultValue:nil key:key];\n"
            "    id item = [[iTermSearchableComboViewItem alloc] "
            'initWithLabel:@"Run Action" tag:1];\n'
            "    id combo = [[iTermSearchableComboView alloc] "
            "initWithGroups:groups "
            'defaultTitle:@"Select Action"];\n'
            "    id checkbox = [NSButton "
            'checkboxWithTitle:@"Enable Feature" target:nil action:nil];\n'
            "}\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        for sink in (
            "initWithLabelText",
            "initWithLabel",
            "defaultTitle",
            "checkboxWithTitle",
        ):
            self.assertIn(
                f"hard-coded English text in Objective-C UI sink '{sink}'",
                result.stderr,
            )

    def test_disclosable_view_prompt_and_formatted_message_require_localization(self):
        (self.sources / "Feature.m").write_text(
            "id view = [[iTermDisclosableView alloc] initWithFrame:NSZeroRect "
            'prompt:@"Why am I being prompted?" '
            'message:[NSString stringWithFormat:@"Reason:\\n\\n%@", reason]];\n'
            "id scrolling = [[iTermScrollingDisclosableView alloc] initWithFrame:NSZeroRect "
            'prompt:@"Show incompatible key bindings" message:output maximumHeight:150];\n',
            encoding="utf-8",
        )
        result = self._run_checker()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Objective-C UI sink 'disclosable prompt'", result.stderr)
        self.assertIn("Objective-C UI sink 'disclosable message'", result.stderr)

    def test_disclosable_view_preserves_dynamic_output_and_non_ui_prompts(self):
        (self.sources / "Feature.m").write_text(
            "id view = [[iTermDisclosableView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100) "
            'prompt:NSLocalizedString(@"fixture.greeting", nil) '
            'message:[output componentsJoinedByString:@"\\n"]];\n'
            'id request = [[LLMRequest alloc] initWithFrame:NSZeroRect '
            'prompt:@"Do not translate model protocol" message:@"Raw protocol output"];\n',
            encoding="utf-8",
        )
        result = self._run_checker()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_hard_coded_english_objective_c_delayed_ui_value_fails(self):
        (self.sources / "Feature.m").write_text(
            "- (void)resetLabel {\n"
            "    [label performSelector:@selector(setStringValue:) "
            'withObject:@"Click Here to Continue" afterDelay:1];\n'
            "}\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:2: hard-coded English text in Objective-C UI sink "
            "'performSelector:setStringValue:withObject'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_attributed_ui_string_fails(self):
        (self.sources / "Feature.m").write_text(
            "- (void)addNotice {\n"
            "    id notice = [[NSAttributedString alloc] "
            'initWithString:@"Press any key to continue." attributes:attrs];\n'
            "    [textView.textStorage appendAttributedString:notice];\n"
            "}\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:2: hard-coded English text in Objective-C UI sink "
            "'initWithString'",
            result.stderr,
        )

    def test_hard_coded_english_cursor_preset_name_fails(self):
        settings = self.sources / "Settings"
        (settings / "iTermCursorBlinkFadePreset.m").write_text(
            "+ (NSArray *)presets {\n"
            "    return @[ [[iTermCursorBlinkFadePreset alloc] "
            'initWithName:@"Breathing" fadeInDuration:1] ];\n'
            "}\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "iTermCursorBlinkFadePreset.m:2: hard-coded English text in "
            "Objective-C UI sink 'initWithName'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_trigger_provider_fails(self):
        triggers = self.sources / "Triggers"
        triggers.mkdir()
        (triggers / "FeatureTrigger.m").write_text(
            "+ (NSString *)title {\n"
            '    return @"Display Message";\n'
            "}\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "FeatureTrigger.m:2: hard-coded English text returned by "
            "Objective-C UI provider 'title'",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_status_bar_provider_fails(self):
        components = self.sources / "StatusBar" / "Components"
        components.mkdir(parents=True)
        (components / "FeatureComponent.m").write_text(
            "- (NSString *)statusBarComponentShortDescription {\n"
            '    return @"Activity Monitor";\n'
            "}\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "FeatureComponent.m:2: hard-coded English text returned by "
            "Objective-C UI provider 'statusBarComponentShortDescription'",
            result.stderr,
        )

    def test_hard_coded_english_key_binding_provider_fails(self):
        keyboard = self.sources / "Keyboard"
        keyboard.mkdir()
        (keyboard / "iTermKeyBindingAction.m").write_text(
            "- (NSString *)displayName {\n"
            '    return [NSString stringWithFormat:@"Run %@", parameter];\n'
            "}\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "iTermKeyBindingAction.m:2: hard-coded English text returned by "
            "Objective-C UI provider 'displayName'",
            result.stderr,
        )

    def test_hard_coded_english_open_quickly_provider_fails(self):
        open_quickly = self.sources / "OpenQuickly"
        open_quickly.mkdir()
        (open_quickly / "iTermOpenQuicklyCommands.m").write_text(
            "+ (NSString *)restrictionDescription {\n"
            '    return @"existing sessions";\n'
            "}\n"
            "+ (NSString *)command {\n"
            '    return @"f";\n'
            "}\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "iTermOpenQuicklyCommands.m:2: hard-coded English text returned by "
            "Objective-C UI provider 'restrictionDescription'",
            result.stderr,
        )
        self.assertNotIn("iTermOpenQuicklyCommands.m:5:", result.stderr)

    def test_objective_c_abstract_status_bar_provider_diagnostic_passes(self):
        components = self.sources / "StatusBar" / "Components"
        components.mkdir(parents=True)
        (components / "BaseComponent.m").write_text(
            "- (NSString *)statusBarComponentShortDescription {\n"
            "    [self doesNotRecognizeSelector:_cmd];\n"
            '    return @"Base class! This should not be called!";\n'
            "}\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_objective_c_dictionary_subscript_keys_are_not_ui_copy(self):
        (self.sources / "Feature.m").write_text(
            '- (void)notifyUser {\n'
            '    NSString *title = decoded[@"title"];\n'
            '    NSString *description = decoded[@"message"] ?: @"";\n'
            '    [controller notify:title withDescription:description];\n'
            '}\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_hard_coded_english_objective_c_indirect_action_fails(self):
        (self.sources / "Feature.m").write_text(
            '- (void)showWarning {\n'
            '    NSString *action = [NSString stringWithFormat:'
            '@"Remove from %@", name];\n'
            '    [iTermWarning showWarningWithTitle:title actions:@[ action ]];\n'
            '}\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:2: hard-coded English text assigned to 'action' for "
            "Objective-C action label",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_actions_variable_fails(self):
        (self.sources / "Feature.m").write_text(
            '- (void)showWarning {\n'
            '    NSArray *actions = @[ localizedAction ];\n'
            '    actions = [actions arrayByAddingObject:'
            '@"Reveal in Script Console"];\n'
            '    [iTermWarning showWarningWithTitle:title actions:actions];\n'
            '}\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:3: hard-coded English text assigned to 'actions' for "
            "Objective-C action label",
            result.stderr,
        )

    def test_objective_c_action_object_identifier_is_not_action_label(self):
        (self.sources / "Feature.m").write_text(
            '- (void)registerActionWithTitle:(NSString *)title {\n'
            '    UNNotificationAction *action = '
            '[UNNotificationAction actionWithIdentifier:@"action" '
            'title:title options:0];\n'
            '    NSArray *actions = @[ action ];\n'
            '}\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_objective_c_title_transformation_tokens_are_not_ui_copy(self):
        (self.sources / "Feature.m").write_text(
            'item.title = [item.title stringByReplacingOccurrencesOfString:@"Window" '
            'withString:@"Tab"];\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_objective_c_internal_title_variable_is_not_ui_copy(self):
        (self.sources / "Feature.m").write_text(
            'static NSString *const title = @"title";\n', encoding="utf-8"
        )

        result = self._run_checker()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_objective_c_format_only_ui_value_is_not_translatable_copy(self):
        (self.sources / "Feature.m").write_text(
            'field.stringValue = [NSString stringWithFormat:@"%lu", value];\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_hard_coded_english_objective_c_action_label_fails(self):
        (self.sources / "Feature.m").write_text(
            '[iTermWarning showWarningWithTitle:title '
            'actions:@[ @"Continue", @"Cancel" ]];\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:1: hard-coded English text in Objective-C action label",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_warning_action_label_fails(self):
        (self.sources / "Feature.m").write_text(
            '[iTermWarningAction warningActionWithLabel:@"Paste" block:nil];\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:1: hard-coded English text in Objective-C action label",
            result.stderr,
        )

    def test_hard_coded_english_objective_c_multiline_cancel_label_fails(self):
        (self.sources / "Feature.m").write_text(
            'warning.cancelLabel =\n    @"Cancel";\n', encoding="utf-8"
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.m:1: hard-coded English text in Objective-C action label",
            result.stderr,
        )

    def test_reference_to_missing_localization_key_fails(self):
        (self.sources / "Feature.swift").write_text(
            'let title = String(localized: "fixture.missing", '
            'defaultValue: "Missing")\n',
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.swift:1: localization key 'fixture.missing' was not found",
            result.stderr,
        )

    def test_tip_data_requires_catalog_entries(self):
        self._write_tip_data()

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "iTermTipData.m: tip '000' title is missing localization key "
            "'ui.tips.data.000.title'",
            result.stderr,
        )

    def test_tip_data_english_fallback_must_match_source(self):
        self._write_tip_data()
        self._write_tip_catalog(english_title="Different title")

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "ui.tips.data.000.title: English fallback differs from "
            "iTermTipData.m",
            result.stderr,
        )

    def test_tip_data_requires_runtime_localization_wiring(self):
        self._write_tip_data(omitted_runtime_marker="localizedStringForKey:key")
        self._write_tip_catalog()

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Tip of the Day localization runtime is missing "
            "'localizedStringForKey:key'",
            result.stderr,
        )

    def test_xib_catalog_with_root_xib_fails(self):
        feature_directory = self.sources / "Feature"
        feature_directory.mkdir(parents=True)
        (feature_directory / "Feature.xib").write_text(
            "<?xml version=\"1.0\"?><document/>", encoding="utf-8"
        )
        self._write_catalog(
            "Feature/Feature.xcstrings",
            {"fixture.title": {"en": "Title", "zh-Hans": "标题"}},
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.xib: localized XIB must be in Base.lproj",
            result.stderr,
        )

    def test_xib_catalog_without_target_membership_fails(self):
        feature_directory = self.sources / "Feature"
        (feature_directory / "Base.lproj").mkdir(parents=True)
        (feature_directory / "Base.lproj" / "Feature.xib").write_text(
            "<?xml version=\"1.0\"?><document/>", encoding="utf-8"
        )
        self._write_catalog(
            "Feature/Feature.xcstrings",
            {"fixture.title": {"en": "Title", "zh-Hans": "标题"}},
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.xcstrings: XIB catalog is not in the main iTerm2 target's Resources build phase",
            result.stderr,
        )

    def test_xib_catalog_in_nonresource_phase_fails(self):
        feature_directory = self.sources / "Feature"
        (feature_directory / "Base.lproj").mkdir(parents=True)
        (feature_directory / "Base.lproj" / "Feature.xib").write_text(
            "<?xml version=\"1.0\"?><document/>", encoding="utf-8"
        )
        self._write_catalog(
            "Feature/Feature.xcstrings",
            {"fixture.title": {"en": "Title", "zh-Hans": "标题"}},
        )
        (self.project_root / "iTerm2.xcodeproj" / "project.pbxproj").write_text(
            """/* Begin PBXBuildFile section */
BBBBBBBBBBBBBBBBBBBBBBBB /* Feature.xib in Sources */ = {isa = PBXBuildFile; fileRef = AAAAAAAAAAAAAAAAAAAAAAAA /* Feature.xib */; };
/* End PBXBuildFile section */
/* Begin PBXFileReference section */
AAAAAAAAAAAAAAAAAAAAAAAA /* Feature.xib */ = {isa = PBXFileReference; lastKnownFileType = text.json.xcstrings; path = Feature.xcstrings; sourceTree = \"<group>\"; };
/* End PBXFileReference section */
/* Begin PBXSourcesBuildPhase section */
CCCCCCCCCCCCCCCCCCCCCCCC /* Sources */ = {
    isa = PBXSourcesBuildPhase;
    files = (
        BBBBBBBBBBBBBBBBBBBBBBBB /* Feature.xib in Sources */,
    );
};
/* End PBXSourcesBuildPhase section */
/* Begin PBXNativeTarget section */
DDDDDDDDDDDDDDDDDDDDDDDD /* iTerm2 */ = {
    isa = PBXNativeTarget;
    buildPhases = (
        CCCCCCCCCCCCCCCCCCCCCCCC /* Sources */,
    );
    name = iTerm2;
};
/* End PBXNativeTarget section */
""",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.xcstrings: XIB catalog is not in the main iTerm2 target's Resources build phase",
            result.stderr,
        )

    def test_xib_catalog_in_resource_phase_passes(self):
        feature_directory = self.sources / "Feature"
        (feature_directory / "Base.lproj").mkdir(parents=True)
        (feature_directory / "Base.lproj" / "Feature.xib").write_text(
            "<?xml version=\"1.0\"?><document/>", encoding="utf-8"
        )
        self._write_catalog(
            "Feature/Feature.xcstrings",
            {"fixture.title": {"en": "Title", "zh-Hans": "标题"}},
        )
        (self.project_root / "iTerm2.xcodeproj" / "project.pbxproj").write_text(
            """/* Begin PBXBuildFile section */
BBBBBBBBBBBBBBBBBBBBBBBB /* Feature.xib in Resources */ = {isa = PBXBuildFile; fileRef = AAAAAAAAAAAAAAAAAAAAAAAA /* Feature.xib */; };
/* End PBXBuildFile section */
/* Begin PBXFileReference section */
AAAAAAAAAAAAAAAAAAAAAAAA /* Feature.xib */ = {isa = PBXFileReference; lastKnownFileType = text.json.xcstrings; path = Feature.xcstrings; sourceTree = \"<group>\"; };
/* End PBXFileReference section */
/* Begin PBXResourcesBuildPhase section */
CCCCCCCCCCCCCCCCCCCCCCCC /* Resources */ = {
    isa = PBXResourcesBuildPhase;
    files = (
        BBBBBBBBBBBBBBBBBBBBBBBB /* Feature.xib in Resources */,
    );
};
/* End PBXResourcesBuildPhase section */
/* Begin PBXNativeTarget section */
DDDDDDDDDDDDDDDDDDDDDDDD /* iTerm2 */ = {
    isa = PBXNativeTarget;
    buildPhases = (
        CCCCCCCCCCCCCCCCCCCCCCCC /* Resources */,
    );
    name = iTerm2;
};
/* End PBXNativeTarget section */
""",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_xib_catalog_in_different_target_resource_phase_fails(self):
        feature_directory = self.sources / "Feature"
        (feature_directory / "Base.lproj").mkdir(parents=True)
        (feature_directory / "Base.lproj" / "Feature.xib").write_text(
            "<?xml version=\"1.0\"?><document/>", encoding="utf-8"
        )
        self._write_catalog(
            "Feature/Feature.xcstrings",
            {"fixture.title": {"en": "Title", "zh-Hans": "标题"}},
        )
        (self.project_root / "iTerm2.xcodeproj" / "project.pbxproj").write_text(
            """/* Begin PBXBuildFile section */
BBBBBBBBBBBBBBBBBBBBBBBB /* Feature.xib in Resources */ = {isa = PBXBuildFile; fileRef = AAAAAAAAAAAAAAAAAAAAAAAA /* Feature.xib */; };
/* End PBXBuildFile section */
/* Begin PBXFileReference section */
AAAAAAAAAAAAAAAAAAAAAAAA /* Feature.xib */ = {isa = PBXFileReference; lastKnownFileType = text.json.xcstrings; path = Feature.xcstrings; sourceTree = "<group>"; };
/* End PBXFileReference section */
/* Begin PBXResourcesBuildPhase section */
CCCCCCCCCCCCCCCCCCCCCCCC /* Resources */ = {
    isa = PBXResourcesBuildPhase;
    files = (
        BBBBBBBBBBBBBBBBBBBBBBBB /* Feature.xib in Resources */,
    );
};
EEEEEEEEEEEEEEEEEEEEEEEE /* Resources */ = {
    isa = PBXResourcesBuildPhase;
    files = (
    );
};
/* End PBXResourcesBuildPhase section */
/* Begin PBXNativeTarget section */
DDDDDDDDDDDDDDDDDDDDDDDD /* iTerm2 */ = {
    isa = PBXNativeTarget;
    buildPhases = (
        EEEEEEEEEEEEEEEEEEEEEEEE /* Resources */,
    );
    name = iTerm2;
};
FFFFFFFFFFFFFFFFFFFFFFFF /* Helper */ = {
    isa = PBXNativeTarget;
    buildPhases = (
        CCCCCCCCCCCCCCCCCCCCCCCC /* Resources */,
    );
    name = Helper;
};
/* End PBXNativeTarget section */
""",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "Feature.xcstrings: XIB catalog is not in the main iTerm2 target's Resources build phase",
            result.stderr,
        )

    def test_uk_crash_reporter_catalog_with_root_xib_fails(self):
        crash_reporter_directory = (
            self.project_root / "ThirdParty" / "UKCrashReporter"
        )
        crash_reporter_directory.mkdir(parents=True)
        (crash_reporter_directory / "UKCrashReporter.xib").write_text(
            "<?xml version=\"1.0\"?><document/>", encoding="utf-8"
        )
        (crash_reporter_directory / "UKCrashReporter.xcstrings").write_text(
            json.dumps(
                {
                    "sourceLanguage": "en",
                    "strings": {
                        "5.title": {
                            "localizations": {
                                "en": {
                                    "stringUnit": {
                                        "state": "translated",
                                        "value": "Crash Reporter",
                                    }
                                },
                                "zh-Hans": {
                                    "stringUnit": {
                                        "state": "translated",
                                        "value": "崩溃报告",
                                    }
                                },
                            }
                        }
                    },
                    "version": "1.0",
                },
                ensure_ascii=False,
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

        result = self._run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "UKCrashReporter.xib: localized XIB must be in Base.lproj",
            result.stderr,
        )


if __name__ == "__main__":
    unittest.main()
