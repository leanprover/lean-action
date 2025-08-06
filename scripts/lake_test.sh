#!/bin/bash
set -e

# start log group
echo "::group::Lake Test Output"

# handle_exit function to handle the exit status of the script
# and set the test-status output parameter accordingly
handle_exit() {
    exit_status=$?
    if [ $exit_status -ne 0 ]; then
        echo "test-status=FAILURE" >>"$GITHUB_OUTPUT"
        echo "::error:: lake test failed"
    else
        echo "test-status=SUCCESS" >>"$GITHUB_OUTPUT"
        # end log group and add a new line to improve readabiltiy
        echo "::endgroup::"
        echo
    fi
}

trap handle_exit EXIT

# use eval to ensure build arguments are expanded
eval "lake test $TEST_ARGS"
