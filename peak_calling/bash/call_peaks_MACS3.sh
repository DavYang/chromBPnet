#!/bin/bash
#SBATCH --job-name=call_peaks_MACS3
#SBATCH --partition=quick
#SBATCH --mem=128G
#SBATCH --time=4:00:00 # Set a reasonable time limit instead of infinite
#SBATCH --output=logs/call_peaks_MACS3_%j.out
#SBATCH --error=logs/call_peaks_MACS3_%j.err

# --- Environment ---
# Activate the conda environment containing MACS3
source /gs/gsfs0/hpc01/rhel8/apps/conda3/etc/profile.d/conda.sh
conda activate macs3

set -e # Exit immediately if a command exits with a non-zero status.

# Ensure temporary files are cleaned up on script exit or interruption
trap 'rm -f "${FILTERED_PEAKS}"' EXIT INT TERM

# --- Usage ---
if [ "$#" -ne 3 ]; then
    echo "Calls peaks, filters, sorts, converts to BED6, and summarizes the results."
    echo "Usage: $0 <input.bam> <base_output_dir> <blacklist.bed>"
    exit 1
fi

# --- Arguments ---
IN_BAM=$1
BASE_OUT_DIR=$2
BLACKLIST_FILE=$3
p_value="0.01"
ext_size="183"

# --- Validation ---
if [ ! -f "${IN_BAM}" ]; then
    echo "Error: Input BAM file not found: ${IN_BAM}"
    exit 1
fi
if [ ! -f "${BLACKLIST_FILE}" ]; then
    echo "Error: Blacklist file not found: ${BLACKLIST_FILE}"
    exit 1
fi

# --- Directory Setup ---
# Derive a clean sample name from the BAM filename
SAMPLE_NAME=$(basename "${IN_BAM}" .bam | sed -E 's/(\.mLb\.clN\.sorted)//')

# Define and create a sample-specific output directory
SAMPLE_OUT_DIR="${BASE_OUT_DIR}/${SAMPLE_NAME}"
mkdir -p "${SAMPLE_OUT_DIR}"

echo "--- Peak Calling Parameters ---"
echo "Input BAM:         ${IN_BAM}"
echo "Output Directory:  ${SAMPLE_OUT_DIR}"
echo "Sample Name:       ${SAMPLE_NAME}"
echo "Blacklist File:    ${BLACKLIST_FILE}"
echo "------------------------------"

# --- 1. Peak Calling with MACS3 ---
echo "Step 1: Calling peaks with MACS3..."
macs3 callpeak \
    -t "${IN_BAM}" \
    -f BAMPE \
    -g hs \
    --outdir "${SAMPLE_OUT_DIR}" \
    -n "${SAMPLE_NAME}" \
    -B \
    --nomodel \
    -p ${p_value} \
    --call-summits \
    --extsize ${ext_size}

echo "MACS3 peak calling complete for ${SAMPLE_NAME}."

# --- 2. Blacklist Filtering ---
RAW_PEAKS="${SAMPLE_OUT_DIR}/${SAMPLE_NAME}_peaks.narrowPeak"
# The temporary file with filtered peaks (but not yet sorted)
FILTERED_PEAKS="${SAMPLE_OUT_DIR}/${SAMPLE_NAME}_peaks.filtered.narrowPeak"
FINAL_BED="${SAMPLE_OUT_DIR}/${SAMPLE_NAME}_peaks.final.bed"

if [ ! -f "${RAW_PEAKS}" ]; then
    echo "Error: MACS3 output peak file not found: ${RAW_PEAKS}"
    exit 1
fi

echo "Step 2: Filtering peaks against blacklist..."
conda deactivate
conda activate bedtools
bedtools subtract -A -a "${RAW_PEAKS}" -b "${BLACKLIST_FILE}" > "${FILTERED_PEAKS}"

# --- Step 4: Sort Final Peaks ---
echo "Step 4: Sorting final peaks..."
# The final, sorted, clean narrowPeak file
FINAL_PEAK_FILE="${SAMPLE_OUT_DIR}/${SAMPLE_NAME}_peaks.final.narrowPeak"
sort -k1,1V -k2,2n "${FILTERED_PEAKS}" > "${FINAL_PEAK_FILE}"

# --- Step 5: Final Summary ---
echo "---"
echo "Step 5: Generating final summary..."
# Count peaks at each stage
total_peaks=$(wc -l < "${RAW_PEAKS}")
filtered_total=$(wc -l < "${FILTERED_PEAKS}")
removed=$((total_peaks - filtered_total))

echo "Summary for ${SAMPLE_NAME}:"
echo " -> Initial peaks called: ${total_peaks}"
echo " -> Peaks after blacklist filtering: ${filtered_total} (${removed} removed)"
echo "---"
echo "Analysis complete."
echo "Final sorted peak file: ${FINAL_PEAK_FILE}"

