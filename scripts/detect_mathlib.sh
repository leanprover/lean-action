#!/bin/bash

# Group logging using the ::group:: workflow command
echo "::group::Detect Mathlib Output"
echo "Trying to detect if project is downstream of Mathlib."

mathlib_repo_url="https://github.com/leanprover-community/mathlib4"
# Check if lake-manifest.json contain the mathlib dependency pattern
if [ -f lake-manifest.json ] && grep -q "$mathlib_repo_url" lake-manifest.json; then
  # Set the detected-mathlib variable to true and send it to the GitHub action output to be used in later steps
  echo "detected-mathlib=true" >>"$GITHUB_OUTPUT"
  echo "Detected Mathlib dependency in lake-manifest.json. Using Mathlib cache."
else
  echo "detected-mathlib=false" >>"$GITHUB_OUTPUT"
  echo "Project is not downstream of Mathlib. Skipping Mathlib cache."
fi

echo "::endgroup::"
echo
