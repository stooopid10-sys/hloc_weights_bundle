#!/bin/bash
# reassemble_netvlad.sh
#
# Reassembles VGG16-NetVLAD-Pitts30K.mat (528 MB) from the split parts.
# The file was split into ~90 MB chunks to fit under GitHub's 100 MB file size limit.
#
# INSTALL.sh does this automatically. Run this script manually only if you
# need the reassembled .mat file for something else.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NETVLAD_DIR="$SCRIPT_DIR/model_cache/torch/hub/netvlad"
OUTPUT_FILE="$NETVLAD_DIR/VGG16-NetVLAD-Pitts30K.mat"

if [ -f "$OUTPUT_FILE" ]; then
    echo "Already reassembled: $OUTPUT_FILE ($(du -h "$OUTPUT_FILE" | cut -f1))"
    exit 0
fi

if ! ls "$NETVLAD_DIR"/VGG16-NetVLAD-Pitts30K.mat.part_* 1> /dev/null 2>&1; then
    echo "ERROR: No part files found in $NETVLAD_DIR"
    exit 1
fi

echo "Reassembling NetVLAD weights from chunks..."
cat "$NETVLAD_DIR"/VGG16-NetVLAD-Pitts30K.mat.part_* > "$OUTPUT_FILE"

echo "Done: $OUTPUT_FILE ($(du -h "$OUTPUT_FILE" | cut -f1))"

# Verify checksum (matches the original file from ETH Zurich)
EXPECTED_SHA256="a67d9d897d3b7942f206478e3a22a4c4c9653172ae2447041d35f6cb278fdc67"
if command -v sha256sum &> /dev/null; then
    ACTUAL=$(sha256sum "$OUTPUT_FILE" | awk '{print $1}')
    if [ "$ACTUAL" = "$EXPECTED_SHA256" ]; then
        echo "Checksum OK: $ACTUAL"
    else
        echo "WARNING: checksum mismatch"
        echo "  Expected: $EXPECTED_SHA256"
        echo "  Got:      $ACTUAL"
        exit 1
    fi
fi
