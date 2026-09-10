"""Run the real settings callback; only controls, logging and scheduling are sinks.

No AI client, vendor request, plugin installation, defaults or Keychain access.
This does not substitute for the live AI harness or full-app UI acceptance.
"""
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
PREFIX = "ui.settings.generalpreferencesviewcontroller."


class AIPluginStatusLocalizationTests(unittest.TestCase):
    def test_settings_display_preserves_diagnostics_and_control_state(self):
        source = (ROOT / "sources/Settings/GeneralPreferencesViewController.m").read_text()
        start = source.index("- (void)setPluginProblem:")
        end = source.index("\n- (NSArray<NSNumber *> *)aiAPIKeyProviderVendors", start)
        callback = source[start:end]
        producer = (ROOT / "sources/AITerm/AIPluginClient.swift").read_text()
        self.assertIn('throw PluginError(reason: "Plugin not found")', producer)
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        with tempfile.TemporaryDirectory(prefix="iterm2-plugin-status-") as temporary:
            directory = Path(temporary)
            (directory / "plugin-status-callback.inc").write_text(callback)
            probe = directory / "probe"
            compiled = subprocess.run(
                ["xcrun", "clang", "-fobjc-arc", "-Wall", "-Werror", "-framework", "Foundation",
                 "-I", str(directory), str(ROOT / "tests/ai_plugin_status_localization_probe.m"),
                 "-o", str(probe)], capture_output=True, text=True, timeout=45)
            self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
            for language in ("en", "zh-Hans"):
                resources = directory / f"{language}.lproj"
                resources.mkdir()
                values = {key: entry["localizations"][language]["stringUnit"]["value"]
                          for key, entry in catalog.items() if key.startswith(PREFIX)}
                (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))
                run = subprocess.run([str(probe), str(resources)], capture_output=True,
                                     text=True, timeout=5)
                self.assertEqual(run.returncode, 0, run.stderr)
                rows = json.loads(run.stdout)
                self.assertEqual(len(rows), 10)
                for row in rows:
                    problem = row["input"]
                    failed = problem is not None
                    with self.subTest(language=language, problem=problem, allowed=row["allowed"]):
                        display = problem
                        if problem == "Plugin not found" and language == "zh-Hans":
                            display = "未找到插件"
                        elif not failed:
                            display = ("Plugin installed and working ✅" if language == "en"
                                       else values[PREFIX + "plugin_installed_and_working.bb8c2eaf"])
                        self.assertEqual(row["display"], display)
                        self.assertEqual(row["logs"], ["problem=" + (problem if failed else "(null)")])
                        self.assertEqual(row["action"], "installPlugin:" if failed else "revealPlugin:")
                        self.assertEqual(row["enabled"], row["allowed"] if failed else True)
                        self.assertEqual(row["ok"], not failed)
                        self.assertEqual(row["scheduled"], 1 if failed else 0)
                        self.assertEqual(row["updates"], 1)
                        self.assertEqual(row["fits"], 1)
                        key = "install.8c1df2d5" if failed else "reveal_in_finder.cc849385"
                        self.assertEqual(row["button"], values[PREFIX + key])


if __name__ == "__main__":
    unittest.main()
