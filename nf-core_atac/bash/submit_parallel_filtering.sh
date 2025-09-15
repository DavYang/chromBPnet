#!/bin/bash

#
# Submission script for parallel BAM filtering and merging
# This script discovers samples and submits a SLURM array job
#

set -e

# --- Usage ---
if [ "$#" -ne 2 ]; then
    echo "Submit parallel BAM filtering and merging job"
    echo "Usage: $0 <input_dir> <output_dir>"
    echo ""
    echo "This script will:"
    echo "  1. Discover all unique samples in the input directory"
    echo "  2. Submit a SLURM array job to process samples in parallel"
    echo "  3. Each sample's replicates will be filtered and merged"
    exit 1
fi

# --- Arguments ---
IN_DIR=$1
OUT_DIR=$2

# --- Validation ---
if [ ! -d "${IN_DIR}" ]; then
    echo "Error: Input directory not found: ${IN_DIR}"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "${OUT_DIR}"

# Create logs directory
mkdir -p "${OUT_DIR}/logs"

echo "Input directory: ${IN_DIR}"
echo "Output directory: ${OUT_DIR}"

# --- Sample Discovery ---
# Find all unique sample prefixes (before _REP[0-9])
SAMPLE_LIST_FILE=$(mktemp)
find "${IN_DIR}" -maxdepth 1 -name "*.bam" -exec basename {} \; | \
    sed -E 's/_REP[0-9].*//' | sort -u > "${SAMPLE_LIST_FILE}"

NUM_SAMPLES=$(wc -l < "${SAMPLE_LIST_FILE}")

if [ ${NUM_SAMPLES} -eq 0 ]; then
    echo "Error: No BAM files found in ${IN_DIR}"
    rm -f "${SAMPLE_LIST_FILE}"
    exit 1
fi

echo "Found ${NUM_SAMPLES} unique samples to process:"
cat "${SAMPLE_LIST_FILE}" | nl

# --- Submit Array Job ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILTER_SCRIPT="${SCRIPT_DIR}/filter_bwa_bams_parallel.sh"

if [ ! -f "${FILTER_SCRIPT}" ]; then
    echo "Error: Filter script not found: ${FILTER_SCRIPT}"
    rm -f "${SAMPLE_LIST_FILE}"
    exit 1
fi

echo ""
echo "Submitting SLURM array job for ${NUM_SAMPLES} samples..."

# Submit the array job
JOB_ID=$(sbatch --array=1-${NUM_SAMPLES} \
    --job-name=filter_bwa_bams_parallel \
    --output="${OUT_DIR}/logs/filter_bwa_bams_parallel_%A_%a.out" \
    --error="${OUT_DIR}/logs/filter_bwa_bams_parallel_%A_%a.err" \
    --time=4-00:00:00 \
    --partition=unlimited \
    --mem=32G \
    --nodes=1 \
    --ntasks=1 \
    --cpus-per-task=4 \
    "${FILTER_SCRIPT}" "${IN_DIR}" "${OUT_DIR}" | awk '{print $4}')

echo "Array job submitted with ID: ${JOB_ID}"
echo "Monitor with: squeue -j ${JOB_ID}"
echo "Check logs in: ${OUT_DIR}/logs/"

# Save sample list for reference
cp "${SAMPLE_LIST_FILE}" "${OUT_DIR}/sample_list.txt"
rm -f "${SAMPLE_LIST_FILE}"

echo "Sample list saved to: ${OUT_DIR}/sample_list.txt"
echo ""
echo "Job submission complete!"
