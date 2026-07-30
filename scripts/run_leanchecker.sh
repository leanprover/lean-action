#!/bin/bash
set -euo pipefail

echo "::group::leanchecker Output"
echo "Checking environment with leanchecker"

if [ "${LEAN4CHECKER_INPUT:-false}" = "true" ] && [ "${LEANCHECKER_INPUT:-false}" != "true" ]; then
  echo "::warning::\`lean4checker\` is deprecated; use \`leanchecker\` instead."
fi

leanchecker_path="$(elan which leanchecker 2>/dev/null || true)"
if [ -n "$leanchecker_path" ] && [ -x "$leanchecker_path" ]; then
  echo "Using bundled leanchecker from the active Lean toolchain"
  lake env leanchecker
  echo "::endgroup::"
  echo
  exit 0
fi

echo "Bundled leanchecker is unavailable for this toolchain; falling back to external lean4checker"

echo "Cloning and building lean4checker"
git clone https://github.com/leanprover/lean4checker

(
toolchain_version=$(< lean-toolchain cut -d: -f 2)
echo "Detected toolchain version: $toolchain_version"

cd lean4checker || exit
git config advice.detachedHead false
git checkout "$toolchain_version"
cp ../lean-toolchain .

lake build
if [ -f ./test.sh ]; then
  ./test.sh
else
  lake test
fi
)

echo "Running external lean4checker"
lake env lean4checker/.lake/build/bin/lean4checker

echo "::endgroup::"
echo
