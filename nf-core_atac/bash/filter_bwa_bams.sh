#!/bin/bash
#SBATCH --job-name=filter_bwa_bams
#SBATCH --output=logs/filter_bwa_bams_%A.out
#SBATCH --error=logs/filter_bwa_bams_%A.err
#SBATCH --time=2-00:00:00
#SBATCH --partition=unlimited
#SBATCH --mem=16G
#SBATCH --nodes=1
#SBATCH --ntasks=1


source /gs/gsfs0/hpc01/rhel8/apps/conda3/etc/profile.d/conda.sh
module load samtools

set -e

# Ensure temporary files are cleaned up on script exit or interruption
trap 'rm -f "${TEMP_BAM}" "${HEADER_FILE}"' EXIT INT TERM

#
# A script to filter BAM files in a directory, keeping only reads mapped to
# autosomal chromosomes (chr1-22) and updating the header accordingly.
#

# --- Usage ---
# Provides a usage message if the number of arguments is incorrect.
if [ "$#" -ne 2 ]; then
    echo "Filters and re-headers all BAM files in a directory to retain only alignments to autosomal chromosomes (e.g., chr1-22)."
    echo "Usage: $0 <input_dir> <output_dir>"
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

# --- Main ---
# Find and process all BAM files in the input directory.
for IN_BAM in "${IN_DIR}"/*.bam; do
    # Check if the glob found any files
    if [ ! -f "${IN_BAM}" ]; then
        echo "Warning: No .bam files found in ${IN_DIR}. Exiting."
        exit 0
    fi

    OUT_BAM="${OUT_DIR}/$(basename "${IN_BAM}")"
    echo "---"
    echo "Processing: $(basename "${IN_BAM}")"
    echo "Outputting to: ${OUT_BAM}"
    
    # Extract chromosome names from the BAM header and filter for autosomes.
    AUTOSOMES=$(samtools view -H "${IN_BAM}" | grep '^@SQ' | cut -f 2 | sed 's/SN://' | grep -E '^chr([1-9]|1[0-9]|2[0-2])$' | tr '\n' ' ')

    if [ -z "${AUTOSOMES}" ]; then
        echo "Error: No autosomal chromosomes with 'chr' prefix found in the BAM header for $(basename "${IN_BAM}"). Skipping this file."
        continue
    fi

    # Create temporary files that will be cleaned up on exit by the trap
    TEMP_BAM=$(mktemp --suffix .bam)
    HEADER_FILE=$(mktemp)

    echo "Generating filtered header..."
    # 1. Create a new header containing only autosomal chromosomes.
    # Keep all original header lines (like @HD, @PG) except the sequence dictionary (@SQ).
    samtools view -H "${IN_BAM}" | grep -v '^@SQ' > "${HEADER_FILE}"
    # Add back only the @SQ lines for the autosomes. The '\b' ensures we match 'chr1' but not 'chr1_random'.
    samtools view -H "${IN_BAM}" | grep '^@SQ' | grep -E "SN:(chr([1-9]|1[0-9]|2[0-2]))\b" >> "${HEADER_FILE}"

    echo "Filtering alignments and sorting..."
    # 2. Filter the original BAM for autosomal reads and sort into a temporary file.
    samtools view -b "${IN_BAM}" ${AUTOSOMES} | samtools sort -o "${TEMP_BAM}" -

    echo "Re-headering the BAM file..."
    # 3. Combine the new header with the filtered alignments.
    samtools reheader "${HEADER_FILE}" "${TEMP_BAM}" > "${OUT_BAM}"

    echo "Indexing the re-headered BAM file..."
    # 4. Index the final, clean BAM file.
    samtools index "${OUT_BAM}"
    echo "Done processing $(basename "${IN_BAM}")."
done

echo "---"
echo "All BAM files have been processed."

# --- Merge Replicates ---
MERGE_DIR="${OUT_DIR}/merged_replicates"
mkdir -p "${MERGE_DIR}"
echo "---"
echo "Merging replicates..."
echo "Output directory for merged files: ${MERGE_DIR}"

# Find unique sample prefixes to identify replicates for merging.
# This extracts the sample name part before "_REP[0-9]".
PREFIXES=$(find "${OUT_DIR}" -maxdepth 1 -name "*.bam" -exec basename {} \; | sed -E 's/_REP[0-9].*//' | sort -u)

for prefix in ${PREFIXES}; do
    # Find all BAM files for the current prefix in the primary output directory
    REPLICATE_BAMS=($(find "${OUT_DIR}" -maxdepth 1 -name "${prefix}_REP*.bam"))
    NUM_REPLICATES=${#REPLICATE_BAMS[@]}

    # Define a clean output name, replacing the replicate number with 'merged'
    MERGED_BAM_NAME=$(basename "${REPLICATE_BAMS[0]}" | sed -E "s/_REP[0-9]/_merged/")
    MERGED_BAM_PATH="${MERGE_DIR}/${MERGED_BAM_NAME}"

    echo "Found ${NUM_REPLICATES} replicate(s) for prefix: ${prefix}"

    if [ ${NUM_REPLICATES} -gt 1 ]; then
        echo "Merging ${NUM_REPLICATES} replicates into ${MERGED_BAM_PATH}"
        samtools merge -f "${MERGED_BAM_PATH}" "${REPLICATE_BAMS[@]}"
    elif [ ${NUM_REPLICATES} -eq 1 ]; then
        echo "Only one replicate found. Copying to merged directory."
        cp "${REPLICATE_BAMS[0]}" "${MERGED_BAM_PATH}"
    else
        echo "Warning: No valid replicates found for prefix '${prefix}'. Skipping."
        continue
    fi

    echo "Indexing merged BAM file: ${MERGED_BAM_PATH}"
    samtools index "${MERGED_BAM_PATH}"
done

echo "---"
echo "Merging complete."
echo "---"
echo "Generating read count summary..."

SUMMARY_FILE="${OUT_DIR}/read_summary.txt"
echo "Read Summary for Autosome-Filtered BAMs" > "${SUMMARY_FILE}"
echo "Generated on $(date)" >> "${SUMMARY_FILE}"
echo "" >> "${SUMMARY_FILE}"

# Section for individual filtered BAMs
echo "--- Individual Filtered Replicates ---" >> "${SUMMARY_FILE}"
echo "======================================" >> "${SUMMARY_FILE}"

for BAM_FILE in "${OUT_DIR}"/*.bam; do
    if [ -f "${BAM_FILE}" ]; then
        FILENAME=$(basename "${BAM_FILE}")
        READ_COUNT=$(samtools view -c "${BAM_FILE}")
        printf "%-55s %'d reads\n" "${FILENAME}:" "${READ_COUNT}" >> "${SUMMARY_FILE}"
    fi
done

echo "" >> "${SUMMARY_FILE}"

# Section for merged BAMs
echo "--- Merged Replicates ---" >> "${SUMMARY_FILE}"
echo "=========================" >> "${SUMMARY_FILE}"

for BAM_FILE in "${MERGE_DIR}"/*.bam; do
    if [ -f "${BAM_FILE}" ]; then
        FILENAME=$(basename "${BAM_FILE}")
        READ_COUNT=$(samtools view -c "${BAM_FILE}")
        printf "%-55s %'d reads\n" "${FILENAME}:" "${READ_COUNT}" >> "${SUMMARY_FILE}"
    fi
done

echo "Read summary saved to: ${SUMMARY_FILE}"
echo "Script finished."

