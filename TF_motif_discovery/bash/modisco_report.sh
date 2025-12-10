#!/bin/bash
#SBATCH --job-name=modisco_report
#SBATCH --partition=normal
#SBATCH --cpus-per-task=4
#SBATCH --mem=30G                 
#SBATCH --time=04:00:00           
#SBATCH --mail-type=END,FAIL
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --error=logs/%x_%A_%a.err

set -e
source /gs/gsfs0/hpc01/rhel8/apps/conda3/etc/profile.d/conda.sh
conda activate chromBPnet_tools

# --- Configuration ---
BASE_DIR="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/TF_motif_discovery"

# Input: The comprehensive motif database you downloaded
MEME_FILE="/gs/gsfs0/shared-lab/greally-lab/David/databases/JASPAR/JASPAR2024_CORE_vertebrates_non-redundant_pfms_meme.txt"
counts_h5="$1"
counts_out_dir="$2"
mkdir -p "$counts_out_dir"

# Set matplotlib backend for headless environment
export MPLBACKEND=Agg

modisco report \
  -i "$counts_h5" \
  -o "$counts_out_dir" \
  -m "$MEME_FILE" \
  -t