"""Run the real fallback and filename expressions, without opening a save panel."""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
MENU_KEY = "ui.swift.sharing.commandsharemenuprovider.save_command_output.50dceb6f"


class CommandExportFilenameTests(unittest.TestCase):
    def test_fallback_filename_is_independent_of_ui_language(self):
        source = (ROOT / "sources/Sharing/CommandShareMenuProvider.swift").read_text()
        saver = (ROOT / "sources/AttributedStrings/AttributedStringSaver.swift").read_text()
        fallback = re.findall(
            r'private static func defaultCommand\(_ maybeCommand: String\?\) -> String \{\n'
            r'\s+let fallback = ([^\n]+)', source)
        filename = re.findall(r'^\s+savePanel.nameFieldStringValue = ([^\n]+)$', saver, re.M)
        self.assertEqual(len(fallback), 1)
        self.assertEqual(len(filename), 1)
        self.assertIn('saver.save(defaultName: defaultCommand(mark.fullCommand), window: window)', source)
        # Only the bundle is injected. The initializer and filename expression
        # are compiled from production, not reimplemented by the test.
        expression = fallback[0].replace('bundle: .main', 'bundle: resources')
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        with tempfile.TemporaryDirectory(prefix="iterm2-command-filename-") as directory:
            root = Path(directory)
            probe_source = root / "main.swift"
            probe_source.write_text(
                'import Foundation\n'
                'guard let resources = Bundle(path: CommandLine.arguments[1]) else { exit(2) }\n'
                f'let fallback = {expression}\n'
                'let defaultName = fallback\n'
                f'let filename = {filename[0]}\n'
                f'let menu = resources.localizedString(forKey: "{MENU_KEY}", value: nil, table: nil)\n'
                'let data = try JSONSerialization.data(withJSONObject: ["filename": filename, "menu": menu])\n'
                'FileHandle.standardOutput.write(data)\n')
            probe = root / "probe"
            compiled = subprocess.run(
                ["xcrun", "swiftc", "-warnings-as-errors", "-module-cache-path", str(root / "cache"),
                 str(probe_source), "-o", str(probe)],
                capture_output=True, text=True, timeout=45)
            self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
            for language in ("en", "zh-Hans"):
                resources = root / f"{language}.lproj"
                resources.mkdir()
                values = {key: entry["localizations"][language]["stringUnit"]["value"]
                          for key, entry in catalog.items()
                          if key.startswith("ui.swift.sharing.commandsharemenuprovider.")}
                (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))
                result = subprocess.run([str(probe), str(resources)],
                                        capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stderr)
                row = json.loads(result.stdout)
                with self.subTest(language=language):
                    # This control proves the actual language catalog is loaded.
                    self.assertEqual(row["menu"], values[MENU_KEY])
                    self.assertEqual(row["filename"], "iTerm2 Command.rtf")


if __name__ == "__main__":
    unittest.main()
