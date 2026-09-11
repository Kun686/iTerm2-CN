"""Native shared provider diagnostics and the attachment-alert name consumer."""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest

from tools.tests.test_uv_shared_error_localization import member


ROOT = Path(__file__).resolve().parents[2]
UNKNOWN_KEY = "ui.swift.aiterm.llmprovider.unknown_platform.9c60e933"
MISSING_KEY = "ui.swift.aiterm.chatinputview.the_current_ai_provider.937d613c"
NAMES = ("OpenAI", "Google", "Azure", "Deep Seek", "Anthropic", "Llama", "Unknown Platform", "server")


class AIProviderNameLocalizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="iterm2-ai-provider-name-")
        cls.addClassCleanup(temporary.cleanup)
        cls.directory = Path(temporary.name)
        provider = (ROOT / "sources/AITerm/LLMProvider.swift").read_text()
        names = [member(provider, "var displayName: String")]
        if "var localizedDisplayName: String" in provider:
            names.append(member(provider, "var localizedDisplayName: String"))
        metadata = (ROOT / "sources/AITerm/LLMMetadata.swift").read_text()
        hosts = [member(metadata, f"static func hostIs{vendor}API(")
                 for vendor in ("OpenAI", "GoogleAI", "AzureAI", "DeepSeekAI", "AnthropicAI")]
        input_view = (ROOT / "sources/AITerm/ChatInputView.swift").read_text()
        alert = re.findall(r"^\s*let providerName = .+$", input_view, re.M)
        controller = (ROOT / "sources/AITerm/AITerm.swift").read_text()
        error_name = re.findall(r'^\s*let provider = llmProvider\?\.displayName \?\? "server"$',
                                controller, re.M)
        error_texts = re.findall(r'^\s*var message = ("Error from .+")$', controller, re.M)
        events = re.findall(r'^\s*case \.error\(reason: let reason\): return (.+)$', controller, re.M)
        if len(alert) != 1 or len(error_name) != 1 or len(set(error_texts)) != 1 or len(events) != 1:
            raise AssertionError("Expected the actual alert/error construction consumers")
        template = (ROOT / "tests/ai_provider_name_probe.swift").read_text()
        for marker, content in {
            "// PROVIDER-HOST-CHECKS": "\n".join(hosts),
            "// PROVIDER-NAME-MEMBERS": "\n".join(names),
            "// PROVIDER-ALERT-NAME": alert[0],
            "// PROVIDER-ERROR-NAME": error_name[0],
            "/* PROVIDER-ERROR-TEXT */": error_texts[0],
            "/* PROVIDER-ERROR-EVENT */": events[0],
        }.items():
            if template.count(marker) != 1:
                raise AssertionError("Expected one template marker: " + marker)
            template = template.replace(marker, content)
        swift_path = cls.directory / "main.swift"
        swift_path.write_text(template.replace("bundle: .main", "bundle: probeBundle"))
        cls.probe = cls.directory / "provider-name-probe"
        result = subprocess.run(
            ["xcrun", "swiftc", "-warnings-as-errors", str(swift_path),
             str(ROOT / "sources/AITerm/iTermAIError.swift"), "-o", str(cls.probe)],
            capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        cls.display_names = {}
        for language in ("en", "zh-Hans"):
            resources = cls.directory / f"{language}.lproj"
            resources.mkdir()
            values = {key: catalog[key]["localizations"][language]["stringUnit"]["value"]
                      for key in (UNKNOWN_KEY, MISSING_KEY)}
            cls.display_names[language] = values
            (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))

    def check_language(self, language):
        result = subprocess.run([str(self.probe), str(self.directory / f"{language}.lproj")],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        snapshots = json.loads(result.stdout)
        self.assertEqual(len(snapshots), len(NAMES))
        for name, row in zip(NAMES, snapshots):
            display = (self.display_names[language][UNKNOWN_KEY] if name == "Unknown Platform" else
                       self.display_names[language][MISSING_KEY] if name == "server" else name)
            error = f"Error from {name}: Synthetic vendor 原文"
            with self.subTest(language=language, name=name):
                self.assertEqual(row, {"name": name, "alertName": display, "error": error,
                                       "event": f"error({error})", "nsError": error})

    def test_english_provider_names_and_errors(self):
        self.check_language("en")

    def test_chinese_provider_names_and_errors(self):
        self.check_language("zh-Hans")


if __name__ == "__main__":
    unittest.main()
