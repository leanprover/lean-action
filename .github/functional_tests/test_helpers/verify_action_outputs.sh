#!/bin/bash

# Expects the following environment variables to be set in the calling job step:
# - OUTPUT_NAME: the name of the output to verify
# - EXPECTED_VALUE: the expected value of the output
# - ACTUAL_VALUE: the actual value of the output
if [ "$ACTUAL_VALUE" != "$EXPECTED_VALUE" ]; then
    echo "Unexpected value for output $OUTPUT_NAME: $ACTUAL_VALUE (expected: $EXPECTED_VALUE)"
    exit 1
fi
echo "Output $OUTPUT_NAME = $EXPECTED_VALUE verified"
