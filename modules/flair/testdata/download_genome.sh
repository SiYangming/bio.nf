#!/bin/bash
set -e

# Script to prepare genome.fa for flair align online testing
# Based on BrooksLabUCSC/flair/test/Makefile

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUTPUT_FILE="${SCRIPT_DIR}/genome.fa"

if [ -f "$OUTPUT_FILE" ]; then
    echo "Genome file $OUTPUT_FILE already exists. Skipping download."
    exit 0
fi

echo "Downloading chromosomes..."
# Use curl instead of wget for better macOS compatibility by default, or keep wget if standard in env. 
# The user environment has wget (based on previous logs). Sticking to wget but adding -O might be safer, but -nv is fine.
# We will execute these commands in the script dir to avoid cluttering PWD
cd "$SCRIPT_DIR"

wget -nv https://hgdownload.soe.ucsc.edu/goldenPath/hg38/chromosomes/chr12.fa.gz
wget -nv https://hgdownload.soe.ucsc.edu/goldenPath/hg38/chromosomes/chr17.fa.gz
wget -nv https://hgdownload.soe.ucsc.edu/goldenPath/hg38/chromosomes/chr20.fa.gz

echo "Concatenating chromosomes to $OUTPUT_FILE..."
# Use gunzip -c instead of zcat for macOS compatibility
gunzip -c chr12.fa.gz chr17.fa.gz chr20.fa.gz > "$OUTPUT_FILE"

echo "Cleaning up temporary files..."
rm chr12.fa.gz chr17.fa.gz chr20.fa.gz

echo "Indexing genome..."
samtools faidx "$OUTPUT_FILE"

echo "Done. Created $OUTPUT_FILE and $OUTPUT_FILE.fai"
