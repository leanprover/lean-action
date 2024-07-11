#!/bin/bash
set -e

# start log group
echo "::group::Configure lean-action"

# Get the directory of the script to read the step summaries md files
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# If the user specifies `build: true`, then run `lake build`.
if [ "$BUILD" = "true" ]; then
    echo "build: true -> will run lake build"
    run_lake_build="true"
fi

# If the user specifies `test: true`
if [ "$TEST" = "true" ]; then
    echo "test: true"
    # only run `lake test` if `lake check-test` returns true
    if ! lake check-test; then
        echo "lake check-test failed -> exiting with status 1"
        echo "::error::lake check-test failed: could not find a test runner"
        cat "$SCRIPT_DIR"/step_summaries/lake_check_error.md >>"$GITHUB_STEP_SUMMARY"
        exit 1
    else
        echo "lake check-test succeeded -> will run lake test"
        run_lake_test="true"
    fi
fi

if [ "$AUTO_CONFIG" = "true" ]; then
    # always run `lake build` with `auto-config: true`
    echo "auto-config: true"
    echo "-> will run lake build"
    run_lake_build="true"
    # only run `lake test` with `auto-config: true` if `lake check-test` returns true
    if lake check-test; then
        echo "lake check-test succeeded -> will run lake test"
        run_lake_test="true"
    else
        echo "lake check-test failed -> will not run lake test"
    fi
fi

# Set the `build` and `test` output parameters to be used to determine later steps
echo "run-lake-build=$run_lake_build" >>"$GITHUB_OUTPUT"
echo "run-lake-test=$run_lake_test" >>"$GITHUB_OUTPUT"
