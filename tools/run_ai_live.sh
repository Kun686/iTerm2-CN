#!/bin/bash
# Live AI test harness runner. Drives AILiveHarness in the ModernTests
# bundle against real vendor APIs. Costs real money. NOT a unit test.
#
# Usage:
#   tools/run_ai_live.sh                  # every harness method
#   tools/run_ai_live.sh openai           # all OpenAI tests
#   tools/run_ai_live.sh smoke            # smoke across vendors
#   tools/run_ai_live.sh test_openai_smoke_streaming  # exact method
#
# Reads API keys from the environment:
#   OPENAI_API_KEY ANTHROPIC_API_KEY GEMINI_API_KEY DEEPSEEK_API_KEY
#
# Vendors with no key set are skipped automatically by the harness.
#
# By default the harness exercises every model in AIMetadata.swift for
# each vendor with a key. For a faster sweep, set per-vendor model lists
# via env vars before invoking this script:
#
#   ITERM2_AI_LIVE_OPENAI_MODELS=gpt-5,gpt-5-mini tools/run_ai_live.sh smoke
#
# Refusal scenarios write captured responses to
# ModernTests/Resources/SafetyRefusalFixtures/ only when explicitly
# requested. Set ITERM2_AI_LIVE_REFRESH_REFUSAL_FIXTURES=1 to refresh.
# Without it, refusal runs exercise the API path but leave the on-disk
# fixtures untouched so casual sweeps don't dirty the working tree.
#
# Credentials stay in a private 0700 temporary directory, never the repository.
# Xcode forwards only the 0600 JSON path through TEST_RUNNER_. The Python
# standard-library helper owns cleanup on exit, failure and signals. SIGKILL
# cannot be trapped; a leftover cannot opt in without its environment/live owner.
# Default time limit: 600 seconds. ITERM2_AI_LIVE_TIMEOUT_SECONDS accepts 1..3600.

set +x
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Resolve the filter argument to one or more -only-testing flags.
filter="${1:-}"
class_path="ModernTests/AILiveHarness"

if [[ -z "$filter" ]]; then
    only_testing_args=( "$class_path" )
elif [[ "$filter" == test_* ]]; then
    only_testing_args=( "${class_path}/${filter}" )
else
    # Discover test methods from AILiveHarness source files at script time.
    # Previously this list was hardcoded, which meant new test files (e.g.
    # AILiveAttachmentTests.swift with the 96-cell matrix) didn't show up
    # for substring filtering until the list was manually updated.
    methods=()
    while IFS= read -r m; do
        [[ -n "$m" ]] && methods+=( "$m" )
    done < <(grep -h -E '^\s*func test_[A-Za-z0-9_]+\(' "$PROJECT_DIR"/AILiveHarness/*.swift \
             | sed -E 's/^[[:space:]]*func (test_[A-Za-z0-9_]+).*/\1/' \
             | sort -u)
    matched=()
    for m in "${methods[@]}"; do
        if [[ "$m" == *"$filter"* ]]; then
            matched+=( "${class_path}/${m}" )
        fi
    done
    if [[ ${#matched[@]} -eq 0 ]]; then
        echo "No method names matched '$filter'." >&2
        echo "Pass 'openai', 'anthropic', 'gemini', 'deepseek', a scenario like 'smoke', or an exact test name." >&2
        exit 2
    fi
    only_testing_args=( "${matched[@]}" )
fi

# Keep the same selection. The helper waits for the child before cleanup.
# No secret is expanded into shell arguments.
exec python3 "$SCRIPT_DIR/run_ai_live.py" "${only_testing_args[@]}"
