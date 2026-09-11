"""Check real password-trigger popup ordering with synthetic account names.

Only menu/index methods are compiled; initialization, account loading, and
execution are excluded. No password-manager window or Keychain is accessed.
"""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class PasswordTriggerPopupLocalizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="iterm2-password-popup-")
        cls.addClassCleanup(temporary.cleanup)
        cls.directory = Path(temporary.name)
        source = (ROOT / "sources/Triggers/PasswordTrigger.m").read_text()
        base = (ROOT / "sources/Triggers/Trigger.m").read_text()

        def method(text, signature):
            if text.count(signature) != 1:
                raise AssertionError(f"Expected one method: {signature}")
            return signature + text.split(signature, 1)[1].split("\n}", 1)[0] + "\n}\n"

        sorter = "- (NSArray *)objectsSortedByValueInDict:(NSDictionary *)dict"
        (cls.directory / "base-sort.inc").write_text(method(base, sorter))
        methods = [method(source, signature) for signature in (
            "- (NSArray *)sortedAccountNames",
            "- (NSInteger)indexForObject:(id)object",
            "- (id)objectAtIndex:(NSInteger)index",
            "- (NSDictionary *)menuItemsForPoupupButton",
            "- (int)defaultIndex")]
        if sorter in source:
            methods.append(method(source, sorter))
        (cls.directory / "password-popup.inc").write_text("\n".join(methods))
        sentinel = re.search(r'^static NSString \*PasswordTriggerPlaceholderString = .*;$', source, re.M)
        if sentinel is None:
            raise AssertionError("Missing the original password-trigger sentinel")
        (cls.directory / "password-sentinel.inc").write_text(sentinel[0])
        controller = (ROOT / "sources/Settings/TriggerController.m").read_text()
        expression = "[trigger objectsSortedByValueInDict:items]"
        if controller.count("for (id key in " + expression + ")") != 1:
            raise AssertionError("Review the actual popup construction order")
        (cls.directory / "popup-order.inc").write_text("return " + expression + ";")
        cls.probe = cls.directory / "password-popup-probe"
        compiled = subprocess.run(
            ["xcrun", "clang", "-fobjc-arc", "-Wall", "-Wextra", "-Werror",
             "-framework", "Foundation", "-I", str(cls.directory),
             str(ROOT / "tests/password_trigger_popup_probe.m"), "-o", str(cls.probe)],
            capture_output=True, text=True, timeout=60)
        if compiled.returncode:
            raise AssertionError(compiled.stdout + compiled.stderr)
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        key = "ui.triggers.passwordtrigger.open_password_manager_to_unlock.d7486d12"
        for language in ("en", "zh-Hans"):
            resources = cls.directory / f"{language}.lproj"
            resources.mkdir()
            value = catalog[key]["localizations"][language]["stringUnit"]["value"]
            (resources / "Localizable.strings").write_bytes(plistlib.dumps({key: value}))

    def check_language(self, language):
        result = subprocess.run([str(self.probe), str(self.directory / f"{language}.lproj")],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        snapshots = json.loads(result.stdout)
        self.assertEqual(len(snapshots), 9)
        sentinel = "Open Password Manager to Unlock"
        for snapshot in snapshots:
            with self.subTest(names=snapshot["names"], field="order"):
                self.assertEqual(snapshot["displayOrder"], snapshot["baselineOrder"])
            self.assertTrue(snapshot["namesUnchanged"])
            self.assertTrue(snapshot["boundsChecked"])
            self.assertEqual(snapshot["defaultIndex"], 0)
            for row in snapshot["rows"]:
                with self.subTest(names=snapshot["names"], key=row["key"]):
                    self.assertEqual(row["savedKey"], row["key"])
                    self.assertEqual(row["restoredIndex"], row["index"])
                    expected = ("打开密码管理器以解锁" if language == "zh-Hans" else sentinel)
                    self.assertEqual(row["label"], expected if row["key"] == sentinel else row["key"])

    def test_english_display_order_matches_parameter_mapping(self):
        self.check_language("en")

    def test_chinese_display_order_matches_parameter_mapping(self):
        self.check_language("zh-Hans")


if __name__ == "__main__":
    unittest.main()
