#!/bin/bash

# Group logging using the ::group:: workflow command
echo "::group::Elan Installation Output"

set -o pipefail
curl -sSfL https://github.com/leanprover/elan/releases/download/v3.1.1/elan-x86_64-unknown-linux-gnu.tar.gz | tar xz
./elan-init -y --default-toolchain none
rm -f elan-init

echo "$HOME/.elan/bin" >> "$GITHUB_PATH"
"$HOME"/.elan/bin/lean --version          
"$HOME"/.elan/bin/lake --version

echo "::endgroup::"
echo
