echo "Trying to detect if project is downstream of Mathlib."

# Check if the lakefile.lean file contains "require mathlib"
if grep -q "require mathlib" lakefile.lean; then
  echo "DETECTED_MATHLIB=true" >> "$GITHUB_OUTPUT"
  echo "Project is downstream of Mathlib. Using Mathlib cache."
else
  echo "Project is not downstream of Mathlib. Skipping Mathlib cache."
fi