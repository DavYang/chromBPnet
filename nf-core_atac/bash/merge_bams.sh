#!/bin/bash
#SBATCH --job-name=merge_pbmc_bams
#SBATCH --output=logs/merge_pbmc_bams_%j.out
#SBATCH --error=logs/merge_pbmc_bams_%j.err
#SBATCH --time=12-00:00:00
#SBATCH --partition=unlimited
#SBATCH --mem=64G
#SBATCH --nodes=1
#SBATCH --ntasks=1

source /gs/gsfs0/hpc01/rhel8/apps/conda3/etc/profile.d/conda.sh
module load samtools

set -e

# --- Usage ---
if [ "$#" -ne 2 ]; then
    echo "Merge all PBMC sample BAM files into a single merged file."
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

mkdir -p "${OUT_DIR}"

# --- Find All PBMC Sample Directories ---
PBMC_DIRS=($(find "${IN_DIR}" -maxdepth 1 -type d -name "pbmc-*" | sort))

if [ ${#PBMC_DIRS[@]} -eq 0 ]; then
    echo "Error: No PBMC sample directories found in ${IN_DIR}"
    exit 1
fi

# --- Collect All BAM Files ---
ALL_BAMS=()

for SAMPLE_DIR in "${PBMC_DIRS[@]}"; do
    SAMPLE_BAMS=($(find "${SAMPLE_DIR}" -maxdepth 1 -name "*.bam"))
    ALL_BAMS+=("${SAMPLE_BAMS[@]}")
done

if [ ${#ALL_BAMS[@]} -eq 0 ]; then
    echo "Error: No BAM files found in any PBMC sample directory"
    exit 1
fi

# --- Merge All PBMC Samples ---
FINAL_MERGED_BAM="${OUT_DIR}/pbmc_merged.bam"

if [ ${#ALL_BAMS[@]} -gt 1 ]; then
    samtools merge -f "${FINAL_MERGED_BAM}" "${ALL_BAMS[@]}"
    samtools sort -@ 8 -o "${FINAL_MERGED_BAM}.sorted" "${FINAL_MERGED_BAM}"
    mv "${FINAL_MERGED_BAM}.sorted" "${FINAL_MERGED_BAM}"
    samtools index "${FINAL_MERGED_BAM}"
else
    cp "${ALL_BAMS[0]}" "${FINAL_MERGED_BAM}"
    cp "${ALL_BAMS[0]}.bai" "${FINAL_MERGED_BAM}.bai"
fi

echo "Merged BAM created: ${FINAL_MERGED_BAM}"
echo "Total reads: $(samtools view -c "${FINAL_MERGED_BAM}")"
