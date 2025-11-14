#!/bin/bash
#SBATCH --job-name=chrombpnet_array         # Job name
#SBATCH --partition=gpu                     # Partition Name
#SBATCH --mem=100G
#SBATCH --gres=gpu
#SBATCH --cpus-per-task=10
#SBATCH --time=infinite                    # total run time limit (HH:MM:SS)
#SBATCH --output=logs/chrombpnet_model_%A_%a.log  # Standard output with array job ID
#SBATCH --error=logs/chrombpnet_model_%A_%a.err   # Error log with array job ID
#SBATCH --mail-type=END,FAIL                # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=david.yang2@einsteinmed.edu     # Where to send mail
#SBATCH --array=0-4                         # Array range - adjust based on number of folds/splits

# Set error handling
set -e

source /gs/gsfs0/hpc01/rhel8/apps/conda3/etc/profile.d/conda.sh
module load singularity

# Get the current array task ID first
FOLD_ID=${SLURM_ARRAY_TASK_ID}

HOME_DIR="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training"

# Define singularity image
singularity_image="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/singularity_image/chrombpnet_latest.sif"

# Input files and parameters
GENOME_FILE="/gs/gsfs0/shared-lab/greally-lab/David/reference_genomes/hg38/GRCh38_full_analysis_set_plus_decoy_hla.fa"
CHROM_SIZES="/gs/gsfs0/shared-lab/greally-lab/chynna/osteo_chynna/chromBPnet/indexes/hg38.autosomes.chrom.sizes"
BAM_FILE="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/nf-core_atac/results/bwa/merged_library/autosomes_only/merged_neutrophils/neutrophil_merged.bam"
PEAKS_FILE="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/peak_calling/outputs/neutrophil_merged/neutrophil_merged_peaks.final.narrowPeak"
NEGATIVE_FILE="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/generate_folds/outputs/neutrophil_merged/folds/f${FOLD_ID}_output_negatives.bed"
FOLD_FILE="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/generate_folds/outputs/neutrophil_merged/splits/fold_${FOLD_ID}.json"
BIAS_MODEL="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/bias_model_training/outputs/neutrophil_merged/bias_model_f0_b1.0/models/neutrophil_merged_bias.h5"

# Define output directory with array index
OUTPUT_DIR="$HOME_DIR/outputs/neutrophil_merged/chrombpnet_model_b1.0/fold_${FOLD_ID}/"


# Create output directory
mkdir -p $OUTPUT_DIR

# Create logs directory if it doesn't exist
mkdir -p logs

# Validate input files exist
echo "Validating input files..."
if [[ ! -f "$BAM_FILE" ]]; then
    echo "ERROR: BAM file not found: $BAM_FILE"
    exit 1
fi

if [[ ! -f "$GENOME_FILE" ]]; then
    echo "ERROR: Genome file not found: $GENOME_FILE"
    exit 1
fi

if [[ ! -f "$PEAKS_FILE" ]]; then
    echo "ERROR: Peaks file not found: $PEAKS_FILE"
    exit 1
fi

if [[ ! -f "$NEGATIVE_FILE" ]]; then
    echo "ERROR: Negative file not found: $NEGATIVE_FILE"
    exit 1
fi

if [[ ! -f "$FOLD_FILE" ]]; then
    echo "ERROR: Fold file not found: $FOLD_FILE"
    exit 1
fi

if [[ ! -f "$BIAS_MODEL" ]]; then
    echo "ERROR: Bias model not found: $BIAS_MODEL"
    exit 1
fi

# Echo the parameters for debugging
echo "Processing fold: $FOLD_ID"
echo "Using fold file: $FOLD_FILE"
echo "Using negative file: $NEGATIVE_FILE"
echo "Using bias model: $BIAS_MODEL"
echo "Output directory: $OUTPUT_DIR"

# Run singularity with environment isolation
echo "Starting chromBPnet training..."
singularity exec --bind /gs/gsfs0/shared-lab/greally-lab:/gs/gsfs0/shared-lab/greally-lab --nv \
  $singularity_image \
  chrombpnet pipeline \
        -ibam $BAM_FILE \
        -d "ATAC" \
        -g $GENOME_FILE \
        -c $CHROM_SIZES \
        -p $PEAKS_FILE \
        -n $NEGATIVE_FILE \
        -fl $FOLD_FILE \
        -b $BIAS_MODEL \
        -o $OUTPUT_DIR

echo "chromBPnet training completed for fold $FOLD_ID"
