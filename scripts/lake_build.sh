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
    else
        echo "build-status=SUCCESS" >>"$GITHUB_OUTPUT"
    fi

    # end log group and add a new line to improve readabiltiy
    echo "::endgroup::"
    echo
}

trap handle_exit EXIT

# run `lake build $BUILD_ARGS` and set the build-status output parameter accordingly
lake build "$BUILD_ARGS"
