"""Actual adblock NSError constructors and log/settings-display consumers.

Only resource lookup and log/UI sinks are redirected. No adblock updater,
browser, defaults, notification observer, filesystem download or network runs.
"""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest

from tools import check_localizations as checker
from tools.tests.test_uv_shared_error_localization import member


ROOT = Path(__file__).resolve().parents[2]
PREFIX = "ui.swift.browser.adblocking.itermbrowseradblockmanager."
URL = "://synthetic 用户 %1$@ </script>\n"
ORIGINALS = (
    "Invalid adblock list URL: " + URL,
    "Failed to parse adblock list response",
    "Downloaded content is not valid JSON format",
    "Adblock rules haven't been updated for 14 days",
)
CHINESE = (
    "广告拦截列表 URL 无效：" + URL,
    "无法解析广告拦截列表响应",
    "下载的内容不是有效的 JSON 格式",
    "广告拦截规则已 14 天未更新",
)


class AdblockErrorLocalizationTests(unittest.TestCase):
    def test_errors_keep_raw_diagnostics_and_localize_only_settings_display(self):
        producer = (ROOT / "sources/Browser/AdBlocking/iTermBrowserAdblockManager.swift").read_text()
        consumer = (ROOT / "sources/Browser/Core/iTermBrowserManager.swift").read_text()
        errors = []
        for match in re.finditer(r'NSError\(domain: "iTermBrowserAdblockManager", code: (\d+),', producer):
            end = checker.swift_delimited_expression_end(producer, match.start() + len("NSError"), "(", ")")
            self.assertIsNotNone(end)
            errors.append((int(match[1]), producer[match.start():end]))
        self.assertEqual([code for code, _ in errors], [1, 2, 3, 4])
        failure = member(producer, "private func handleFailure(")
        logs = re.findall(r'^\s*RLog\("Adblock update failed: .*$', failure, re.M)
        self.assertEqual(len(logs), 1)
        constants = re.findall(r'^\s*@objc static let errorKey = .+$', producer, re.M)
        self.assertEqual(len(constants), 1)
        signature = "private static func localizedAdblockErrorDescription("
        helper = member(consumer, signature) if signature in consumer else ""
        template = (ROOT / "tests/adblock_error_localization_probe.swift").read_text()
        for marker, source in {
            "// ADBLOCK-ERROR-KEY": constants[0],
            "// ADBLOCK-ERROR-CONSTRUCTORS": "return [" + ",\n".join(error for _, error in errors) + "]",
            "// ADBLOCK-PRODUCER-LOG": logs[0],
            "// ADBLOCK-DISPLAY-HELPER": helper,
            "// ADBLOCK-NOTIFICATION-CONSUMER": member(consumer, "@objc private func adblockDidFail("),
        }.items():
            self.assertEqual(template.count(marker), 1)
            template = template.replace(marker, source)
        template = template.replace("bundle: .main", "bundle: probeBundle")
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        with tempfile.TemporaryDirectory(prefix="iterm2-adblock-display-") as directory:
            root = Path(directory)
            swift = root / "main.swift"
            swift.write_text(template)
            probe = root / "probe"
            compiled = subprocess.run(
                ["xcrun", "swiftc", "-warnings-as-errors", str(swift), "-o", str(probe)],
                capture_output=True, text=True, timeout=45)
            self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
            for language in ("en", "zh-Hans"):
                resources = root / f"{language}.lproj"
                resources.mkdir()
                values = {key: entry["localizations"][language]["stringUnit"]["value"]
                          for key, entry in catalog.items() if key.startswith(PREFIX)}
                self.assertEqual(len(values), 4)
                (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))
                run = subprocess.run([str(probe), str(resources), URL],
                                     capture_output=True, text=True, timeout=5)
                self.assertEqual(run.returncode, 0, run.stderr)
                snapshot = json.loads(run.stdout)
                self.assertEqual(len(snapshot["known"]), 4)
                for index, row in enumerate(snapshot["known"]):
                    expected = ORIGINALS[index]
                    for field, value in {
                        "domain": "iTermBrowserAdblockManager", "code": index + 1,
                        "userInfo": {"NSLocalizedDescription": expected},
                        "consumerLog": ["Adblock error: " + expected],
                        "producerLog": ["Adblock update failed: " + expected] if index < 3 else [],
                        "displayed": expected if language == "en" else CHINESE[index],
                        "success": False,
                    }.items():
                        with self.subTest(language=language, code=index + 1, field=field):
                            self.assertEqual(row[field], value)
                self.assertEqual(len(snapshot["passthrough"]), 8)
                for row in snapshot["passthrough"]:
                    with self.subTest(language=language, fallback=row["raw"]):
                        self.assertEqual(row["displayed"], row["raw"])
                        self.assertEqual(row["consumerLog"], ["Adblock error: " + row["raw"]])
                self.assertEqual(snapshot["missingError"], {"displayed": None, "logs": []})


if __name__ == "__main__":
    unittest.main()
