#!/bin/bash
set -e

echo "::group::mk_all Output"

# handle_exit function to handle the exit status of the script
# and set the mk_all-status output parameter accordingly
handle_exit() {
    exit_status=$?
    if [ $exit_status -ne 0 ]; then
        echo "mk_all-status=FAILURE" >>"$GITHUB_OUTPUT"
        echo "::error:: lake exe mk_all failed"
    else
        echo "mk_all-status=SUCCESS" >>"$GITHUB_OUTPUT"
        echo "::endgroup::"
    fi
}

trap handle_exit EXIT

lake exe mk_all --check
