#!/bin/bash
set -e

echo "::group::Lake Lint Output"

# handle_exit function to handle the exit status of the script
# and set the lint-status output parameter accordingly
handle_exit() {
    exit_status=$?
    if [ $exit_status -ne 0 ]; then
        echo "lint-status=FAILURE" >>"$GITHUB_OUTPUT"
    else
        echo "lint-status=SUCCESS" >>"$GITHUB_OUTPUT"
    fi
    echo "::endgroup::"
    echo
}

trap handle_exit EXIT

lake lint
