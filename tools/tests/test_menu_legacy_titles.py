from pathlib import Path
import subprocess
import sys
import unittest
from xml.etree import ElementTree

from tools.generate_menu_legacy_titles import menu_item_identifier


class MenuLegacyTitleTableTests(unittest.TestCase):
    def test_identifier_follows_appkit_explicit_then_action_fallback(self):
        item = ElementTree.fromstring('<menuItem><connections><action selector="restoreArchive:"/></connections></menuItem>')
        self.assertEqual(menu_item_identifier(item), "restoreArchive:")
        item.set("identifier", "stable.explicit")
        self.assertEqual(menu_item_identifier(item), "stable.explicit")
        item.set("identifier", "")
        self.assertEqual(menu_item_identifier(item), "")

    def test_submenu_does_not_inherit_a_descendants_action(self):
        item = ElementTree.fromstring('<menuItem><menu><items><menuItem><connections><action selector="child:"/></connections></menuItem></items></menu></menuItem>')
        self.assertIsNone(menu_item_identifier(item))

    def test_table_matches_current_base_menu(self):
        root = Path(__file__).resolve().parents[2]
        result = subprocess.run([sys.executable, str(root / "tools/generate_menu_legacy_titles.py")],
                                capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
