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

sandbox_setup="${LAKE_CHECK_SANDBOX_INPUT:-none}"
case "$sandbox_setup" in
    none | sysctl | setuid) ;;
    *)
        failure_message="\`lake-check-sandbox\` must be \"none\", \"sysctl\" or \"setuid\", got \"${sandbox_setup}\""
        exit 1
        ;;
esac

# `lake check` looks for `bwrap` on PATH unless COMPARATOR_BWRAP points at it. The GitHub-hosted
# Ubuntu images do not ship bubblewrap, so install it the way the nanoda path installs Rust.
if [ -n "${COMPARATOR_BWRAP:-}" ] && [ -x "${COMPARATOR_BWRAP}" ]; then
    sandbox_exe="${COMPARATOR_BWRAP}"
    echo "Using the sandbox at COMPARATOR_BWRAP=${sandbox_exe}"
else
    if ! command -v bwrap > /dev/null 2>&1; then
        echo "bubblewrap not found; installing it"
        if ! command -v apt-get > /dev/null 2>&1; then
            failure_message="\`lake-check\` needs \`bwrap\` on PATH, and \`apt-get\` is not available to install it. Install bubblewrap before calling lean-action, or point COMPARATOR_BWRAP at it."
            exit 1
        fi
        sudo apt-get update
        sudo apt-get install -y bubblewrap
    fi
    sandbox_exe="$(command -v bwrap)"
fi

# Probe the sandbox before running the check. An environment that cannot sandbox has to be
# reported as a setup problem naming the input that fixes it, not as a failed check: `lake check`
# exits 1 either way, so by the time it has run the two are hard to tell apart.
sandbox_probe_output=""
sandbox_works() {
    sandbox_probe_output="$("$sandbox_exe" --ro-bind / / true 2>&1)"
}

if ! sandbox_works; then
    case "$sandbox_setup" in
        sysctl)
            echo "::warning::\`lake-check-sandbox: sysctl\` is relaxing kernel.apparmor_restrict_unprivileged_userns on this runner so bubblewrap can start. This affects the whole runner for the rest of the job."
            if ! sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0; then
                failure_message="\`lake-check-sandbox: sysctl\` could not set \`kernel.apparmor_restrict_unprivileged_userns\`. This runner either does not have that knob, in which case its sandbox is blocked by something else, or does not offer passwordless sudo."
                exit 2
            fi
            ;;
        setuid)
            echo "::warning::\`lake-check-sandbox: setuid\` is installing ${sandbox_exe} setuid root so bubblewrap can start."
            if ! sudo chmod u+s "$sandbox_exe"; then
                failure_message="\`lake-check-sandbox: setuid\` could not make ${sandbox_exe} setuid root. This runner probably does not offer passwordless sudo."
                exit 2
            fi
            ;;
    esac
fi

if ! sandbox_works; then
    # The remedy depends on which half of the sandbox was refused, so name the one that fits.
    # A denied uid map means user namespaces are blocked, which `lake-check-sandbox` can fix.
    # A denied `pivot_root` means the job is running inside a container, which it cannot.
    case "$sandbox_probe_output" in
        *"pivot_root"*)
            hint="The user namespace was created but \`pivot_root\` was refused, which means this job is running inside a container. No value of \`lake-check-sandbox\` can fix that. Run \`lake-check\` on a runner that is not containerised."
            ;;
        *"uid map"* | *"user namespace"*)
            if [ "$sandbox_setup" = "none" ]; then
                hint="This runner blocks the unprivileged user namespaces bubblewrap needs, which is the default on Ubuntu 24.04 and newer, including GitHub-hosted runners. Set \`lake-check-sandbox: sysctl\` to let lean-action relax \`kernel.apparmor_restrict_unprivileged_userns\` for this job, or \`lake-check-sandbox: setuid\` to install bubblewrap setuid root instead. Both need passwordless sudo."
            else
                hint="\`lake-check-sandbox: ${sandbox_setup}\` was applied and the sandbox still cannot start. Try the other value, or run on a runner that permits unprivileged user namespaces."
            fi
            ;;
        *)
            hint="Set \`lake-check-sandbox\` to \"sysctl\" or \"setuid\" if this runner needs a privileged change before bubblewrap can sandbox."
            ;;
    esac
    failure_message="\`lake check\` cannot start its sandbox, so nothing was checked: \`${sandbox_exe} --ro-bind / / true\` fails with \"${sandbox_probe_output}\". ${hint}"
    exit 2
fi
echo "Sandbox check passed: bubblewrap can create a user namespace here"

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
