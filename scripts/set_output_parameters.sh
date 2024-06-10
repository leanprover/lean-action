#!/bin/bash

# Group logging using the ::group:: workflow command
echo "::group::Set Output Parameters"

# If the BUILD_STATUS environment variable is not set,
# set the `build-status` output parameter to NOT_RUN
# Otherwise, set it to the value of the BUILD_STATUS environment variable
if [ "$BUILD_STATUS" = "" ]; then
    echo "build-status=NOT_RUN" >>"$GITHUB_OUTPUT"
else
    echo "build-status=$BUILD_STATUS" >>"$GITHUB_OUTPUT"
fi

# If the TEST_STATUS environment variable is not set,
# set the `test-status` output parameter to NOT_RUN
# Otherwise, set it to the value of the TEST_STATUS environment variable
if [ "$TEST_STATUS" = "" ]; then
    echo "test-status=NOT_RUN" >>"$GITHUB_OUTPUT"
else
    echo "test-status=$TEST_STATUS" >>"$GITHUB_OUTPUT"
fi
echo "::endgroup::"
