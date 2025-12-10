#!/bin/bash
#SBATCH --job-name=summarize_folds
#SBATCH --partition=normal
#SBATCH --mem=32G
#SBATCH --time=2:00:00
#SBATCH --output=logs/summarize_folds_%A_%a.out
#SBATCH --error=logs/summarize_folds_%A_%a.err
#SBATCH --array=1-3

set -e

# Load required modules
module load singularity

# Set home directory
HOMEDIR="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/variant_scoring"

# Define variant classes
VARIANT_CLASSES=("mFNCV" "nFNCV" "unFNCV")
VARIANT_CLASS=${VARIANT_CLASSES[$((SLURM_ARRAY_TASK_ID-1))]}

echo "Processing variant class: $VARIANT_CLASS"

# Define paths
SCORE_DIR="${HOMEDIR}/outputs/variant_prediction_scores/${VARIANT_CLASS}/perfold_perchrom"
OUTPUT_DIR="${HOMEDIR}/outputs/variant_prediction_scores/${VARIANT_CLASS}"
OUTPUT_PREFIX="${OUTPUT_DIR}/pbmc_merged"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Build list of score files from all folds with full paths
SCORE_FILES=()
for FOLD_ID in {0..4}; do
    SCORE_FILE="${SCORE_DIR}/fold_${FOLD_ID}/pbmc_merged.variant_scores.tsv"
    if [ -f "$SCORE_FILE" ]; then
        SCORE_FILES+=("$SCORE_FILE")
    else
        echo "Warning: Score file not found: $SCORE_FILE"
    fi
done

if [ ${#SCORE_FILES[@]} -eq 0 ]; then
    echo "Error: No score files found for ${VARIANT_CLASS}"
    exit 1
fi

echo "Found ${#SCORE_FILES[@]} score files from folds"

# Create temporary directory with symlinks so all files are in one place
TEMP_SCORE_DIR="${OUTPUT_DIR}/temp_scores_$$"
mkdir -p "$TEMP_SCORE_DIR"

SCORE_LIST=""
for i in "${!SCORE_FILES[@]}"; do
    LINK_NAME="fold_${i}_variant_scores.tsv"
    ln -sf "${SCORE_FILES[$i]}" "${TEMP_SCORE_DIR}/${LINK_NAME}"
    SCORE_LIST="${SCORE_LIST} ${LINK_NAME}"
done

# Set singularity image and script paths
singularity_image="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/singularity_image/chrombpnet_latest.sif"
HOST_SCRIPT_SRC_DIR="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/variant_scoring/variant-scorer/src"

# Run variant summary
singularity exec \
    --bind "${HOST_SCRIPT_SRC_DIR}":/scripts \
    --bind /gs/gsfs0/shared-lab/greally-lab:/gs/gsfs0/shared-lab/greally-lab \
    "$singularity_image" \
    bash -c "
        python /scripts/variant_summary_across_folds.py \
            --score_dir '${TEMP_SCORE_DIR}' \
            --score_list${SCORE_LIST} \
            --out_prefix '${OUTPUT_PREFIX}' \
            --schema chrombpnet
    "

# Clean up temporary directory
rm -rf "$TEMP_SCORE_DIR"

echo "--------------------------------------------------------"
echo "Completed summarization for ${VARIANT_CLASS}"
echo "Output: ${OUTPUT_PREFIX}.mean.variant_scores.tsv"
echo "--------------------------------------------------------"

