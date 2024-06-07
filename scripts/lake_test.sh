#!/bin/bash

echo "::group::Lake Test Output"
# Get the directory of the script
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# use `lake check-test` to determine if the project has a test runner available
# TODO: add a more helpful error message once the test frame work matures
if ! lake check-test; then
    echo "::error::lake check-test failed: could not find a test runner"
    cat "$SCRIPT_DIR"/step_summaries/lake_check_error.md >>"$GITHUB_STEP_SUMMARY"
    exit 1
fi

if lake test; then
    echo "TEST_STATUS=SUCCESS" >>"$GITHUB_OUTPUT"
else
    echo "TEST_STATUS=FAILURE" >>"$GITHUB_OUTPUT"
fi

echo "::endgroup::"
echo
