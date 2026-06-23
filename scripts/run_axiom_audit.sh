#!/bin/bash
set -e

# Group logging using the ::group:: workflow command
echo "::group::axiom-audit Output"
echo "Auditing axioms with leanprover-community/axiom-audit"

# Pin the tool to a released tag so the action is reproducible.
AXIOM_AUDIT_REF="v0.1.0"

# handle_exit function to capture exit status and cleanup
handle_exit() {
    exit_status=$?

    # Close the log group before cleanup
    echo "::endgroup::"

    # Always cleanup temporary files/directories
    echo "Cleaning up temporary files..."
    rm -rf _axiom_audit

    if [ $exit_status -ne 0 ]; then
        echo "axiom-audit-status=FAILURE" >> "$GITHUB_OUTPUT"
        echo "::error::axiom-audit check failed"
    else
        echo "axiom-audit-status=SUCCESS" >> "$GITHUB_OUTPUT"
        echo
    fi
}
trap handle_exit EXIT

# Check for a conflicting directory before we start
if [ -d "_axiom_audit" ]; then
    echo "::error::Directory _axiom_audit already exists. Please remove it before running axiom-audit."
    exit 1
fi

# Step 1: Determine the root namespace to audit. Prefer the explicit override; otherwise use the
# first `lean_lib` name from the lakefile — the library's root namespace, which (unlike the package
# name, e.g. `foo` vs the `Foo` library) is what declarations are actually defined under. Projects
# with multiple libraries or a namespace that differs from the library name should set
# `axiom-audit-root` explicitly.
ROOT="$AXIOM_AUDIT_ROOT"
if [ -z "$ROOT" ]; then
    if [ -f "lakefile.toml" ]; then
        ROOT=$(grep -A3 '^\[\[lean_lib\]\]' lakefile.toml | grep -m1 '^name' | sed 's/.*= *"\([^"]*\)".*/\1/' || true)
    fi
    if [ -z "$ROOT" ] && [ -f "lakefile.lean" ]; then
        ROOT=$(grep -E '^\s*lean_lib\s' lakefile.lean | head -1 | awk '{print $2}' | tr -d '«»' || true)
    fi
fi
if [ -z "$ROOT" ]; then
    echo "::error::Could not determine the library root namespace from the lakefile; set the axiom-audit-root input."
    exit 1
fi
echo "Auditing root namespace: $ROOT"
echo "Allowlist: $AXIOM_AUDIT_ALLOW"

# Step 2: Clone and build axiom-audit with the project's toolchain (so its olean reader matches
# the project's Lean version). The tool is dependency-free, so this is a quick build.
echo "Cloning and building axiom-audit @ $AXIOM_AUDIT_REF..."
git clone --depth 1 --branch "$AXIOM_AUDIT_REF" https://github.com/leanprover-community/axiom-audit.git _axiom_audit
cp lean-toolchain _axiom_audit/
(
    cd _axiom_audit
    lake build
)

# Step 3: Run the audit against the project's own compiled environment (via `lake env`, so the
# tool sees the project's search path). Exits non-zero on a violation, failing the step.
lake env _axiom_audit/.lake/build/bin/axiom-audit --root "$ROOT" --allow "$AXIOM_AUDIT_ALLOW"

echo "axiom-audit completed successfully"
