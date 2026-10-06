#!/usr/bin/env bash
set -euo pipefail

# Group logging using the ::group:: workflow command
echo "::group::lake check Output"
echo "Checking the project with \`lake check\`"

# Set by the checks below when they can name the failure precisely; handle_exit falls back to a
# generic message for anything that fails without setting one.
failure_message=""

# handle_exit captures the failing command's status, records the step output, and re-exits with
# the same status.
handle_exit() {
    exit_status=$?
    echo "::endgroup::"
    if [ "$exit_status" -ne 0 ]; then
        echo "lake-check-status=FAILURE" >> "$GITHUB_OUTPUT"
        echo "::error::${failure_message:-lake check failed}"
    else
        echo "lake-check-status=SUCCESS" >> "$GITHUB_OUTPUT"
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

# Resolve the same sandbox executable Lake will use. An explicit COMPARATOR_BWRAP that cannot be
# run is an error rather than something to quietly paper over: Lake would still honour it, so
# falling back to `bwrap` here would probe one executable and check with another.
if [ -n "${COMPARATOR_BWRAP:-}" ]; then
    if [ ! -x "${COMPARATOR_BWRAP}" ]; then
        failure_message="COMPARATOR_BWRAP is set to \"${COMPARATOR_BWRAP}\", which is not an executable file. \`lake check\` would use it as its sandbox, so this is fatal rather than something to fall back from."
        exit 2
    fi
    sandbox_exe="${COMPARATOR_BWRAP}"
    echo "Using the sandbox at COMPARATOR_BWRAP=${sandbox_exe}"
else
    # The GitHub-hosted Ubuntu images do not ship bubblewrap, and neither do Namespace's.
    if ! command -v bwrap > /dev/null 2>&1; then
        echo "bubblewrap not found; installing it"
        if ! command -v apt-get > /dev/null 2>&1; then
            failure_message="\`lake-check\` needs \`bwrap\` on PATH, and \`apt-get\` is not available to install it. Install bubblewrap before calling lean-action, or point COMPARATOR_BWRAP at it."
            exit 2
        fi
        sudo apt-get update
        sudo apt-get install -y bubblewrap
    fi
    sandbox_exe="$(command -v bwrap)"
fi

# Probe the sandbox before running the check. An environment that cannot sandbox has to be
# reported as a setup problem naming the remedy, not as a failed check: `lake check` exits 1 both
# when it rejects a project and when bubblewrap fails to start, so by the time it has run the two
# are hard to tell apart.
sandbox_probe_output=""
sandbox_works() {
    sandbox_probe_output="$("$sandbox_exe" --ro-bind / / true 2>&1)"
}

if ! sandbox_works; then
    # The remedy depends on which half of the sandbox was refused, so name the one that fits.
    # A denied uid map means user namespaces are blocked; a denied `pivot_root` means the job is
    # running inside a container, which is a different problem with a different fix.
    case "$sandbox_probe_output" in
        *"pivot_root"*)
            hint="The user namespace was created but \`pivot_root\` was refused, which means this job is running in a container whose seccomp profile forbids it. On Namespace runners, request a privileged container: add \`namespace-features:container.privileged=true\` to \`runs-on\` and the \`-with-features\` suffix to the machine label. Otherwise use a runner that is not containerised."
            ;;
        *"uid map"* | *"user namespace"*)
            hint="This runner restricts the unprivileged user namespaces bubblewrap needs, as GitHub-hosted runners do. Grant them before calling lean-action, either with an AppArmor profile permitting \`userns\` for ${sandbox_exe}, or with \`sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0\`. See \"Independent kernel checks with \\\`lake check\\\`\" in the lean-action README."
            ;;
        *)
            hint="Make bubblewrap able to create its sandbox on this runner before calling lean-action."
            ;;
    esac
    failure_message="\`lake check\` cannot start its sandbox, so nothing was checked: \`${sandbox_exe} --ro-bind / / true\` fails with \"${sandbox_probe_output}\". ${hint}"
    exit 2
fi
echo "Sandbox check passed: bubblewrap can create a user namespace here"

# `lake check` builds the project itself, inside the sandbox. Whether the project is also built on
# the runner beforehand is the caller's choice, made with the `build` input: leaving it on is
# faster because `lake check` then has a populated `.lake`, while turning it off keeps the
# project's code off the runner entirely. Either way this script does not build it.

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

if [ "$status" -ne 0 ] && grep -q "^bwrap:" "$check_log"; then
    bwrap_error="$(grep -m1 "^bwrap:" "$check_log")"
    rm -f "$check_log"
    failure_message="\`lake check\` could not start its sandbox (${bwrap_error}). Nothing was checked; this is a setup problem, not a finding about the project."
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
        failure_message="\`lake check\` could not start: the project has no \`lake-manifest.json\`, or it has no default build targets. This is a setup problem, not a finding about the project."
        exit 2
        ;;
    *)
        failure_message="\`lake check\` exited with unexpected status ${status}."
        exit "$status"
        ;;
esac
