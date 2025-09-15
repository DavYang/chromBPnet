#!/bin/bash
#SBATCH --job-name=filter_bwa_bams_parallel
#SBATCH --output=logs/filter_bwa_bams_parallel_%A_%a.out
#SBATCH --error=logs/filter_bwa_bams_parallel_%A_%a.err
#SBATCH --time=4-00:00:00
#SBATCH --partition=unlimited
#SBATCH --mem=32G
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4

source /gs/gsfs0/hpc01/rhel8/apps/conda3/etc/profile.d/conda.sh
module load samtools

set -e

# Ensure temporary files are cleaned up on script exit or interruption
trap 'rm -f "${TEMP_BAM}" "${HEADER_FILE}" "${SAMPLE_LIST_FILE}"' EXIT INT TERM

#
# A parallelized script to filter BAM files by sample, keeping only reads mapped to
# autosomal chromosomes (chr1-22).
#

# --- Usage ---
# Provides a usage message if the number of arguments is incorrect.
if [ "$#" -ne 2 ]; then
    echo "Parallel filtering of BAM files by sample, retaining only alignments to autosomal chromosomes (e.g., chr1-22)."
    echo "Usage: $0 <input_dir> <output_dir>"
    echo ""
    echo "Arguments:"
    echo "  input_dir: Directory containing input BAM files"
    echo "  output_dir: Directory for output files"
    echo ""
    echo "This script processes samples in parallel using SLURM array jobs."
    echo "Each sample's replicates are filtered and saved to individual output files."
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
    exit 1
fi

echo "Found ${NUM_SAMPLES} unique samples to process"

# --- Array Job Logic ---
if [ -z "${SLURM_ARRAY_TASK_ID}" ]; then
    echo "Error: This script must be run as a SLURM array job"
    echo "Submit with: sbatch --array=1-${NUM_SAMPLES} $0 <input_dir> <output_dir>"
    exit 1
fi

# Get the sample for this array task
SAMPLE_PREFIX=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${SAMPLE_LIST_FILE}")
echo "Processing sample: ${SAMPLE_PREFIX} (task ${SLURM_ARRAY_TASK_ID}/${NUM_SAMPLES})"

# --- Sample Processing ---
# Find all BAM files for this sample
SAMPLE_BAMS=($(find "${IN_DIR}" -maxdepth 1 -name "${SAMPLE_PREFIX}_REP*.bam"))
NUM_REPLICATES=${#SAMPLE_BAMS[@]}

if [ ${NUM_REPLICATES} -eq 0 ]; then
    echo "Warning: No BAM files found for sample ${SAMPLE_PREFIX}. Skipping."
    exit 0
fi

echo "Found ${NUM_REPLICATES} replicate(s) for sample ${SAMPLE_PREFIX}"

# Create sample-specific output directory
SAMPLE_OUT_DIR="${OUT_DIR}/${SAMPLE_PREFIX}"
mkdir -p "${SAMPLE_OUT_DIR}"

# --- Filter Individual Replicates ---
echo "Filtering individual replicates for sample ${SAMPLE_PREFIX}..."

for IN_BAM in "${SAMPLE_BAMS[@]}"; do
    REP_NAME=$(basename "${IN_BAM}")
    OUT_BAM="${SAMPLE_OUT_DIR}/${REP_NAME}"
    
    echo "Processing replicate: ${REP_NAME}"
    
    # Extract chromosome names from the BAM header and filter for autosomes
    AUTOSOMES=$(samtools view -H "${IN_BAM}" | grep '^@SQ' | cut -f 2 | sed 's/SN://' | grep -E '^chr([1-9]|1[0-9]|2[0-2])$' | tr '\n' ' ')

    if [ -z "${AUTOSOMES}" ]; then
        echo "Error: No autosomal chromosomes with 'chr' prefix found in the BAM header for ${REP_NAME}. Skipping this file."
        continue
    fi

    # Create temporary files that will be cleaned up on exit by the trap
    TEMP_BAM=$(mktemp --suffix .bam)
    HEADER_FILE=$(mktemp)

    echo "Generating filtered header for ${REP_NAME}..."
    # 1. Create a new header containing only autosomal chromosomes
    samtools view -H "${IN_BAM}" | grep -v '^@SQ' > "${HEADER_FILE}"
    # Add back only the @SQ lines for the autosomes
    samtools view -H "${IN_BAM}" | grep '^@SQ' | grep -E "SN:(chr([1-9]|1[0-9]|2[0-2]))\b" >> "${HEADER_FILE}"

    echo "Filtering alignments and sorting for ${REP_NAME}..."
    # 2. Filter the original BAM for autosomal reads and sort into a temporary file
    samtools view -b "${IN_BAM}" ${AUTOSOMES} | samtools sort -o "${TEMP_BAM}" -

    echo "Re-headering the BAM file for ${REP_NAME}..."
    # 3. Combine the new header with the filtered alignments
    samtools reheader "${HEADER_FILE}" "${TEMP_BAM}" > "${OUT_BAM}"

    echo "Indexing the re-headered BAM file for ${REP_NAME}..."
    # 4. Index the final, clean BAM file
    samtools index "${OUT_BAM}"
    
    echo "Completed processing ${REP_NAME}"
done

# --- Generate Sample Summary ---
SAMPLE_SUMMARY="${SAMPLE_OUT_DIR}/read_summary.txt"
echo "Read Summary for Sample: ${SAMPLE_PREFIX}" > "${SAMPLE_SUMMARY}"
echo "Generated on $(date)" >> "${SAMPLE_SUMMARY}"
echo "" >> "${SAMPLE_SUMMARY}"

# Section for individual filtered replicates
echo "--- Individual Filtered Replicates ---" >> "${SAMPLE_SUMMARY}"
echo "======================================" >> "${SAMPLE_SUMMARY}"

# Find all filtered BAM files for this sample
FILTERED_BAMS=($(find "${SAMPLE_OUT_DIR}" -maxdepth 1 -name "*.bam"))

for BAM_FILE in "${FILTERED_BAMS[@]}"; do
    if [ -f "${BAM_FILE}" ]; then
        FILENAME=$(basename "${BAM_FILE}")
        READ_COUNT=$(samtools view -c "${BAM_FILE}")
        printf "%-55s %'d reads\n" "${FILENAME}:" "${READ_COUNT}" >> "${SAMPLE_SUMMARY}"
    fi
done

echo "Sample summary saved to: ${SAMPLE_SUMMARY}"
echo "Completed processing sample: ${SAMPLE_PREFIX}"
