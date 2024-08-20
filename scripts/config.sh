#!/bin/bash
set -e

# start log group
echo "::group::Configure lean-action"

# Get the directory of the script to read the step summaries md files
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Verify that a lake-manifest.json exist
if [ ! -f lake-manifest.json ]; then
  echo "::error::No lake-manifest.json found. Run lake update to generate manifest"
  echo "::error::Exiting with status 1"
  exit 1
fi

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

# If the user specifies `lint: true`
if [ "$LINT" = "true" ]; then
    echo "lint: true"
    # only run `lake lint` if `lake check-lint` returns true
    if ! lake check-lint; then
        echo "lake check-lint failed -> exiting with status 1"
        echo "::error::lake check-lint failed: could not find a lint driver"
        exit 1
    else
        echo "lake check-lint succeeded -> will run lake lint"
        run_lake_lint="true"
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

    # only run `lake lint` with `auto-config: true` if `lake check-lint` returns true
    if lake check-lint; then
        echo "lake check-lint succeeded -> will run lake lint"
        run_lake_lint="true"
    else
        echo "lake check-test failed -> will not run lake lint"
    fi
fi

# Set the `build`, `test`, and `lint` output parameters to be used to determine later steps
{
    echo "run-lake-build=$run_lake_build"
    echo "run-lake-test=$run_lake_test"
    echo "run-lake-lint=$run_lake_lint"
} >>"$GITHUB_OUTPUT"
