#!/usr/bin/env bash
set -euo pipefail

# Group logging using the ::group:: workflow command
echo "::group::lake check Output"
echo "Checking the project with \`lake check\`"

# Set by the checks below when they can name the failure precisely; handle_exit falls back to a
# generic message for anything that fails without setting one.
failure_message=""

# The deprecated `nanoda` step delegates here on toolchains that bundle the checkers, and has to
# keep reporting under its own output name.
status_name="${LAKE_CHECK_STATUS_NAME:-lake-check-status}"

# handle_exit captures the failing command's status, records the step output, and re-exits with
# the same status.
handle_exit() {
    exit_status=$?
    echo "::endgroup::"
    if [ "$exit_status" -ne 0 ]; then
        echo "${status_name}=FAILURE" >> "$GITHUB_OUTPUT"
        echo "::error::${failure_message:-lake check failed}"
    else
        echo "${status_name}=SUCCESS" >> "$GITHUB_OUTPUT"
    fi
    exit "$exit_status"
}
trap handle_exit EXIT

# The step guard in `action.yml` only runs this script when `lake-check` is not "false", so
# anything other than the two running modes is a typo worth failing on rather than ignoring.
mode="${LAKE_CHECK_INPUT:-}"
case "$mode" in
    true | paranoid) ;;
    *)
        failure_message="\`lake-check\` must be \"false\", \"true\" or \"paranoid\", got \"${mode}\""
        exit 1
        ;;
esac

# `lake check` sandboxes the code it checks with bubblewrap, which needs Linux namespaces; Lake
# refuses to run anywhere else, so say so here rather than letting it fail further in.
runner_os="$(uname -s)"
if [ "$runner_os" != "Linux" ]; then
    failure_message="\`lake-check\` requires a Linux runner: \`lake check\` sandboxes the code it checks with bubblewrap, which needs Linux namespaces. This runner is ${runner_os}."
    exit 1
fi

# Feature-detect from the help text rather than comparing version strings: toolchains are often
# nightlies or PR builds whose versions do not order usefully. A Lake without `lake check` prints
# its top-level help here and still exits 0, so match on content, not on the exit status.
check_help="$(lake check --help 2>&1 || true)"

case "$check_help" in
    *"Check this project against external checker(s)"*) ;;
    *)
        failure_message="\`lake-check\` needs \`lake check\`, which requires Lean v4.35.0-rc1 or newer."
        exit 1
        ;;
esac

if [ "$mode" = "paranoid" ]; then
    case "$check_help" in
        *"--paranoid"*) ;;
        *)
            failure_message="\`lake-check: paranoid\` needs \`lake check --paranoid\`, which requires Lean v4.35.0-rc2 or newer. This toolchain has \`lake check\`, so \`lake-check: true\` would work."
            exit 1
            ;;
    esac
fi

# `lake check` looks for `bwrap` on PATH unless COMPARATOR_BWRAP points at it. The GitHub-hosted
# Ubuntu images do not ship bubblewrap, so install it the way the nanoda path installs Rust.
if [ -n "${COMPARATOR_BWRAP:-}" ] && [ -x "${COMPARATOR_BWRAP}" ]; then
    echo "Using the sandbox at COMPARATOR_BWRAP=${COMPARATOR_BWRAP}"
elif ! command -v bwrap > /dev/null 2>&1; then
    echo "bubblewrap not found; installing it"
    if ! command -v apt-get > /dev/null 2>&1; then
        failure_message="\`lake-check\` needs \`bwrap\` on PATH, and \`apt-get\` is not available to install it. Install bubblewrap before calling lean-action, or point COMPARATOR_BWRAP at it."
        exit 1
    fi
    sudo apt-get update
    sudo apt-get install -y bubblewrap
fi

# `lake check` resolves dependencies inside the sandbox, which is not granted write access to the
# project directory, so `lake-manifest.json` has to exist before it starts. `lake build` writes one
# and is a no-op when the project is already up to date; it also pre-populates `.lake`, which
# matters because the sandboxed build has no network.
echo "Building the project..."
lake build

# Keep a copy of the output: a sandbox that fails to start has to be told apart from a project
# that was rejected, and `lake check` does not distinguish them by exit code.
check_log="$(mktemp "${RUNNER_TEMP:-/tmp}/lake-check.XXXXXX")"

status=0
if [ "$mode" = "paranoid" ]; then
    echo "Running \`lake check --paranoid\`: Lean's own kernel plus every bundled external checker"
    lake check --paranoid 2>&1 | tee "$check_log" || status=$?
else
    echo "Running \`lake check\`"
    lake check 2>&1 | tee "$check_log" || status=$?
fi

# `bwrap` failing to start exits 1, the same code as a genuine rejection: the documented exit 2
# only covers `bwrap` being missing outright. Reporting "your project was rejected" when nothing
# was ever checked is the worst possible outcome, so key off the sandbox's own diagnostic.
if [ "$status" -ne 0 ] && grep -q "^bwrap:" "$check_log"; then
    bwrap_error="$(grep -m1 "^bwrap:" "$check_log")"
    rm -f "$check_log"
    failure_message="\`lake check\` could not start its sandbox (${bwrap_error}). Nothing was checked; this is a setup problem, not a finding about the project. GitHub-hosted Ubuntu runners block unprivileged user namespaces, which bubblewrap needs."
    exit 2
fi
rm -f "$check_log"

case "$status" in
    0)
        echo "lake check accepted the project"
        ;;
    1)
        failure_message="\`lake check\` rejected the project: a checker rejected it, it uses an axiom that is not permitted, or the build did not succeed."
        exit 1
        ;;
    2)
        failure_message="\`lake check\` could not start: \`bwrap\` is missing or unusable, the project has no \`lake-manifest.json\`, or it has no default build targets. This is a setup problem, not a finding about the project."
        exit 2
        ;;
    *)
        failure_message="\`lake check\` exited with unexpected status ${status}."
        exit "$status"
        ;;
esac
