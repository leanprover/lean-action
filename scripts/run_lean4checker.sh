#!/bin/bash
set -e

echo "Checking environment with lean4checker"


# clone lean4checker
echo "Cloning and building lean4checker"
git clone https://github.com/leanprover/lean4checker

# build and test lean4checker in a subshell
(
toolchain_version=$(< lean-toolchain cut -d: -f 2)
echo "Detected toolchain version: $toolchain_version"
cd lean4checker || exit
git config --global advice.detachedHead false # turn off git warning about detached head
git checkout "$toolchain_version"
cp ../lean-toolchain .

# build lean4checker and test lean4checker
lake build
./test.sh
)

# run lean4checker
echo "Running lean4checker"
lake env lean4checker/.lake/build/bin/lean4checker
