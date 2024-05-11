#!/bin/bash

echo "Trying to detect if project is downstream of Mathlib."

# define mathlib dependency patterns for lakefile.lean and lakefile.toml
dot_lean_pattern="require mathlib"
dot_toml_pattern="git = \"https://github.com/leanprover-community/mathlib4\""

# Check if the lakefile.lean file contains "require mathlib"
if grep -q "$dot_lean_pattern" lakefile.lean || grep -q "$dot_toml_pattern" lakefile.toml; then
  echo "DETECTED_MATHLIB=true" >> "$GITHUB_OUTPUT"
  echo "Project is downstream of Mathlib. Using Mathlib cache."
else
  echo "Project is not downstream of Mathlib. Skipping Mathlib cache."
fi