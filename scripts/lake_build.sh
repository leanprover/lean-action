#!/bin/bash

# start log group
echo "::group::Lake Build Output"

# run `lake build $BUILD_ARGS` and set the build-status output parameter accordingly
if lake build "$BUILD_ARGS"; then
    echo "build-status=SUCCESS" >>"$GITHUB_OUTPUT"
else
    echo "build-status=FAILURE" >>"$GITHUB_OUTPUT"
fi

# end log group and add a new line to improve readabiltiy
echo "::endgroup::"
echo
