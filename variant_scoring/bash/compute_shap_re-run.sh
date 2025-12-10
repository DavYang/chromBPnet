#!/bin/bash
#SBATCH --job-name=compute_shap_failed
#SBATCH --partition=gpu
#SBATCH --gpus=1
#SBATCH --gres=gpu:1
#SBATCH --mem=200G
#SBATCH --time=7-00:00:00
#SBATCH --output=logs/compute_shap/compute_shap_failed_%A_%a.out
#SBATCH --error=logs/compute_shap/compute_shap_failed_%A_%a.err
#SBATCH --array=30,31,32,34,35,36,37

set -e

# Load required modules
module load singularity
module load cuda/11.6

# Create logs directory if it doesn't exist
mkdir -p logs

# Set TMPDIR to avoid disk space issues
export TMPDIR="/gs/gsfs0/users/$USER/tmp"
mkdir -p "$TMPDIR"

# Set home directory
HOMEDIR="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/variant_scoring"

# Define variant classes
VARIANT_CLASSES=("mFNCV" "nFNCV" "unFNCV")

# Define chromosomes
CHROMOSOMES=(
    "chr1" "chr2" "chr3" "chr4" "chr5" "chr6" "chr7" "chr8" "chr9" "chr10"
    "chr11" "chr12" "chr13" "chr14" "chr15" "chr16" "chr17" "chr18" "chr19"
    "chr20" "chr21" "chr22"
)

# Calculate variant class and chromosome from array task ID
# 3 variant classes × 22 chromosomes = 66 total tasks
NUM_CHROMS=22
VARIANT_IDX=$(( (SLURM_ARRAY_TASK_ID-1) / NUM_CHROMS ))
CHROM_IDX=$(( (SLURM_ARRAY_TASK_ID-1) % NUM_CHROMS ))

VARIANT_CLASS=${VARIANT_CLASSES[$VARIANT_IDX]}
CHROM=${CHROMOSOMES[$CHROM_IDX]}

echo "Processing variant class: $VARIANT_CLASS, chromosome: $CHROM"

# Define paths - map variant class names to file names
declare -A VARIANT_FILES
VARIANT_FILES["mFNCV"]="functional_methylated_outlier_variants_chrombpnet_corrected.tsv"
VARIANT_FILES["nFNCV"]="non_functional_variants_chrombpnet_corrected.tsv"
VARIANT_FILES["unFNCV"]="functional_unmethylated_outlier_variants_chrombpnet_corrected.tsv"

VARIANT_TSV="${HOMEDIR}/chrombpnet_formatted_variants/${VARIANT_FILES[$VARIANT_CLASS]}"
OUTPUT_DIR="${HOMEDIR}/outputs/variant_shap_scores/${VARIANT_CLASS}"
OUTPUT_PREFIX="${OUTPUT_DIR}/pbmc_merged.${CHROM}"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Use fold 0 model (or could average across folds, but using single fold for now)
FOLD_ID=0
genome="/gs/gsfs0/shared-lab/greally-lab/David/reference_genomes/hg38/GRCh38_full_analysis_set_plus_decoy_hla.fa"
model_nobias="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training/outputs/pbmc_merged/chrombpnet_model_b1.0/fold_${FOLD_ID}/models/chrombpnet_nobias.h5"
chromsizes="/gs/gsfs0/shared-lab/greally-lab/chynna/osteo_chynna/chromBPnet/indexes/hg38.autosomes.chrom.sizes"

# Set singularity image and script paths
singularity_image="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/singularity_image/chrombpnet_latest.sif"
HOST_SCRIPT_SRC_DIR="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/variant_scoring/variant-scorer/src"

# Check if variant file exists
if [ ! -f "$VARIANT_TSV" ]; then
    echo "Error: Variant file not found: $VARIANT_TSV"
    exit 1
fi

# Run SHAP computation
singularity exec --nv \
    --bind "${HOST_SCRIPT_SRC_DIR}":/scripts \
    --bind /gs/gsfs0/shared-lab/greally-lab:/gs/gsfs0/shared-lab/greally-lab \
    --bind /gs/gsfs0/users/davyang:/gs/gsfs0/users/davyang \
    "$singularity_image" \
    bash -c "
        mkdir -p '$OUTPUT_DIR' && \
        python /scripts/variant_shap.py \
            --list '$VARIANT_TSV' \
            --genome '$genome' \
            --model '$model_nobias' \
            --out_prefix '$OUTPUT_PREFIX' \
            --chrom_sizes '$chromsizes' \
            --schema chrombpnet \
            --batch_size 128 \
            --chrom '$CHROM' \
            --shap_type counts
    "

echo "--------------------------------------------------------"
echo "Completed SHAP computation for ${VARIANT_CLASS} chromosome ${CHROM}"
echo "Output: ${OUTPUT_PREFIX}.variant_shap.counts.h5"
echo "--------------------------------------------------------"
