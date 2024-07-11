#!/bin/bash
set -e

echo "::group::Lake Test Output"

# handle_exit function to handle the exit status of the script
# and set the test-status output parameter accordingly
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

lake test
