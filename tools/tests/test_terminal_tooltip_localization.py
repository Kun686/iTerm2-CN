"""Native production excerpts keep diagnostic tooltips raw and UI localized.

The NSViewToolTipOwner method and constructor tooltip expressions come from the
real source. Only bundle lookup and the DLog destination are substituted. This
does not exercise rendering, mouse events or the real logging backend.
"""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
PREFIX = "ui.swift.terminalview.terminalbutton."


class TerminalTooltipLocalizationTests(unittest.TestCase):
    sites = (
        ("TerminalRevealChannelButton", None, "Reveal embedded command"),
        ("TerminalFoldBlockButton", True, "Unfold block"),
        ("TerminalFoldBlockButton", False, "Fold block"),
        ("TerminalCopyCommandButton", None, "Copy command to clipboard"),
        ("TerminalBookmarkButton", None, "Toggle named mark"),
        ("TerminalShareButton", None, "Share command…"),
        ("TerminalCommandInfoButton", None, "Open Command Info…"),
        ("TerminalFoldButton", None, "Fold command"),
        ("TerminalUnfoldButton", None, "Unfold command"),
        ("TerminalSettingsButton", None, "Command Settings…"),
    )
    passthrough = ("", "User-defined tooltip 用户数据", "Unrecognized future tooltip")

    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="iterm2-tooltip-localization-")
        cls.addClassCleanup(temporary.cleanup)
        cls.directory = Path(temporary.name)
        source = (ROOT / "sources/TerminalView/TerminalButton.swift").read_text()
        signature = "extension TerminalButton: NSViewToolTipOwner {"
        owner = signature + source.split(signature, 1)[1].split("\n}", 1)[0] + "\n}"
        rows = []
        for name, folded, _ in cls.sites:
            constructor = source.split(f"class {name}:", 1)[1].split("\n    required init?", 1)[0]
            matches = re.findall(r"tooltip: (.+)\)\s*$", constructor, re.M)
            if len(matches) != 1:
                raise AssertionError(f"Expected one actual constructor tooltip in {name}")
            parameters = "" if folded is None else "(currentlyFolded: Bool) in "
            argument = "" if folded is None else str(folded).lower()
            rows.append("({ " + parameters + "return snapshot(" + matches[0] + ") })(" + argument + ")")
        rows.extend("snapshot(" + json.dumps(value, ensure_ascii=False) + ")" for value in cls.passthrough)
        template = (ROOT / "tests/terminal_button_tooltip_probe.swift").read_text()
        lookup_path = ROOT / "sources/TerminalView/TerminalButtonTooltip.swift"
        lookup = lookup_path.read_text() if lookup_path.exists() else ""
        probe_source = template.replace("// TOOLTIP-OWNER-METHOD", owner).replace(
            "// TOOLTIP-DISPLAY-LOOKUP", lookup).replace(
                "// TOOLTIP-CALL-SITES", "return [\n" + ",\n".join(rows) + "\n]")
        probe_source = probe_source.replace("bundle: .main", "bundle: probeBundle")
        swift_path = cls.directory / "main.swift"
        swift_path.write_text(probe_source)
        cls.probe = cls.directory / "tooltip-probe"
        compiled = subprocess.run(
            ["xcrun", "swiftc", "-warnings-as-errors", str(swift_path), "-o", str(cls.probe)],
            capture_output=True, text=True, timeout=60,
        )
        if compiled.returncode:
            raise AssertionError(compiled.stdout + compiled.stderr)
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        cls.translations = {}
        for language in ("en", "zh-Hans"):
            resources = cls.directory / f"{language}.lproj"
            resources.mkdir()
            values = {key: entry["localizations"][language]["stringUnit"]["value"]
                      for key, entry in catalog.items() if key.startswith(PREFIX)}
            (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))
            cls.translations[language] = {
                entry["localizations"]["en"]["stringUnit"]["value"]: values[key]
                for key, entry in catalog.items() if key in values
            }

    def check_language(self, language):
        result = subprocess.run(
            [str(self.probe), str(self.directory / f"{language}.lproj")],
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        actual = json.loads(result.stdout)
        self.assertEqual(len(actual), len(self.sites) + len(self.passthrough))
        for row, (_, _, original) in zip(actual, self.sites):
            with self.subTest(language=language, tooltip=original):
                self.assertEqual(row["displayed"], self.translations[language][original])
                self.assertEqual(row["stored"], original)
                self.assertEqual(row["log"], f"Returning {original} for SyntheticTerminalButton")
        for row, original in zip(actual[len(self.sites):], self.passthrough):
            with self.subTest(passthrough=original):
                self.assertEqual(row["stored"], original)
                self.assertEqual(row["displayed"], original)
                self.assertEqual(row["log"], f"Returning {original} for SyntheticTerminalButton")

    def test_english_tooltip_boundary(self):
        self.check_language("en")

    def test_chinese_tooltip_boundary(self):
        self.check_language("zh-Hans")


if __name__ == "__main__":
    unittest.main()
