"""Keep visible titles, placeholders and help represented in their XIB catalogs."""

import json
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]


class XibVisibleLocalizationTests(unittest.TestCase):
    def assert_catalog_field(self, catalog, key, english):
        self.assertTrue(key in catalog, f"Missing XIB localization: {key}")
        translations = catalog[key]["localizations"]
        self.assertEqual(translations["en"]["stringUnit"]["value"], english)
        self.assertTrue(translations["zh-Hans"]["stringUnit"]["value"].strip())

    def test_status_bar_advanced_help_has_catalog_entries(self):
        directory = ROOT / "sources/StatusBar/Setup"
        name = "iTermStatusBarSetupViewController"
        catalog = json.loads((directory / f"{name}.xcstrings").read_text())["strings"]
        xib = ET.parse(directory / f"Base.lproj/{name}.xib")
        tooltips = [item for item in xib.iter() if item.get("toolTip")]
        self.assertEqual(len(tooltips), 3)
        for item in tooltips:
            key = item.attrib["id"] + ".ibShadowedToolTip"
            with self.subTest(key=key):
                self.assert_catalog_field(catalog, key, item.attrib["toolTip"])
                self.assertNotEqual(
                    catalog[key]["localizations"]["zh-Hans"]["stringUnit"]["value"],
                    item.attrib["toolTip"],
                )

    def test_main_menu_item_titles_have_catalog_entries(self):
        directory = ROOT / "sources/MainMenu"
        catalog = json.loads((directory / "MainMenu.xcstrings").read_text())["strings"]
        xib = ET.parse(directory / "Base.lproj/MainMenu.xib")
        for item in xib.iter("menuItem"):
            if not item.get("title") or item.get("isSeparatorItem") == "YES":
                continue
            with self.subTest(item=item.get("id")):
                self.assert_catalog_field(catalog, item.attrib["id"] + ".title",
                                          item.attrib["title"])

    def test_password_manager_placeholders_and_help_have_catalog_entries(self):
        directory = ROOT / "sources/PasswordManager"
        catalog = json.loads((directory / "iTermPasswordManager.xcstrings").read_text())["strings"]
        xib = ET.parse(directory / "Base.lproj/iTermPasswordManager.xib")
        for item in xib.iter():
            # These are the keys emitted by ibtool --export-strings-file for
            # AppKit cell placeholders and a view's shadowed tooltip property.
            for attribute, suffix in (("placeholderString", ".placeholderString"),
                                      ("toolTip", ".ibShadowedToolTip")):
                if not item.get(attribute):
                    continue
                with self.subTest(item=item.get("id"), field=attribute):
                    self.assert_catalog_field(catalog, item.attrib["id"] + suffix,
                                              item.attrib[attribute])

    def test_password_manager_button_titles_match_base_xib(self):
        directory = ROOT / "sources/PasswordManager"
        catalog = json.loads((directory / "iTermPasswordManager.xcstrings").read_text())["strings"]
        xib = ET.parse(directory / "Base.lproj/iTermPasswordManager.xib")
        for item in xib.iter("buttonCell"):
            if not item.get("title"):
                continue
            with self.subTest(item=item.get("id")):
                self.assert_catalog_field(catalog, item.attrib["id"] + ".title",
                                          item.attrib["title"])


if __name__ == "__main__":
    unittest.main()
