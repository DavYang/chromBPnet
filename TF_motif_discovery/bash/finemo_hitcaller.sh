#!/bin/bash
#SBATCH --job-name=finemo_call_hits_global
#SBATCH --partition=gpu
#SBATCH --gpus=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=100G
#SBATCH --time=24:00:00
#SBATCH --mail-type=END,FAIL
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --error=logs/%x_%A_%a.err

set -e

source /gs/gsfs0/hpc01/rhel8/apps/conda3/etc/profile.d/conda.sh
conda activate chromBPnet_tools

export MPLBACKEND=Agg

# MODISCO results (.h5)
MODISCO_H5="$1"

# finemo extracted scores (.npz), the command uses the NPZ prefix, not the full filename
EXTRACTED_SCORES_NPZ_PREFIX="$2"

# CWM trim threshold
CWM_TRIM_THRESHOLD="$3"

# Output directory
OUTPUT_DIR="$4"
mkdir -p "$OUTPUT_DIR"


echo "--- Running: finemo call-hits ---"

finemo call-hits \
    -r "$EXTRACTED_SCORES_NPZ_PREFIX" \
    -m "$MODISCO_H5" \
    -t "$CWM_TRIM_THRESHOLD" \
    -o "$OUTPUT_DIR" \
    --compile

# ======================================================================

echo "--------------------------------------------------------"
echo "--------------------------------------------------------"



