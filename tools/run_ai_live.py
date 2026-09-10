#!/usr/bin/env python3
"""Own a private, short-lived live-test config and the test runner lifecycle."""

import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time


API_KEYS = ("OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GEMINI_API_KEY",
            "DEEPSEEK_API_KEY", "LLAMA_API_KEY")
OPTIONS = {
    **{f"{vendor}_{setting}": f"ITERM2_AI_LIVE_{vendor}_{setting}"
       for vendor in ("OPENAI", "ANTHROPIC", "GEMINI", "DEEPSEEK")
       for setting in ("MODELS", "INTERVAL")},
    "REFRESH_REFUSAL_FIXTURES": "ITERM2_AI_LIVE_REFRESH_REFUSAL_FIXTURES",
    "CASSETTE_MODE": "ITERM2_AI_LIVE_CASSETTE_MODE",
    "CASSETTE_DIR": "ITERM2_AI_LIVE_CASSETTE_DIR",
    "REGENERATE_ATTACHMENT_FIXTURES": "ITERM2_AI_LIVE_REGENERATE_ATTACHMENT_FIXTURES",
}


def stop_runner(process):
    """Let Expect clean up its Xcode descendants, then reap the owned group."""
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        pass
    finally:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait(timeout=5)


def main():
    project = Path(__file__).resolve().parent.parent
    if not sys.argv[1:]:
        print("Invoke this helper through tools/run_ai_live.sh.", file=sys.stderr)
        return 2
    try:
        limit = int(os.environ.get("ITERM2_AI_LIVE_TIMEOUT_SECONDS", "600"))
        if not 1 <= limit <= 3600:
            raise ValueError
    except ValueError:
        print("ITERM2_AI_LIVE_TIMEOUT_SECONDS must be an integer from 1 to 3600.",
              file=sys.stderr)
        return 2

    temporary_root = Path(tempfile.gettempdir()).resolve()
    if temporary_root == project or project in temporary_root.parents:
        print("Live-test TMPDIR must be outside the repository.", file=sys.stderr)
        return 2

    interrupted = None

    def on_signal(number, _frame):
        nonlocal interrupted
        interrupted = number

    for number in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(number, on_signal)

    config = {name: os.environ[name] for name in API_KEYS if os.environ.get(name)}
    config.update({field: os.environ[name] for field, name in OPTIONS.items()
                   if os.environ.get(name)})
    config.update(PROJECT_ROOT=str(project), OWNER_PID=str(os.getpid()))
    environment = os.environ.copy()
    for name in API_KEYS:
        environment.pop(name, None)
        environment.pop("TEST_RUNNER_" + name, None)
    environment.pop("ITERM2_AI_LIVE_CONFIG_PATH", None)

    try:
        # mkdtemp creates mode 0700 before any secret exists. The explicit path
        # stays stable even if XCTest later changes its own temporary directory.
        with tempfile.TemporaryDirectory(prefix="iterm2-ai-live.",
                                         dir=temporary_root) as directory:
            path = Path(directory) / "config.json"
            descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                                 0o600)
            with os.fdopen(descriptor, "w") as stream:
                os.fchmod(stream.fileno(), 0o600)
                json.dump(config, stream)
            environment["TEST_RUNNER_ITERM2_AI_LIVE_CONFIG_PATH"] = str(path)
            environment["ITERM2_AI_LIVE_KEEP_CONFIG"] = "1"
            if interrupted is not None:
                return 128 + interrupted
            process = subprocess.Popen(
                [str(project / "tools/run_tests.expect"), *sys.argv[1:]],
                cwd=project, env=environment, start_new_session=True,
            )
            deadline = time.monotonic() + limit
            try:
                while True:
                    if interrupted is not None:
                        return 128 + interrupted
                    remaining = deadline - time.monotonic()
                    if remaining <= 0:
                        print("Live-test runner exceeded its time limit.", file=sys.stderr)
                        return 124
                    try:
                        code = process.wait(timeout=min(0.2, remaining))
                        return code if code >= 0 else 128 - code
                    except subprocess.TimeoutExpired:
                        continue
            finally:
                stop_runner(process)
    except (OSError, ValueError, subprocess.SubprocessError):
        # Do not echo environment values, JSON contents or subprocess payloads.
        print("Unable to create or run the private live-test configuration.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
