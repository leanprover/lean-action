#!/bin/bash
set -e

echo "::group::Lake Test Output"

handle_exit() {
    exit_status=$?
    if [ $exit_status -ne 0 ]; then
        echo "test-status=FAILURE" >>"$GITHUB_OUTPUT"
    else
        echo "test-status=SUCCESS" >>"$GITHUB_OUTPUT"
    fi
    echo "::endgroup::"
    echo
}

trap handle_exit EXIT

# Get the directory of the script
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# use `lake check-test` to determine if the project has a test runner available
# TODO: add a more helpful error message once the test frame work matures
if ! lake check-test; then
    echo "::error::lake check-test failed: could not find a test runner"
    cat "$SCRIPT_DIR"/step_summaries/lake_check_error.md >>"$GITHUB_STEP_SUMMARY"
    exit 1
fi

lake test
