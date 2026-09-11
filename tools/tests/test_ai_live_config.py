"""Exercise live-test credential transport with synthetic data and no Xcode/API."""

import json
import os
from pathlib import Path
import selectors
import shutil
import signal
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SYNTHETIC_KEY = 'synthetic-only-quote"-slash\\-newline\n-tab\t'
PATH = os.pathsep.join((str(Path(sys.executable).parent), "/usr/bin", "/bin"))
PROBE = r'''#!/usr/bin/env python3
import json, os, pathlib, signal, stat, sys, time
root = pathlib.Path.cwd()
path = pathlib.Path(os.environ.get("TEST_RUNNER_ITERM2_AI_LIVE_CONFIG_PATH",
                                   root / ".iterm2-ai-live.json"))
snapshot = {"path": str(path), "arguments": sys.argv[1:],
            "outside_repo": not path.resolve().is_relative_to(root.resolve()),
            "key_in_environment": "OPENAI_API_KEY" in os.environ}
try:
    config = json.loads(path.read_text())
    snapshot.update(valid_json=True, key_matches=config.get("OPENAI_API_KEY") ==
                    os.environ["SYNTHETIC_EXPECTED"],
                    project_matches=config.get("PROJECT_ROOT") == str(root.resolve()),
                    mode=stat.S_IMODE(path.stat().st_mode),
                    directory_mode=stat.S_IMODE(path.parent.stat().st_mode))
except (OSError, ValueError):
    snapshot["valid_json"] = False
print(json.dumps(snapshot), flush=True)
mode = os.environ.get("SYNTHETIC_MODE", "success")
if mode in ("signal", "timeout", "concurrent"):
    # Finite fake workload, never a real build or vendor call.
    time.sleep(3)
sys.exit(7 if mode == "failure" else 0)
'''


class AILiveRunnerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="iterm2-ai-transport-test-")
        self.addCleanup(self.temporary.cleanup)
        base = Path(self.temporary.name)
        self.repo = base / "repo"
        (self.repo / "tools").mkdir(parents=True)
        (self.repo / "AILiveHarness").mkdir()
        self.tempdir = base / "temporary"
        self.tempdir.mkdir()
        for name in ("run_ai_live.sh", "run_ai_live.py"):
            if (ROOT / "tools" / name).exists():
                shutil.copy2(ROOT / "tools" / name, self.repo / "tools" / name)
        fake_runner = self.repo / "tools/run_tests.expect"
        fake_runner.write_text(PROBE)
        fake_runner.chmod(0o700)
        (self.repo / "AILiveHarness/Methods.swift").write_text(
            "    func test_synthetic_smoke() {}\n    func test_other() {}\n")
        self.environment = {
            "PATH": PATH, "TMPDIR": str(self.tempdir),
            "OPENAI_API_KEY": "synthetic-only-simple",
            "SYNTHETIC_EXPECTED": "synthetic-only-simple",
            "ITERM2_AI_LIVE_TIMEOUT_SECONDS": "10",
        }

    def launch(self, argument="test_synthetic_smoke", **environment):
        process = subprocess.Popen(
            ["/bin/bash", str(self.repo / "tools/run_ai_live.sh"), argument],
            cwd=self.repo, env={**self.environment, **environment},
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            start_new_session=True,
        )
        self.addCleanup(self.stop_if_running, process)
        return process

    def stop_if_running(self, process):
        if process.poll() is not None:
            return
        process.send_signal(signal.SIGTERM)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=5)

    def finish(self, process):
        try:
            stdout, stderr = process.communicate(timeout=15)
        except BaseException:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.communicate(timeout=5)
            raise
        self.assertNotIn(self.environment["OPENAI_API_KEY"], stderr)
        return process.returncode, stdout, stderr

    def read_snapshot(self, process):
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            if not selector.select(timeout=5):
                process.send_signal(signal.SIGTERM)
                self.finish(process)
                self.fail("Synthetic runner did not become ready within five seconds")
        return json.loads(process.stdout.readline())

    def assert_cleaned(self, snapshot):
        self.assertTrue(snapshot["outside_repo"])
        self.assertFalse(Path(snapshot["path"]).exists())
        self.assertFalse(Path(snapshot["path"]).parent.exists())
        self.assertFalse((self.repo / ".iterm2-ai-live.json").exists())

    def test_success_and_failure_remove_private_config(self):
        for mode, expected in (("success", 0), ("failure", 7)):
            with self.subTest(mode=mode):
                code, stdout, _ = self.finish(self.launch(SYNTHETIC_MODE=mode))
                self.assertEqual(code, expected)
                snapshot = json.loads(stdout)
                self.assertTrue(snapshot["valid_json"])
                self.assertTrue(snapshot["key_matches"])
                self.assertTrue(snapshot["project_matches"])
                self.assertEqual(snapshot["mode"], 0o600)
                self.assertEqual(snapshot["directory_mode"], 0o700)
                self.assertFalse(snapshot["key_in_environment"])
                self.assertEqual(snapshot["arguments"],
                                 ["ModernTests/AILiveHarness/test_synthetic_smoke"])
                self.assert_cleaned(snapshot)

    def test_json_control_characters_and_filter(self):
        code, stdout, stderr = self.finish(self.launch(
            "smoke", OPENAI_API_KEY=SYNTHETIC_KEY, SYNTHETIC_EXPECTED=SYNTHETIC_KEY))
        self.assertEqual(code, 0)
        self.assertNotIn(SYNTHETIC_KEY, stdout + stderr)
        snapshot = json.loads(stdout)
        self.assertTrue(snapshot["valid_json"])
        self.assertTrue(snapshot["key_matches"])
        self.assertEqual(snapshot["arguments"],
                         ["ModernTests/AILiveHarness/test_synthetic_smoke"])
        self.assert_cleaned(snapshot)

    def test_unmatched_filter_leaves_no_config(self):
        code, stdout, _ = self.finish(self.launch("no_such_synthetic_method"))
        self.assertEqual(code, 2)
        self.assertEqual(stdout, "")
        self.assertFalse((self.repo / ".iterm2-ai-live.json").exists())
        self.assertEqual(list(self.tempdir.iterdir()), [])

    def test_signal_cleans_after_child_started(self):
        process = self.launch(SYNTHETIC_MODE="signal")
        snapshot = self.read_snapshot(process)
        process.send_signal(signal.SIGTERM)
        code, _, _ = self.finish(process)
        self.assertEqual(code, 128 + signal.SIGTERM)
        self.assert_cleaned(snapshot)

    def test_timeout_cleans_private_config(self):
        code, stdout, _ = self.finish(self.launch(
            SYNTHETIC_MODE="timeout", ITERM2_AI_LIVE_TIMEOUT_SECONDS="1"))
        self.assertEqual(code, 124)
        self.assert_cleaned(json.loads(stdout))

    def test_concurrent_invocations_have_separate_configs(self):
        first = self.launch(SYNTHETIC_MODE="concurrent")
        second = self.launch(SYNTHETIC_MODE="concurrent")
        one = self.read_snapshot(first)
        two = self.read_snapshot(second)
        try:
            self.assertNotEqual(one["path"], two["path"])
        finally:
            first.send_signal(signal.SIGTERM)
            second.send_signal(signal.SIGTERM)
            self.finish(first)
            self.finish(second)
        self.assert_cleaned(one)
        self.assert_cleaned(two)

    def test_repository_tmpdir_is_rejected(self):
        code, stdout, _ = self.finish(self.launch(TMPDIR=str(self.repo)))
        self.assertNotEqual(code, 0)
        self.assertEqual(stdout, "")
        self.assertFalse((self.repo / ".iterm2-ai-live.json").exists())


class AILiveConfigReaderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="iterm2-ai-reader-test-")
        cls.addClassCleanup(cls.temporary.cleanup)
        base = Path(cls.temporary.name)
        cls.repo = base / "repo"
        source_dir = cls.repo / "AILiveHarness"
        source_dir.mkdir(parents=True)
        (cls.repo / ".git").mkdir()
        text = (ROOT / "AILiveHarness/AILiveHarness.swift").read_text()
        path_start = text.index("    nonisolated static func configFilePath()")
        path_end = text.index("    override func setUpWithError()", path_start)
        load_start = text.index("    private static func loadConfig()")
        load_end = text.index("    private static func loadKeys()", load_start)
        # Compile the actual reader bodies, without XCTest/AppKit or vendor code.
        probe = source_dir / "Probe.swift"
        probe.write_text(
            'import Foundation\nimport Darwin\nclass Probe {\n'
            'static let configFileName = ".iterm2-ai-live.json"\n'
            'private static var cachedConfig: [String: String]?\n' +
            text[path_start:path_end] + text[load_start:load_end] +
            'static func run() {\n'
            'if CommandLine.arguments.count == 1 { print(configFilePath()); return }\n'
            'let before = loadConfig() != nil\n'
            'if before { try? FileManager.default.removeItem(atPath: configFilePath()) }\n'
            'print("\\(before),\\(loadConfig() != nil)")\n}\n}\nProbe.run()\n')
        cls.binary = base / "reader"
        result = subprocess.run(["xcrun", "swiftc", "-warnings-as-errors", str(probe), "-o", str(cls.binary)],
                                capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise AssertionError(result.stderr)

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(
            prefix="iterm2-ai-live.", dir=self.temporary.name)
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "config.json"
        self.path.write_text(json.dumps({"PROJECT_ROOT": str(self.repo.resolve()),
                                        "OWNER_PID": str(os.getpid()),
                                        "OPENAI_API_KEY": "synthetic-only-reader"}))
        self.path.chmod(0o600)

    def read(self, path=None, remove=False):
        env = {"PATH": PATH}
        if path is not None:
            env["ITERM2_AI_LIVE_CONFIG_PATH"] = str(path)
        result = subprocess.run([str(self.binary)] + (["remove"] if remove else []),
                                env=env, capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def test_no_environment_does_not_discover_legacy_root_config(self):
        legacy = self.repo / ".iterm2-ai-live.json"
        legacy.write_text('{"OPENAI_API_KEY":"synthetic-only-legacy"}')
        try:
            self.assertEqual(self.read(), "/dev/null")
            self.assertTrue(legacy.exists())
        finally:
            legacy.unlink()

    def test_valid_config_and_no_cached_opt_in_after_removal(self):
        # Foundation normalizes /private/var to /var; Python realpath does the
        # reverse. Require the same file, not an arbitrary spelling of its alias.
        self.assertTrue(self.path.samefile(self.read(self.path)))
        self.assertEqual(self.read(self.path, remove=True), "true,false")

    def test_rejects_unsafe_permissions_and_symlinks(self):
        self.path.chmod(0o644)
        self.assertEqual(self.read(self.path), "/dev/null")
        self.path.chmod(0o600)
        Path(self.directory.name).chmod(0o755)
        self.assertEqual(self.read(self.path), "/dev/null")
        Path(self.directory.name).chmod(0o700)
        original = self.path.with_name("payload.json")
        self.path.rename(original)
        self.path.symlink_to(original)
        self.assertEqual(self.read(self.path), "/dev/null")

    def test_rejects_wrong_worktree_and_dead_owner(self):
        owner = subprocess.Popen(["/usr/bin/true"])
        owner.wait(timeout=5)
        for update in ({"PROJECT_ROOT": "/wrong/worktree"}, {"OWNER_PID": "0"},
                       {"OWNER_PID": str(owner.pid)}):
            data = {"PROJECT_ROOT": str(self.repo.resolve()), "OWNER_PID": str(os.getpid())}
            self.path.write_text(json.dumps({**data, **update}))
            self.assertEqual(self.read(self.path), "/dev/null")


class PlainTestRunnerTests(unittest.TestCase):
    def test_plain_tests_clear_opt_in_without_deleting_legacy_file(self):
        with tempfile.TemporaryDirectory(prefix="iterm2-plain-runner-test-") as temporary:
            root = Path(temporary)
            runner = root / "run_tests.expect"
            shutil.copy2(ROOT / "tools/run_tests.expect", runner)
            legacy = root / ".iterm2-ai-live.json"
            legacy.write_text('{"OPENAI_API_KEY":"synthetic-only-legacy"}')
            fake = root / "xcodebuild"
            fake.write_text('#!/usr/bin/env python3\nimport json, os\n'
                            'print(json.dumps({k: k in os.environ for k in '
                            '["TEST_RUNNER_ITERM2_AI_LIVE_CONFIG_PATH", '
                            '"ITERM2_AI_LIVE_CONFIG_PATH"]}))\n')
            fake.chmod(0o700)
            env = {"PATH": str(root) + os.pathsep + PATH,
                   "TEST_RUNNER_ITERM2_AI_LIVE_CONFIG_PATH": str(legacy),
                   "ITERM2_AI_LIVE_CONFIG_PATH": str(legacy)}
            result = subprocess.run(["/usr/bin/expect", str(runner), "ModernTests/Fake"],
                                    cwd=root, env=env, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            snapshot = next(json.loads(line) for line in result.stdout.splitlines()
                            if line.startswith("{"))
            self.assertFalse(any(snapshot.values()))
            self.assertTrue(legacy.exists())

    def test_opt_in_without_private_path_fails_before_starting_tests(self):
        # Even if the production guard regresses, this test must never build.
        with tempfile.TemporaryDirectory(prefix="iterm2-no-live-path-test-") as temporary:
            fake = Path(temporary) / "xcodebuild"
            fake.write_text("#!/bin/sh\nexit 99\n")
            fake.chmod(0o700)
            result = subprocess.run(
                ["/usr/bin/expect", str(ROOT / "tools/run_tests.expect"), "ModernTests/Fake"],
                env={"PATH": temporary + os.pathsep + PATH, "ITERM2_AI_LIVE_KEEP_CONFIG": "1"},
                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 2)
        self.assertNotIn("spawn xcodebuild", result.stdout)


if __name__ == "__main__":
    unittest.main()
