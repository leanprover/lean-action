#!/bin/bash
set -e

echo "::group::Lake Lint Output"

# Get the directory of the script to read the step summaries md files
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# handle_exit function to handle the exit status of the script
# and set the lint-status output parameter accordingly
handle_exit() {
    exit_status=$?
    if [ $exit_status -ne 0 ]; then
        echo "lint-status=FAILURE" >>"$GITHUB_OUTPUT"
        echo "::error::lake lint failed: could not find a test runner"
        cat "$SCRIPT_DIR"/step_summaries/lake_check_error.md >>"$GITHUB_STEP_SUMMARY"
    else
        echo "lint-status=SUCCESS" >>"$GITHUB_OUTPUT"
    fi
    echo "::endgroup::"
    echo
}

trap handle_exit EXIT

lake lint
