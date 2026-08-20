#!/usr/bin/env bash
set -euo pipefail

# Group logging using the ::group:: workflow command
echo "::group::axiom-audit Output"
echo "Auditing axioms with leanprover-community/axiom-audit"

# Pin the tool by tag for readability AND verify the exact commit after clone (tags are mutable).
AXIOM_AUDIT_REF="v0.1.2"
AXIOM_AUDIT_SHA="46024e005996495c65ef609368e11ab39c4222e3"

# Work in a temp dir outside the package tree (avoids touching/colliding with the project).
WORKDIR="$(mktemp -d "${RUNNER_TEMP:-/tmp}/axiom-audit.XXXXXX")"

# handle_exit captures the failing command's status, records the step output, cleans up, and
# re-exits with the same status.
handle_exit() {
    exit_status=$?
    echo "::endgroup::"
    rm -rf "$WORKDIR"
    if [ "$exit_status" -ne 0 ]; then
        echo "axiom-audit-status=FAILURE" >> "$GITHUB_OUTPUT"
        echo "::error::axiom-audit check failed"
    else
        echo "axiom-audit-status=SUCCESS" >> "$GITHUB_OUTPUT"
    fi
    exit "$exit_status"
}
trap handle_exit EXIT

# Ensure the project is built: the audit reads compiled oleans, so a `build: false` configuration
# or a stale/partial build must not silently audit the wrong thing. `lake build` is a no-op if the
# project is already up to date.
echo "Building the project..."
lake build

# Clone and build the tool with the project's own toolchain (it is dependency-free, so this is a
# quick build), and verify the pinned commit.
echo "Fetching axiom-audit @ ${AXIOM_AUDIT_REF} (${AXIOM_AUDIT_SHA})..."
git clone --depth 1 --branch "$AXIOM_AUDIT_REF" https://github.com/leanprover-community/axiom-audit.git "$WORKDIR/axiom-audit"
got_sha="$(git -C "$WORKDIR/axiom-audit" rev-parse HEAD)"
if [ "$got_sha" != "$AXIOM_AUDIT_SHA" ]; then
    echo "::error::axiom-audit ${AXIOM_AUDIT_REF} resolved to ${got_sha}, expected ${AXIOM_AUDIT_SHA}"
    exit 1
fi
cp lean-toolchain "$WORKDIR/axiom-audit/"
(
    cd "$WORKDIR/axiom-audit"
    lake build
)

# Run the audit against the project's compiled environment (via `lake env`, so the tool sees the
# project's search path). The tool auto-detects the library root from the lakefile; pass --root
# only when the user overrides it.
audit_args=(--allow "$AXIOM_AUDIT_ALLOW")
if [ -n "${AXIOM_AUDIT_ROOT:-}" ]; then
    audit_args+=(--root "$AXIOM_AUDIT_ROOT")
fi
lake env "$WORKDIR/axiom-audit/.lake/build/bin/axiom-audit" "${audit_args[@]}"

echo "axiom-audit completed successfully"
