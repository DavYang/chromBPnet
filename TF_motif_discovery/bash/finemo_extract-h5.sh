#!/bin/bash
#SBATCH --job-name=finemo_extract_counts
#SBATCH --partition=gpu
#SBATCH --gpus=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=100G
#SBATCH --time=24:00:00
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --error=logs/%x_%A_%a.err

set -e

source /gs/gsfs0/hpc01/rhel8/apps/conda3/etc/profile.d/conda.sh
conda activate chromBPnet_tools

# --- Configuration ---

# Input: The contribution scores from modisco step
CONTRIBUTION_SCORES="$1"
REGIONS_BED="$2"
OUTPUT_DIR="$3"
mkdir -p "$OUTPUT_DIR"
EXTRACTED_SCORES_NPZ="${OUTPUT_DIR}/finemo_extracted_counts-scores"

echo "--- Running: finemo extract-regions-chrombpnet-h5 ---"
export MPLBACKEND=Agg

finemo extract-regions-chrombpnet-h5 \
    -c "$CONTRIBUTION_SCORES" \
    -p "$REGIONS_BED" \
    -o "$EXTRACTED_SCORES_NPZ" \
    -w 2114

echo "Extracted scores saved to: $EXTRACTED_SCORES_NPZ"


