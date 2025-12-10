#!/bin/bash
#SBATCH --job-name=hitcaller_variant
#SBATCH --partition=gpu
#SBATCH --gpus=1
#SBATCH --mem=100G
#SBATCH --time=24:00:00
#SBATCH --output=logs/hitcaller_variant/hitcaller_variant_%A_%a.out
#SBATCH --error=logs/hitcaller_variant/hitcaller_variant_%A_%a.err
#SBATCH --array=1-66

set -e

# Load required modules
source /gs/gsfs0/hpc01/rhel8/apps/conda3/etc/profile.d/conda.sh 
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

VARIANT_CLASS="${VARIANT_CLASSES[$VARIANT_IDX]}"
CHROM="${CHROMOSOMES[$CHROM_IDX]}"

echo "Processing variant class: $VARIANT_CLASS, chromosome: $CHROM"

# Define paths - map variant class names to file names
declare -A VARIANT_FILES
VARIANT_FILES["mFNCV"]="functional_methylated_outlier_variants_chrombpnet_corrected.tsv"
VARIANT_FILES["nFNCV"]="non_functional_variants_chrombpnet_corrected.tsv"
VARIANT_FILES["unFNCV"]="functional_unmethylated_outlier_variants_chrombpnet_corrected.tsv"

VARIANT_TSV="${HOMEDIR}/chrombpnet_formatted_variants/${VARIANT_FILES[$VARIANT_CLASS]}"
SHAP_H5="${HOMEDIR}/outputs/variant_shap_scores/${VARIANT_CLASS}/pbmc_merged.${CHROM}.variant_shap.counts.h5"
OUTPUT_DIR="${HOMEDIR}/outputs/variant_hit_calls/${VARIANT_CLASS}/${CHROM}"
MODISCO_H5="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/TF_motif_discovery/outputs/modisco_results/tfmodisco_motifs_count_contributions.h5"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check if required files exist
if [[ ! -f "$SHAP_H5" ]]; then
    echo "Error: SHAP file not found: $SHAP_H5"
    exit 1
fi

if [[ ! -f "$MODISCO_H5" ]]; then
    echo "Error: TF-MoDISco file not found: $MODISCO_H5"
    exit 1
fi

if [[ ! -f "$VARIANT_TSV" ]]; then
    echo "Error: Variant file not found: $VARIANT_TSV"
    exit 1
fi

# Set singularity image and script paths
singularity_image="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/singularity_image/chrombpnet_latest.sif"
HOST_SCRIPT_SRC_DIR="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/variant_scoring/variant-scorer/src"

# Filter variant file to current chromosome for hit calling
CHROM_VARIANT_TSV="${OUTPUT_DIR}/variants_${CHROM}.tsv"
grep "^${CHROM}" "$VARIANT_TSV" > "$CHROM_VARIANT_TSV" || echo "No variants found for ${CHROM}"

if [[ ! -s "$CHROM_VARIANT_TSV" ]]; then
    echo "Warning: No variants found for ${VARIANT_CLASS} chromosome ${CHROM}, skipping..."
    exit 0
fi

# Run hit calling
singularity exec --nv \
    --bind "${HOST_SCRIPT_SRC_DIR}":/scripts \
    --bind /gs/gsfs0/shared-lab/greally-lab:/gs/gsfs0/shared-lab/greally-lab \
    --bind /gs/gsfs0/users/davyang:/gs/gsfs0/users/davyang \
    "$singularity_image" \
    bash -c "
        conda activate chromBPnet_tools && \
        python /scripts/hitcaller_variant.py \
            --shap_data '$SHAP_H5' \
            --input_type h5 \
            --modisco_h5 '$MODISCO_H5' \
            --variant_file '$CHROM_VARIANT_TSV' \
            --output_dir '$OUTPUT_DIR' \
            --alpha 0.6 \
            --hits_per_loc 3
    "

echo "--------------------------------------------------------"
echo "Completed hit calling for ${VARIANT_CLASS} chromosome ${CHROM}"
echo "Output: ${OUTPUT_DIR}/variant_hit_calls.tsv"
echo "--------------------------------------------------------"
