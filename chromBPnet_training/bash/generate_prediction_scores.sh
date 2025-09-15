#!/bin/bash
#SBATCH --job-name=chrombpnet_array         # Job name
#SBATCH --partition=gpu                     # Partition Name
#SBATCH --mem=100G
#SBATCH --gres=gpu
#SBATCH --cpus-per-task=10
#SBATCH --time=infinite                    # total run time limit (HH:MM:SS)
#SBATCH --output=logs/chrombpnet_model_%A_%a.log  # Standard output with array job ID
#SBATCH --error=logs/chrombpnet_model_%A_%a.err   # Error log with array job ID
#SBATCH --array=0-4                         # Array range - adjust based on number of folds/splits
                 
source /gs/gsfs0/hpc01/rhel8/apps/conda3/etc/profile.d/conda.sh
module load singularity


# Define full home path to replace tilde
HOME_DIR="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training"


# Define the singularity image path
# Define singularity image
singularity_image="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/singularity_image/chrombpnet_latest.sif"
# Get the current array task ID
FOLD_ID=${SLURM_ARRAY_TASK_ID}

# Define output directory first so we can use it for other path definitions
OUTPUT_DIR="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training/outputs/pbmc-2_4_merged/chrombpnet_model_b0.6/extracted_scores/prediction_scores_bw/fold_${FOLD_ID}/"

genome="/gs/gsfs0/shared-lab/greally-lab/David/reference_genomes/hg38/GRCh38_full_analysis_set_plus_decoy_hla.fa"
model="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training/outputs/pbmc-2_4_merged/chrombpnet_model_b0.6/fold_${FOLD_ID}/models/chrombpnet.h5"
model_nobias="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training/outputs/pbmc-2_4_merged/chrombpnet_model_b0.6/fold_${FOLD_ID}/models/chrombpnet_nobias.h5"
chromsizes="/gs/gsfs0/shared-lab/greally-lab/chynna/osteo_chynna/chromBPnet/indexes/hg38.autosomes.chrom.sizes"
peaks="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/peak_calling/outputs/pbmc-2_4_merged/pbmc-2_4_merged_peaks.final.narrowPeak"

out_prefix=$OUTPUT_DIR/pbmc-2_4_merged

# Create output directory
mkdir -p $OUTPUT_DIR

# Echo the parameters for debugging
echo "Processing fold: $FOLD_ID"
echo "Using ChromBPNet model: $model"
echo "Using bias-corrected model: $model_nobias"
echo "Output directory: $OUTPUT_DIR"
echo "Using singularity image: $singularity_image"

module load singularity

# Run the contribution scores command
echo "Starting chromBPnet predictionscore extraction..."
singularity exec --bind /gs/gsfs0/shared-lab/greally-lab:/gs/gsfs0/shared-lab/greally-lab --nv \
  $singularity_image \
  chrombpnet pred_bw \
  -g $genome \
  -cmb $model_nobias \
  -r $peaks \
  -c $chromsizes \
  -op $out_prefix




