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

sandbox_setup="${LAKE_CHECK_SANDBOX_INPUT:-none}"
case "$sandbox_setup" in
    none | apparmor | sysctl | setuid) ;;
    *)
        failure_message="\`lake-check-sandbox\` must be \"none\", \"apparmor\", \"sysctl\" or \"setuid\", got \"${sandbox_setup}\""
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
#
# Exercise the namespace and mount operations Lake itself uses, not just a bind: a runner can
# permit `--ro-bind` and still refuse the sandbox Lake actually builds.
sandbox_probe_output=""
sandbox_works() {
    sandbox_probe_output="$("$sandbox_exe" --unshare-all --ro-bind / / --proc /proc --dev /dev true 2>&1)"
}

# Privileged setup is only ever applied to a distribution bubblewrap at a root-owned path. The
# executable to modify would otherwise be decided by PATH or by COMPARATOR_BWRAP, and neither
# establishes that the target is bubblewrap or that modifying it is safe.
assert_trusted_sandbox_exe() {
    if [ -n "${COMPARATOR_BWRAP:-}" ]; then
        failure_message="\`lake-check-sandbox: ${sandbox_setup}\` will not modify the executable named by COMPARATOR_BWRAP. Provision that sandbox yourself, or unset COMPARATOR_BWRAP to use the distribution's bubblewrap."
        exit 2
    fi
    if [ -L "$sandbox_exe" ]; then
        failure_message="\`lake-check-sandbox: ${sandbox_setup}\` will not modify ${sandbox_exe}, which is a symbolic link; the target it resolves to today need not be the one modified."
        exit 2
    fi
    case "$sandbox_exe" in
        /usr/bin/bwrap | /bin/bwrap) ;;
        *)
            failure_message="\`lake-check-sandbox: ${sandbox_setup}\` only modifies a distribution bubblewrap at /usr/bin/bwrap or /bin/bwrap, and this runner's is at ${sandbox_exe}. Grant it user namespaces yourself instead."
            exit 2
            ;;
    esac
    if [ "$(stat -c '%U' "$sandbox_exe")" != "root" ]; then
        # `chmod u+s` on a file owned by the job user grants that user's own privileges, not
        # root's, so it would not make the sandbox work and would not mean what it appears to.
        failure_message="\`lake-check-sandbox: ${sandbox_setup}\` will not modify ${sandbox_exe}, which is not owned by root."
        exit 2
    fi
}

if ! sandbox_works; then
    case "$sandbox_setup" in
        apparmor)
            # Ubuntu's own mechanism: the restriction denies unprivileged user namespaces to
            # programs whose AppArmor profile does not grant `userns`. Granting it here covers
            # bubblewrap and the processes it starts, which inherit an unconfined profile; it does
            # not cover the rest of the runner.
            assert_trusted_sandbox_exe
            if ! command -v apparmor_parser > /dev/null 2>&1; then
                failure_message="\`lake-check-sandbox: apparmor\` needs \`apparmor_parser\`, which is not on this runner. Use \"sysctl\" or \"setuid\" instead."
                exit 2
            fi
            if [ -e /etc/apparmor.d/bwrap ]; then
                failure_message="\`lake-check-sandbox: apparmor\` will not overwrite the existing AppArmor policy at /etc/apparmor.d/bwrap. Remove it, or grant bubblewrap user namespaces yourself."
                exit 2
            fi
            echo "::warning::\`lake-check-sandbox: apparmor\` is installing an AppArmor profile granting ${sandbox_exe}, and the processes it starts, permission to create user namespaces. The runner's restriction stays in force for everything else. On a persistent self-hosted runner the profile outlives this job."
            if ! sudo tee /etc/apparmor.d/lean-action-bwrap > /dev/null <<PROFILE
abi <abi/4.0>,
include <tunables/global>

profile lean-action-bwrap ${sandbox_exe} flags=(unconfined) {
  userns,
  include if exists <local/lean-action-bwrap>
}
PROFILE
            then
                failure_message="\`lake-check-sandbox: apparmor\` could not write /etc/apparmor.d/lean-action-bwrap. This runner probably does not offer passwordless sudo."
                exit 2
            fi
            if ! sudo apparmor_parser -r /etc/apparmor.d/lean-action-bwrap; then
                failure_message="\`lake-check-sandbox: apparmor\` could not load the AppArmor profile for ${sandbox_exe}. Use \"sysctl\" or \"setuid\" instead."
                exit 2
            fi
            ;;
        sysctl)
            echo "::warning::\`lake-check-sandbox: sysctl\` is relaxing kernel.apparmor_restrict_unprivileged_userns on this runner. This affects every program on the runner, not just bubblewrap, and nothing restores it: on a persistent self-hosted runner it stays relaxed for later jobs too. \`lake-check-sandbox: apparmor\` is narrower."
            if ! sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0; then
                failure_message="\`lake-check-sandbox: sysctl\` could not set \`kernel.apparmor_restrict_unprivileged_userns\`. This runner either does not have that knob, in which case its sandbox is blocked by something else, or does not offer passwordless sudo."
                exit 2
            fi
            ;;
        setuid)
            assert_trusted_sandbox_exe
            echo "::warning::\`lake-check-sandbox: setuid\` is installing ${sandbox_exe} setuid root. The setuid bit persists on disk, so on a persistent self-hosted runner it outlives this job."
            if ! sudo chmod u+s "$sandbox_exe"; then
                failure_message="\`lake-check-sandbox: setuid\` could not make ${sandbox_exe} setuid root. This runner probably does not offer passwordless sudo."
                exit 2
            fi
            ;;
    esac
fi

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
