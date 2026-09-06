#!/usr/bin/env python3

import plistlib
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "prepare_cn_info_plist.py"
CONFIGURATION_FILES = {
    "Development": "dev-iTerm2.plist",
    "Beta": "beta-iTerm2.plist",
    "Nightly": "nightly-iTerm2.plist",
    "Deployment": "release-iTerm2.plist",
}


class PrepareCNInfoPlistTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)
        self.plists = self.root / "plists"
        self.plists.mkdir()
        for filename in (*CONFIGURATION_FILES.values(), "preview-iTerm2.plist"):
            self._write_plist(filename)
        self.output = self.plists / "iTerm2.plist"

    def tearDown(self):
        self.temporary_directory.cleanup()

    def _document(self, **overrides):
        document = {
            "CFBundleName": "iTerm2",
            "FixtureName": "safe",
            "SUFeedURL": "https://iterm2.com/appcasts/final_modern.xml",
            "SUFeedURLForFinal": "https://iterm2.com/appcasts/final_modern.xml",
            "SUFeedURLForTesting": "https://iterm2.com/appcasts/testing_modern.xml",
        }
        document.update(overrides)
        return document

    def _write_plist(self, filename, **overrides):
        path = self.plists / filename
        path.write_bytes(plistlib.dumps(self._document(**overrides)))
        return path

    def _run(
        self,
        configuration,
        variant="release",
        temporary_directory=None,
        version=None,
        edition=None,
    ):
        arguments = [
            sys.executable,
            str(SCRIPT),
            "--source-root",
            str(self.root),
            "--configuration",
            configuration,
            "--variant",
            variant,
            "--output",
            str(self.output),
        ]
        if temporary_directory is not None:
            arguments.extend(["--temporary-directory", str(temporary_directory)])
        if version is not None:
            arguments.extend(["--version", version])
        if edition is not None:
            arguments.extend(["--edition", edition])
        return subprocess.run(
            arguments,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_selects_expected_plist_for_each_configuration(self):
        for configuration, filename in CONFIGURATION_FILES.items():
            with self.subTest(configuration=configuration):
                self._write_plist(filename, FixtureName=filename)
                result = self._run(configuration)
                self.assertEqual(result.returncode, 0, result.stderr)
                document = plistlib.loads(self.output.read_bytes())
                self.assertEqual(document["FixtureName"], filename)
                self.assertNotIn("iTermCNCommunityBuild", document)
                self.assertIn("SUFeedURL", document)

    def test_deployment_preview_selects_preview_plist(self):
        self._write_plist("preview-iTerm2.plist", FixtureName="preview")

        result = self._run("Deployment", variant="preview")

        self.assertEqual(result.returncode, 0, result.stderr)
        document = plistlib.loads(self.output.read_bytes())
        self.assertEqual(document["FixtureName"], "preview")

    def test_stale_output_is_replaced(self):
        self.output.write_bytes(
            plistlib.dumps({"iTermCNCommunityBuild": True})
        )

        result = self._run("Development")

        self.assertEqual(result.returncode, 0, result.stderr)
        document = plistlib.loads(self.output.read_bytes())
        self.assertNotIn("iTermCNCommunityBuild", document)
        self.assertEqual(
            document["SUFeedURL"],
            "https://iterm2.com/appcasts/final_modern.xml",
        )

    def test_writes_bundle_versions_before_publishing_output(self):
        result = self._run("Deployment", version="3.7.20260905")

        self.assertEqual(result.returncode, 0, result.stderr)
        document = plistlib.loads(self.output.read_bytes())
        self.assertEqual(document["CFBundleShortVersionString"], "3.7.20260905")
        self.assertEqual(document["CFBundleVersion"], "3.7.20260905")
        self.assertEqual(document["CFBundleGetInfoString"], "3.7.20260905")

    def test_can_create_atomic_temporary_file_outside_output_directory(self):
        temporary_directory = self.root / "xcode-temporary"

        result = self._run("Development", temporary_directory=temporary_directory)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.output.exists())
        self.assertEqual(list(temporary_directory.iterdir()), [])

    def test_cn_edition_is_derived_without_mutating_upstream_source(self):
        source = self.plists / "release-iTerm2.plist"
        before = source.read_bytes()

        result = self._run("Deployment", edition="cn")

        self.assertEqual(result.returncode, 0, result.stderr)
        document = plistlib.loads(self.output.read_bytes())
        self.assertEqual(document["CFBundleDisplayName"], "iTerm2-CN")
        self.assertEqual(document["CFBundleName"], "iTerm2")
        self.assertTrue(document["iTermCNCommunityBuild"])
        self.assertFalse(document["SUEnableAutomaticChecks"])
        self.assertFalse(document["SUAutomaticallyUpdate"])
        self.assertNotIn("SUFeedURL", document)
        self.assertNotIn("SUFeedURLForFinal", document)
        self.assertNotIn("SUFeedURLForTesting", document)
        self.assertEqual(source.read_bytes(), before)

    def test_upstream_edition_preserves_update_policy_and_identity(self):
        source_document = self._document(FixtureName="upstream")
        self._write_plist("dev-iTerm2.plist", FixtureName="upstream")

        result = self._run("Development", edition="upstream")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(plistlib.loads(self.output.read_bytes()), source_document)

    def test_rejects_cn_identity_in_shared_source_plist(self):
        self._write_plist(
            "dev-iTerm2.plist",
            CFBundleDisplayName="iTerm2-CN",
            iTermCNCommunityBuild=True,
        )

        result = self._run("Development", edition="cn")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("source plists must not define iTermCNCommunityBuild", result.stderr)

    def test_rejects_cn_bundle_name_in_shared_source_plist(self):
        self._write_plist("dev-iTerm2.plist", CFBundleName="iTerm2-CN")

        result = self._run("Development", edition="cn")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("source plists must not use the iTerm2-CN bundle name", result.stderr)

    def test_rejects_non_dictionary_source(self):
        (self.plists / "dev-iTerm2.plist").write_bytes(plistlib.dumps([]))

        result = self._run("Development")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("root must be a dictionary", result.stderr)

    def test_rejects_unknown_configuration_and_deployment_variant(self):
        unknown_configuration = self._run("Unknown")
        unknown_variant = self._run("Deployment", variant="unknown")
        unknown_edition = self._run("Development", edition="enterprise")

        self.assertNotEqual(unknown_configuration.returncode, 0)
        self.assertIn("unsupported build configuration", unknown_configuration.stderr)
        self.assertNotEqual(unknown_variant.returncode, 0)
        self.assertIn("unsupported Deployment plist variant", unknown_variant.stderr)
        self.assertNotEqual(unknown_edition.returncode, 0)
        self.assertIn("unsupported build edition", unknown_edition.stderr)


if __name__ == "__main__":
    unittest.main()
