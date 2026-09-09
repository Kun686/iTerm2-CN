"""Run the production fork-title block without accessing chats or vendor APIs."""
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
KEY = "ui.swift.aiterm.chatwindowcontroller.forked_at.079deb8e"
MARKER = "(Forked at "
TITLES = ("Original", "Original (Forked at old)", "中文 %@ 标题",
          "中文 (Forked at old)", "", "(Forked at old)",
          "User (分支创建于 old)", "User (Forked at first) (Forked at second)")


class ChatForkTitleLocalizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="iterm2-chat-fork-title-")
        cls.addClassCleanup(temporary.cleanup)
        cls.directory = Path(temporary.name)
        source = (ROOT / "sources/AITerm/ChatWindowController.swift").read_text()
        start = "            var title = originalTitle\n"
        end = "            let chatID = try client.create(chatWithTitle: title,"
        if source.count(start) != 1 or source.count(end) != 1:
            raise AssertionError("Expected the unique production fork-title block")
        block = start + source.split(start, 1)[1].split(end, 1)[0]
        template = (ROOT / "tests/chat_fork_title_probe.swift").read_text()
        marker = "// FORK-TITLE-PRODUCTION"
        if template.count(marker) != 1:
            raise AssertionError("Expected one probe insertion marker")
        probe_source = template.replace(marker, block).replace("bundle: .main", "bundle: probeBundle")
        swift_path = cls.directory / "main.swift"
        swift_path.write_text(probe_source)
        cls.probe = cls.directory / "fork-title-probe"
        result = subprocess.run(
            ["xcrun", "swiftc", "-warnings-as-errors", str(swift_path), "-o", str(cls.probe)],
            capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        entry = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"][KEY]
        for language in ("en", "zh-Hans"):
            resources = cls.directory / f"{language}.lproj"
            resources.mkdir()
            value = entry["localizations"][language]["stringUnit"]["value"]
            (resources / "Localizable.strings").write_bytes(plistlib.dumps({KEY: value}))

    def titles(self, language, originals, time):
        result = subprocess.run(
            [str(self.probe), str(self.directory / f"{language}.lproj"), time, *originals],
            capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def check_language(self, language):
        actual = self.titles(language, TITLES, "new-time")
        self.assertEqual(len(actual), len(TITLES))
        for original, title in zip(TITLES, actual):
            # Preserve the upstream first-marker replacement rule, including
            # arbitrary user text and pre-existing malformed/multiple suffixes.
            prefix = original.split(MARKER, 1)[0] if MARKER in original else original + " "
            with self.subTest(language=language, original=original):
                self.assertEqual(title, prefix + MARKER + "new-time)")

    def test_english_matches_original_title_rules(self):
        self.check_language("en")

    def test_chinese_matches_original_title_rules(self):
        self.check_language("zh-Hans")

    def test_repeated_forks_across_language_changes(self):
        for languages in (("en", "zh-Hans", "en"), ("zh-Hans", "en", "zh-Hans")):
            title = "Existing (Forked at old)"
            for index, language in enumerate(languages):
                title = self.titles(language, [title], str(index))[0]
                with self.subTest(languages=languages, index=index):
                    self.assertEqual(title, f"Existing (Forked at {index})")


if __name__ == "__main__":
    unittest.main()
