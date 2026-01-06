#!/bin/bash
set -e

# Group logging using the ::group:: workflow command
echo "::group::nanoda Output"
echo "Checking environment with nanoda external type checker"

# handle_exit function to capture exit status
handle_exit() {
    exit_status=$?
    if [ $exit_status -ne 0 ]; then
        echo "nanoda-status=FAILURE" >> "$GITHUB_OUTPUT"
        echo "::error::nanoda check failed"
    else
        echo "nanoda-status=SUCCESS" >> "$GITHUB_OUTPUT"
        echo "::endgroup::"
        echo
    fi
}
trap handle_exit EXIT

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
# TODO: Once https://github.com/leanprover/lean4export/pull/11 is merged,
# switch to leanprover/lean4export and remove the branch checkout.
git clone --depth 1 --branch fix-nondep-normalization https://github.com/kim-em/lean4export.git _lean4export

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

# Step 4: Detect module name from lakefile
echo "Detecting module name..."
MODULE_NAME=""

# Try lakefile.toml first
if [ -f "lakefile.toml" ]; then
    # Extract name from [package] section
    MODULE_NAME=$(grep -A5 '^\[package\]' lakefile.toml | grep '^name' | head -1 | sed 's/.*= *"\([^"]*\)".*/\1/' || true)
fi

# Fallback to lakefile.lean
if [ -z "$MODULE_NAME" ] && [ -f "lakefile.lean" ]; then
    # Try to extract from 'package' declaration
    MODULE_NAME=$(grep -E "^package\s+" lakefile.lean | head -1 | awk '{print $2}' || true)
fi

if [ -z "$MODULE_NAME" ]; then
    echo "::error::Could not detect module name from lakefile.toml or lakefile.lean"
    exit 1
fi

echo "Detected module name: $MODULE_NAME"

# Step 5: Export the project
echo "Exporting $MODULE_NAME..."
EXPORT_FILE="_nanoda_export.txt"
lake env _lean4export/.lake/build/bin/lean4export "$MODULE_NAME" > "$EXPORT_FILE"

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
_nanoda_lib/target/release/nanoda_bin "$CONFIG_FILE"

# Cleanup temporary files
echo ""
echo "Cleaning up temporary files..."
rm -rf _lean4export _nanoda_lib "$EXPORT_FILE" "$CONFIG_FILE"

echo "nanoda check completed successfully"
