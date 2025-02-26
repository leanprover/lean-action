#!/bin/bash

# Check if either "lean-toolchain" or "lake-manifest.json" have been modified,
# ignoring white space changes.

if [[ -n $(git diff -w "lean-toolchain") ]] || [[ -n $(git diff -w "lake-manifest.json") ]]; then
    echo "files_changed=true"
else
    echo "files_changed=false"
fi