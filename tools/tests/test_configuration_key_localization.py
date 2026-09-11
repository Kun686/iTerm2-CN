"""Keep configuration keys verbatim when UI help names them for the user."""
import json
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]


class ConfigurationKeyLocalizationTests(unittest.TestCase):
    def test_hotkey_migration_warning_names_the_actual_parent_key(self):
        header = (ROOT / "sources/Settings/Profiles/ITAddressBookMgr.h").read_text()
        declaration = re.search(
            r'^#define KEY_DYNAMIC_PROFILE_PARENT_NAME\s+@"([^"]+)"$',
            header, re.MULTILINE)
        self.assertIsNotNone(declaration)
        configuration_key = declaration.group(1)
        resource_key = (
            "ui.hotkey.itermhotkeymigrationhelper."
            "you_have_dynamic_profiles_whose_dynamic_profile_parent_name_is_set_to_yo.bb8eb57d")
        source = (ROOT / "sources/Hotkey/iTermHotKeyMigrationHelper.m").read_text()
        self.assertIn(f'NSLocalizedStringWithDefaultValue(@"{resource_key}"', source)
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())
        translations = catalog["strings"][resource_key]["localizations"]
        for language in ("en", "zh-Hans"):
            with self.subTest(language=language):
                self.assertIn(f"“{configuration_key}”", translations[language]["stringUnit"]["value"])


if __name__ == "__main__":
    unittest.main()
