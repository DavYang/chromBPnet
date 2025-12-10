#!/bin/bash
#SBATCH --job-name=finemo_report
#SBATCH --partition=normal
#SBATCH --mem=30G
#SBATCH --time=04:00:00
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --error=logs/%x_%A_%a.err

set -e

source /gs/gsfs0/hpc01/rhel8/apps/conda3/etc/profile.d/conda.sh
conda activate chromBPnet_tools

# --- Configuration ---

export MPLBACKEND=Agg
HITS_DIR_COUNTS="$1"
MODISCO_H5="$2"
PEAKS_BED="$3"

finemo report \
    -H ${HITS_DIR_COUNTS}/hits_0.7  \
    -r ${HITS_DIR_COUNTS}/finemo_extracted_counts-scores.npz \
    -m ${MODISCO_H5} \
    -p ${PEAKS_BED} \
    -o ${HITS_DIR_COUNTS}/hits_0.7 