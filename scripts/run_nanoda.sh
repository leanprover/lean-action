#!/usr/bin/env bash
set -e

# Group logging using the ::group:: workflow command
echo "::group::nanoda Output"
echo "Checking environment with nanoda external type checker"

echo "::warning::\`nanoda\` is deprecated; use \`lake-check: paranoid\` instead, which runs nanoda together with every other checker bundled with the toolchain. It has no equivalent of \`nanoda-allow-sorry: true\`, because \`lake check\` permits only the standard axioms, so projects that carry a \`sorry\` should stay on this input for now."

# handle_exit function to capture exit status and cleanup
handle_exit() {
    exit_status=$?

    # Close the log group before cleanup
    echo "::endgroup::"

    # Always cleanup temporary files/directories
    echo "Cleaning up temporary files..."
    rm -rf _lean4export _nanoda_lib _nanoda_export.txt _nanoda_config.json

    if [ $exit_status -ne 0 ]; then
        echo "nanoda-status=FAILURE" >> "$GITHUB_OUTPUT"
        echo "::error::nanoda check failed"
    else
        echo "nanoda-status=SUCCESS" >> "$GITHUB_OUTPUT"
        echo
    fi
}
trap handle_exit EXIT

# Check for conflicting directories before we start
if [ -d "_lean4export" ] || [ -d "_nanoda_lib" ]; then
    echo "::error::Directories _lean4export or _nanoda_lib already exist. Please remove them before running nanoda."
    exit 1
fi

# Recent release toolchains ship both the exporter and nanoda, matched to each other and to the
# compiler that produced the oleans. When they are there, use them: cloning and building
# `lean4export` and `nanoda_lib` costs a Rust toolchain and two source builds on every run, and
# pins `nanoda_lib` to a branch rather than a release.
BUNDLED_EXPORTER="$(elan which leanexport 2>/dev/null || true)"
BUNDLED_NANODA="$(elan which nanoda_bin 2>/dev/null || true)"

if [ -n "$BUNDLED_EXPORTER" ] && [ -x "$BUNDLED_EXPORTER" ] \
    && [ -n "$BUNDLED_NANODA" ] && [ -x "$BUNDLED_NANODA" ]; then
    echo "Using the leanexport and nanoda_bin bundled with this toolchain"
    EXPORTER="$BUNDLED_EXPORTER"
    NANODA="$BUNDLED_NANODA"
else
    echo "This toolchain bundles no nanoda; building it and lean4export from source"

    # Step 1: Install Rust if not present
    echo "Checking for Rust installation..."
    if ! command -v cargo &> /dev/null; then
        echo "Installing Rust toolchain..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal
        # shellcheck source=/dev/null
        source "$HOME/.cargo/env"
    else
        echo "Rust already installed: $(cargo --version)"
    fi

    # Step 2: Clone and build lean4export
    echo "Cloning and building lean4export..."
    git clone --depth 1 https://github.com/leanprover/lean4export.git _lean4export

    # Copy lean-toolchain to lean4export so it uses matching Lean version
    cp lean-toolchain _lean4export/

    (
        cd _lean4export
        lake build
    )

    # Step 3: Clone and build nanoda_lib
    echo "Cloning and building nanoda_lib..."
    # Using debug branch which has fixes for recent Lean kernel changes
    git clone --depth 1 --branch debug https://github.com/ammkrn/nanoda_lib.git _nanoda_lib

    (
        cd _nanoda_lib
        cargo build --release
    )

    EXPORTER="_lean4export/.lake/build/bin/lean4export"
    NANODA="_nanoda_lib/target/release/nanoda_bin"
fi

# Step 4: Detect module name from lakefile
echo "Detecting module name..."
MODULE_NAME=""

# Try lakefile.toml first. Prefer `defaultTargets`, then the first `lean_lib`: those name the
# module to export, where the package name need not be a module at all. `lake init foo lib` on a
# current toolchain writes `name = "foo"` at the top level with no `[package]` section and a
# library called `Foo`, so looking only for a package name finds nothing to export.
if [ -f "lakefile.toml" ]; then
    MODULE_NAME=$(grep -m1 '^defaultTargets' lakefile.toml | sed -n 's/.*\[[^"]*"\([^"]*\)".*/\1/p' || true)

    if [ -z "$MODULE_NAME" ]; then
        MODULE_NAME=$(grep -A3 '^\[\[lean_lib\]\]' lakefile.toml | grep -m1 '^name' | sed 's/.*= *"\([^"]*\)".*/\1/' || true)
    fi

    # Older lakefiles put the package name in a `[package]` section.
    if [ -z "$MODULE_NAME" ]; then
        MODULE_NAME=$(grep -A5 '^\[package\]' lakefile.toml | grep '^name' | head -1 | sed 's/.*= *"\([^"]*\)".*/\1/' || true)
    fi
fi

# Fallback to lakefile.lean
if [ -z "$MODULE_NAME" ] && [ -f "lakefile.lean" ]; then
    # Try to extract from 'package' declaration (allowing leading whitespace)
    MODULE_NAME=$(grep -E "^\s*package\s+" lakefile.lean | head -1 | awk '{print $2}' || true)
fi

if [ -z "$MODULE_NAME" ]; then
    echo "::error::Could not detect module name from lakefile.toml or lakefile.lean"
    exit 1
fi

echo "Detected module name: $MODULE_NAME"

# Step 5: Export the project
echo "Exporting $MODULE_NAME..."
EXPORT_FILE="_nanoda_export.txt"
lake env "$EXPORTER" "$MODULE_NAME" > "$EXPORT_FILE"

echo "Export file size: $(wc -c < "$EXPORT_FILE") bytes"
echo "Export file lines: $(wc -l < "$EXPORT_FILE") lines"

# Step 6: Create nanoda config
echo "Creating nanoda configuration..."
CONFIG_FILE="_nanoda_config.json"

# Build permitted_axioms array
PERMITTED_AXIOMS='["propext", "Classical.choice", "Quot.sound", "Lean.trustCompiler"'
if [ "$NANODA_ALLOW_SORRY" = "true" ]; then
    PERMITTED_AXIOMS="$PERMITTED_AXIOMS, \"sorryAx\""
    echo "Note: sorryAx axiom is permitted"
fi
PERMITTED_AXIOMS="$PERMITTED_AXIOMS]"

cat > "$CONFIG_FILE" << EOF
{
    "export_file_path": "$EXPORT_FILE",
    "use_stdin": false,
    "permitted_axioms": $PERMITTED_AXIOMS,
    "unpermitted_axiom_hard_error": false,
    "nat_extension": true,
    "string_extension": true,
    "print_success_message": true
}
EOF

echo "Config file contents:"
cat "$CONFIG_FILE"

# Step 7: Run nanoda
echo ""
echo "Running nanoda type checker..."
"$NANODA" "$CONFIG_FILE"

echo "nanoda check completed successfully"
