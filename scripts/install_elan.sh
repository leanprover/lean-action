#!/usr/bin/env bash
set -e

# Group logging using the ::group:: workflow command
echo "::group::Elan Installation Output"

set -o pipefail
# `--no-modify-path` because this script puts `$HOME/.elan/bin` on `$GITHUB_PATH`
# itself, two lines below. Without the flag elan additionally edits the user's
# persistent environment -- `HKCU\Environment\PATH` on Windows, `~/.profile` and
# friends elsewhere -- which is redundant on GitHub-hosted runners and outlives
# the job on self-hosted ones.
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf |
  sh -s -- -y --default-toolchain none --no-modify-path
rm -f elan-init

echo "$HOME/.elan/bin" >>"$GITHUB_PATH"
"$HOME"/.elan/bin/lean --version
"$HOME"/.elan/bin/lake --version

echo "::endgroup::"
echo
