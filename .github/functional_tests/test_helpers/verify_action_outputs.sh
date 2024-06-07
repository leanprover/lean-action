#!/bin/bash
if [ "$ACTUAL_VALUE" != "$EXPECTED_VALUE" ]; then
    echo "Unexpected value for output $OUTPUT_NAME: $ACTUAL_VALUE (expected: $EXPECTED_VALUE)"
    exit 1
fi
echo "Output $OUTPUT_NAME = $EXPECTED_VALUE verified"
