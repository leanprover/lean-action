#!/bin/bash

# Group logging using the ::group:: workflow command
echo "::group::Mathlib Detection"
echo "Trying to detect if project is downstream of Mathlib."

# define mathlib dependency patterns for lakefile.lean and lakefile.toml
dot_lean_pattern="require mathlib"
dot_toml_pattern="\[\[require\]\]\nname = \"mathlib\"\ngit = \"https://github.com/leanprover-community/mathlib4"

# Check if lakefile.lean or lakefile.toml contain the mathlib dependency pattern
if grep -q "$dot_lean_pattern" lakefile.lean || grep -Pzq "$dot_toml_pattern" lakefile.toml; then
  # Set the DETECTED_MATHLIB variable to true and send it to the GitHub action output to be used in later steps
  echo "DETECTED_MATHLIB=true" >> "$GITHUB_OUTPUT"
  echo "Project is downstream of Mathlib. Using Mathlib cache."
else
  echo "Project is not downstream of Mathlib. Skipping Mathlib cache."
fi

echo "::endgroup::"
