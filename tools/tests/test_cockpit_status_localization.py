"""Native count/prune routines plus real bucket/filter/display expressions.

Rows and the unrelated priority provider are synthetic. This does not launch
Cockpit, read live terminal statuses, or validate actual AppKit layout.
"""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest

from tools.tests.test_uv_shared_error_localization import member


ROOT = Path(__file__).resolve().parents[2]
PREFIX = "ui.swift.claudecode.cockpitwindowcontroller."
FIXTURES = ([], [None, None, "无状态", "Waiting"],
            [None, "No status", "无状态", "Custom %@ 用户"],
            ["No status"], [None], ["", "无状态", "Custom %@ 用户"])


class CockpitStatusLocalizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="iterm2-cockpit-status-")
        cls.addClassCleanup(temporary.cleanup)
        cls.directory = Path(temporary.name)
        source = (ROOT / "sources/ClaudeCode/CockpitWindowController.swift").read_text()
        members = [member(source, signature) for signature in (
            "private static func countStatuses(", "private static func prune(",
            "private static func pruneRow(", "private func statusSortKey(")]
        declarations = re.findall(r"^.*static let noStatusLabel = .+$", source, re.M)
        if len(declarations) != 1:
            raise AssertionError("Expected the actual no-status sentinel declaration")
        members += declarations
        if "private static func statusDisplayName(" in source:
            members.append(member(source, "private static func statusDisplayName("))
            declarations = re.findall(r"^.*private var reportedStatuses = .+$", source, re.M)
            if len(declarations) != 1:
                raise AssertionError("Expected the display-only reported-status cache")
            members += declarations
        rebuild = member(source, "fileprivate func rebuildRows(")
        counts = "statusCounts =" + rebuild.split("statusCounts =", 1)[1].split("let pruned =", 1)[0]
        update = member(source, "private func updateStatusFilter(")
        filters = "let total =" + update.split("let total =", 1)[1].split("let selectedIndex =", 1)[0]
        buckets = member(source, "private func bucketSessionsByStatus(")
        keys = re.findall(r"^\s*let bucketKey = .+$", buckets, re.M)
        if len(keys) != 1:
            raise AssertionError("Expected the actual grouping key expression")
        group_label = buckets.split("let identity = CockpitRow.Identity.group(scope, status)", 1)[1].split(
            "let groupRow =", 1)[0]
        template = (ROOT / "tests/cockpit_status_localization_probe.swift").read_text()
        for marker, content in {
            "MEMBERS": "\n".join(members), "PRE-FILTER-COUNTS": counts,
            "FILTER-ITEMS": filters, "BUCKET-KEY": keys[0], "GROUP-LABEL": group_label,
        }.items():
            label = "// COCKPIT-" + ("PRODUCTION-" if marker == "MEMBERS" else "") + marker
            if template.count(label) != 1:
                raise AssertionError("Missing or duplicate template marker: " + label)
            template = template.replace(label, content)
        template = template.replace("bundle: .main", "bundle: probeBundle")
        swift_path = cls.directory / "main.swift"
        swift_path.write_text(template)
        cls.probe = cls.directory / "cockpit-probe"
        result = subprocess.run(
            ["xcrun", "swiftc", "-warnings-as-errors", str(swift_path), "-o", str(cls.probe)],
            capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        catalog = json.loads((ROOT / "sources/Localizable.xcstrings").read_text())["strings"]
        cls.no_status_names = {}
        cls.filter_formats = {}
        for language in ("en", "zh-Hans"):
            resources = cls.directory / f"{language}.lproj"
            resources.mkdir()
            values = {key: entry["localizations"][language]["stringUnit"]["value"]
                      for key, entry in catalog.items() if key.startswith(PREFIX)}
            (resources / "Localizable.strings").write_bytes(plistlib.dumps(values))
            cls.no_status_names[language] = values[PREFIX + "no_status.eace244c"]
            cls.filter_formats[language] = values[PREFIX + "0_1.fa1e7180"]
            if re.findall(r"%[12]\$(?:@|lld)", cls.filter_formats[language]) != ["%1$@", "%2$lld"]:
                raise AssertionError("Expected the existing status/count filter placeholders")

    def check_language(self, language):
        result = subprocess.run([str(self.probe), str(self.directory / f"{language}.lproj")],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        snapshots = json.loads(result.stdout)
        self.assertEqual(len(snapshots), len(FIXTURES))
        for fixture, snapshot in zip(FIXTURES, snapshots):
            expected_members = {}
            for index, status in enumerate(fixture):
                key = "No status" if status is None else status
                expected_members.setdefault(key, []).append(str(index))
            expected_counts = {key: len(ids) for key, ids in expected_members.items()}
            with self.subTest(language=language, fixture=fixture, field="sentinel"):
                self.assertEqual(snapshot["sentinel"], "No status")
                self.assertTrue(snapshot["sentinelSortLast"])
            with self.subTest(language=language, fixture=fixture, field="counts/filter"):
                self.assertEqual(snapshot["counts"], expected_counts)
                self.assertEqual(snapshot["selected"], expected_members)
            groups = {row["key"]: row for row in snapshot["groups"]}
            filters = {row["key"]: row["title"] for row in snapshot["filters"] if row["key"] is not None}
            with self.subTest(language=language, fixture=fixture, field="groups/filter keys"):
                self.assertEqual(set(groups), set(expected_counts))
                self.assertEqual(set(filters), set(expected_counts))
            for key, ids in expected_members.items():
                display = self.no_status_names[language] if key == "No status" and key not in fixture else key
                filter_title = re.sub(r"%[12]\$(?:@|lld)",
                                      lambda match: display if match[0] == "%1$@" else str(len(ids)),
                                      self.filter_formats[language])
                with self.subTest(language=language, fixture=fixture, key=key, field="display"):
                    self.assertEqual(groups.get(key), {"key": key, "ids": ids, "label": f"{display} · {len(ids)}"})
                    self.assertEqual(filters.get(key), filter_title)

    def test_english_status_identity_and_display(self):
        self.check_language("en")

    def test_chinese_status_identity_and_display(self):
        self.check_language("zh-Hans")


if __name__ == "__main__":
    unittest.main()
