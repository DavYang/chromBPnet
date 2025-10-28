#!/bin/bash
#SBATCH --job-name=average_h5
#SBATCH --partition=unlimited                     # Partition Name
#SBATCH --mem=120G
#SBATCH --time=7-00:00:00                     # total run time limit (HH:MM:SS)
#SBATCH --output=logs/average_h5.log  
#SBATCH --error=logs/average_h5.err   


# Load conda environment
source /gs/gsfs0/hpc01/rhel8/apps/conda3/etc/profile.d/conda.sh
conda activate chrombpnet_python

# Define file paths (correct bash syntax)
file_pattern="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training/outputs/pbmc_merged/chrombpnet_model_b1.0/contribution_scores_bw/fold_*/pbmc-merged.counts_scores.h5"
output_path="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training/outputs/pbmc_merged/chrombpnet_model_b1.0/contribution_scores_bw/averaged_scores/averaged_folds_pbmc-merged.counts_scores.h5"

# Create output directory if it doesn't exist
mkdir -p "$(dirname "$output_path")"

# Run the averaging script
python /gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training/python/average_contribution_scores_h5.py \
    --file_pattern "$file_pattern" \
    --output_path "$output_path"