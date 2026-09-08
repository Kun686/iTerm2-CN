#!/usr/bin/env python3
"""Keep the nonlocalized legacy-title table synchronized with the Base main menu."""
import argparse
import json
from pathlib import Path
import re
import sys
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[1]
START = "    // BEGIN GENERATED MENU TITLES\n"
END = "    // END GENERATED MENU TITLES"


def swift_string(value):
    quoted = json.dumps(value, ensure_ascii=False)
    return re.sub(r"\\u([0-9a-fA-F]{4})", lambda match: "\\u{" + match[1] + "}", quoted)


def menu_item_identifier(item):
    if item.get("identifier") is not None:
        return item.get("identifier")
    # NSMenuItem.identifier defaults to its action selector when no explicit
    # identifier was set. Read only this item's connection, never its submenu.
    action = item.find("connections/action")
    return action.get("selector") if action is not None else None


def generated_block(root):
    menu = ElementTree.parse(root / "sources/MainMenu/Base.lproj/MainMenu.xib")
    rows = []
    keys = set()
    for item in menu.iter("menuItem"):
        if item.get("isSeparatorItem") == "YES" or not item.get("title"):
            continue
        key = item.attrib["id"] + ".title"
        if key in keys:
            raise ValueError("Duplicate menu object ID: " + key)
        keys.add(key)
        value = menu_item_identifier(item)
        identifier = swift_string(value) if value is not None else "nil"
        rows.append(f"        ({swift_string(key)}, {identifier}, {swift_string(item.attrib['title'])}),")
    if not rows:
        raise ValueError("Base main menu has no titled items")
    return ('    private static let entries: [(key: String, identifier: String?, title: String)] = [\n'
            + "\n".join(rows) + "\n    ]\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="Regenerate only the marked table")
    args = parser.parse_args()
    path = ROOT / "sources/MainMenu/MenuItemLegacyTitles.swift"
    source = path.read_text(encoding="utf-8")
    if source.count(START) != 1 or source.count(END) != 1:
        raise ValueError("Expected one generated table region")
    prefix, remaining = source.split(START)
    _, suffix = remaining.split(END)
    expected = prefix + START + generated_block(ROOT) + END + suffix
    if source == expected:
        print("Legacy menu title table matches the Base XIB")
        return 0
    if not args.write:
        print("Legacy menu title table is stale; run tools/generate_menu_legacy_titles.py --write", file=sys.stderr)
        return 1
    path.write_text(expected, encoding="utf-8")
    print("Regenerated the legacy menu title table")
    return 0


if __name__ == "__main__":
    sys.exit(main())
