#!/bin/bash

# start log group
echo "::group::Lake Build Output"

# run `lake build $BUILD_ARGS` and set the BUILD_STATUS output parameter accordingly
if lake build "$BUILD_ARGS"; then
    echo "BUILD_STATUS=SUCCESS" >>"$GITHUB_OUTPUT"
else
    echo "BUILD_STATUS=FAILURE" >>"$GITHUB_OUTPUT"
fi

# end log group and add a new line to improve readabiltiy
echo "::endgroup::"
echo
