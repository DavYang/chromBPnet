#!/bin/bash
#SBATCH --job-name=merge_neutrophil_bams
#SBATCH --output=logs/merge_neutrophil_bams_%j.out
#SBATCH --error=logs/merge_neutrophil_bams_%j.err
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
    echo "Merge only the two highest-quality neutrophil BAM files (neutrophil-2_REP2 and neutrophil-3_REP2)."
    echo "Based on FastQC analysis, these have the best duplication levels (71-74% deduplicated)."
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

# --- Collect High-Quality BAM Files Only ---
ALL_BAMS=()

echo "Selecting only high-quality neutrophil samples (neutrophil-2_REP2 and neutrophil-3_REP2)..."
for SAMPLE_BAM in $(find "${IN_DIR}" -name "neutrophil-[23]_REP2.mLb.clN.sorted.bam" | sort); do
    echo "Including: $(basename "$SAMPLE_BAM")"
    ALL_BAMS+=("${SAMPLE_BAM}")
done

echo "Found ${#ALL_BAMS[@]} high-quality BAM files to merge"

# --- Merge High-Quality neutrophil Samples ---
FINAL_MERGED_BAM="${OUT_DIR}/neutrophil_merged.bam"

if [ ${#ALL_BAMS[@]} -gt 1 ]; then
    samtools merge -f "${FINAL_MERGED_BAM}" "${ALL_BAMS[@]}"
    samtools sort -@ 8 -o "${FINAL_MERGED_BAM}.sorted" "${FINAL_MERGED_BAM}"
    mv "${FINAL_MERGED_BAM}.sorted" "${FINAL_MERGED_BAM}"
    samtools index "${FINAL_MERGED_BAM}"
else
    cp "${ALL_BAMS[0]}" "${FINAL_MERGED_BAM}"
    cp "${ALL_BAMS[0]}.bai" "${FINAL_MERGED_BAM}.bai"
fi

echo "High-quality merged BAM created: ${FINAL_MERGED_BAM}"
echo "Total reads: $(samtools view -c "${FINAL_MERGED_BAM}")"
echo "Samples included: neutrophil-2_REP2 and neutrophil-3_REP2 (71-74% deduplication rates)"
