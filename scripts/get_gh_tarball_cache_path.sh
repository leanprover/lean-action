#!/usr/bin/env bash
set -e

PROJECT_NAME=$(jq -r .name lake-manifest.json)

TARBALL_FILE="$PROJECT_NAME-x86_64-unknown-linux-gnu.tar.gz"
echo "Tarball file name: $TARBALL_FILE"

echo "tarball-file=$TARBALL_FILE" >> $GITHUB_OUTPUT
