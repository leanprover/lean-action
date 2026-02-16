#!/usr/bin/env bash
echo "::group::Get GitHub cache tarball path"

if [ -f lake-manifest.json ]; then
  PROJECT_NAME=$(jq -r .name lake-manifest.json)
  TARBALL_FILE="$PROJECT_NAME-x86_64-unknown-linux-gnu.tar.gz"

  echo "Tarball file name: $TARBALL_FILE"
  echo "tarball-file=$TARBALL_FILE" >> $GITHUB_OUTPUT
else
  echo "::error::No lake-manifest.json found. Run lake update to generate manifest"
  echo "::error::Exiting with status 1"
  exit 1
fi
