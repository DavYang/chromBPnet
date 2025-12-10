#!/bin/bash
#SBATCH --job-name=modisco_motifs
#SBATCH --partition=normal
#SBATCH --cpus-per-task=16
#SBATCH --mem=150G
#SBATCH --time=2-00:00:00
#SBATCH --output=logs/modisco_%x_%A_%a.out
#SBATCH --error=logs/modisco_%x_%A_%a.err

# Load conda environment
source /gs/gsfs0/hpc01/rhel8/apps/conda3/etc/profile.d/conda.sh
conda activate chromBPnet_tools

# Set matplotlib backend for headless environment
export MPLBACKEND=Agg

# --- Configuration ---
AVERAGED_SCORES_H5="$1"
OUTPUT_DIR="$2"

OUTPUT_FILE="${OUTPUT_DIR}/tfmodisco_motifs_count_contributions.h5"

mkdir -p "$OUTPUT_DIR"

modisco motifs \
    -i "$AVERAGED_SCORES_H5" \
    -n 1000000 \
    -o "$OUTPUT_FILE" \
    -w 400

echo "MoDisco motif discovery completed"
