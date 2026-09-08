"""Native menus/bindings with actual Toolbelt method excerpts.

User defaults, registered tool classes and window consumers are synthetic.
The real menu builders, toggle action/configuration, notification menu lookup,
wrapper name binding and deferred display update execute. No real tools open.
"""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest

from tools.tests.test_close_job_list_localization import method


ROOT = Path(__file__).resolve().parents[2]
TRANSLATIONS = {
    "Actions": "操作", "Captured Output": "捕获输出", "Command History": "命令历史",
    "Recent Directories": "最近目录", "Jobs": "作业", "Notes": "笔记",
    "Paste History": "粘贴历史", "Profiles": "配置文件", "Snippets": "代码片段",
    "Named Marks": "命名标记", "Session Status": "会话状态", "Codecierge": "Codecierge",
    "User 工具 %@": "User 工具 %@",
}


class ToolbeltDisplayLocalizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="iterm2-toolbelt-display-")
        cls.addClassCleanup(temporary.cleanup)
        cls.directory = Path(temporary.name)
        toolbelt = (ROOT / "sources/Toolbelt/iTermToolbeltView.m").read_text()
        wrapper = (ROOT / "sources/Toolbelt/iTermToolWrapper.m").read_text()
        delegate = (ROOT / "sources/AppKit/iTermApplicationDelegate.m").read_text()
        constants = re.findall(r'^NSString \*const (k\w+ToolName) = @"[^"\n]+";', toolbelt, re.M)
        if len(constants) != 12:
            raise AssertionError("Expected twelve actual built-in names")
        declarations = re.findall(r'^NSString \*const k\w+ToolName = @"[^"\n]+";', toolbelt, re.M)
        display_signature = "+ (NSString *)displayNameForToolName:"
        display = method(toolbelt, display_signature) if display_signature in toolbelt else ""
        notification = method(delegate, "- (void)toolDidToggle:")
        notification = notification[notification.index("    NSMenuItem *menuItem ="):]
        init_start = wrapper.index("        _title = [[NSTextField alloc]")
        init_end = wrapper.index("        NSImage *closeImage", init_start)
        update = method(wrapper, "- (void)setTitleEditable")
        # Completion signal only; leave the actual display statements unchanged.
        update = update[:-1] + "    _updated = YES;\n}"
        includes = {
            "toolbelt-constants.inc": "\n".join(declarations),
            "toolbelt-names.inc": "return @[" + ",".join(constants) + "];",
            "toolbelt-display-declaration.inc": display.split("{", 1)[0] + ";" if display else "",
            "toolbelt-methods.inc": "\n".join([display, *(method(toolbelt, signature) for signature in (
                "+ (NSArray<NSString *> *)allTools", "+ (NSArray *)configuredTools",
                "+ (void)populateMenu:", "+ (void)addToolsToMenu:",
                "+ (void)toggleShouldShowTool:", "+ (NSArray *)defaultTools"))]),
            "toolbelt-action.inc": method(delegate, "- (IBAction)toggleToolbeltTool:"),
            "toolbelt-notification.inc": notification[:-1],
            "toolbelt-wrapper-init.inc": wrapper[init_start:init_end],
            "toolbelt-wrapper-methods.inc": method(wrapper, "- (void)setName:") + "\n" + update,
        }
        for name, contents in includes.items():
            (cls.directory / name).write_text(contents)
        cls.probe = cls.directory / "toolbelt-probe"
        compiled = subprocess.run(
            ["xcrun", "clang", "-fobjc-arc", "-Wall", "-Werror", "-framework", "AppKit",
             "-I", str(cls.directory), str(ROOT / "tests/toolbelt_display_localization_probe.m"),
             "-o", str(cls.probe)], capture_output=True, text=True, timeout=60)
        if compiled.returncode:
            raise AssertionError(compiled.stdout + compiled.stderr)
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        for language in ("en", "zh-Hans"):
            resources = cls.directory / f"{language}.lproj"
            resources.mkdir()
            values = {key: entry["localizations"][language]["stringUnit"]["value"]
                      for key, entry in catalog.items() if key.startswith("ui.toolbelt.")}
            (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))

    def check_language(self, language):
        result = subprocess.run([str(self.probe), str(self.directory / f"{language}.lproj")],
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual([row["raw"] for row in data["rows"]], sorted(TRANSLATIONS))
        for row in data["rows"]:
            raw = row["raw"]
            expected = raw if language == "en" else TRANSLATIONS[raw]
            with self.subTest(language=language, tool=raw):
                self.assertEqual(row["identifier"], "Toolbelt." + raw)
                self.assertEqual(row["tag"], 1 if raw == "User 工具 %@" else 3)
                self.assertEqual(row["action"], "toggleToolbeltTool:")
                self.assertEqual(row["keyEquivalent"], "")
                self.assertEqual(row["notification"], raw)
                self.assertTrue(row["configuredAfter"])
                self.assertTrue(row["stateAfter"])
                self.assertTrue(row["restored"])
                self.assertEqual(row["displayed"], expected)
                self.assertEqual(row["axTitle"], expected)
        self.assertEqual(data["menuCount"], len(TRANSLATIONS) + 1)
        self.assertEqual(data["header"], "Synthetic header")
        self.assertEqual(data["registryNames"], sorted(TRANSLATIONS))
        for row in data["wrappers"]:
            expected = row["raw"] if language == "en" else TRANSLATIONS.get(row["raw"], row["raw"])
            with self.subTest(language=language, wrapper=row["raw"]):
                self.assertTrue(row["updated"])
                self.assertEqual(row["stored"], row["raw"])
                self.assertEqual(row["displayed"], expected)
                self.assertFalse(row["editable"])
        with self.subTest(language=language, dynamic_name_collision=True):
            self.assertEqual(data["dynamicNotes"], "Notes")
            self.assertEqual(data["dynamicWrapper"], "Notes")

    def test_english_display_and_raw_contracts(self):
        self.check_language("en")

    def test_chinese_display_and_raw_contracts(self):
        self.check_language("zh-Hans")


if __name__ == "__main__":
    unittest.main()
