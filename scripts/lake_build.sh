#!/bin/bash
set -e

# start log group
echo "::group::Lake Build Output"

# handle_exit function to handle the exit status of the script
# and set the build-status output parameter accordingly
handle_exit() {
    exit_status=$?
    if [ $exit_status -ne 0 ]; then
        echo "build-status=FAILURE" >>"$GITHUB_OUTPUT"
        echo "::error:: lake build failed"
    else
        echo "build-status=SUCCESS" >>"$GITHUB_OUTPUT"
        # end log group and add a new line to improve readabiltiy
        echo "::endgroup::"
        echo
    fi
}

trap handle_exit EXIT

lake build "$BUILD_ARGS"
