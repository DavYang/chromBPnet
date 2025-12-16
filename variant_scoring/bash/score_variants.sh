#!/bin/bash
#SBATCH --job-name=variant_score                # Job name
#SBATCH --partition=gpu                   # Partition Name
#SBATCH --mem=350G  
#SBATCH --time=7-00:00:00                       # total run time limit (D-HH:MM:SS)
#SBATCH --output=logs/variant_scores/variant_scores_%A_%a.out  # Standard output with array job ID
#SBATCH --error=logs/variant_scores/variant_scores_%A_%a.err   # Error log with array job ID
#SBATCH --gres=gpu:1
#SBATCH --array=1-15                     # 3 variant classes × 5 folds = 15 total tasks

# Load required modules
module load singularity
module load cuda/11.6

# Create logs directory if it doesn't exist
mkdir -p logs

# Set TMPDIR to avoid disk space issues
export TMPDIR="/gs/gsfs0/users/$USER/tmp"
mkdir -p "$TMPDIR"

# python -m pip install --target=/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/variant_scoring/python_packages pybedtools 

# python -m pip install --target=/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/variant_scoring/python_packages --no-dependencies pysam

# python -m pip install --target=/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/variant_scoring/python_packages tensorflow

# python -m pip install --target=/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/variant_scoring/python_packages tqdm

# python -m pip install --target=/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/variant_scoring/python_packages h5py

# Set home directory for this analysis
HOMEDIR="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/variant_scoring"

# Number of folds
NUM_FOLDS=5

# Check if SLURM_ARRAY_TASK_ID is set and is a number
if [[ -z "$SLURM_ARRAY_TASK_ID" ]] || ! [[ "$SLURM_ARRAY_TASK_ID" =~ ^[0-9]+$ ]]; then
    echo "Error: SLURM_ARRAY_TASK_ID is not set or not a number." >&2
    exit 1
fi

# Calculate variant class and fold from array task ID
# Layout: variant_class changes every NUM_FOLDS tasks (5 folds per variant class)
TASKS_PER_VARIANT_CLASS=$NUM_FOLDS
VARIANT_CLASS_IDX=$(( (SLURM_ARRAY_TASK_ID-1) / TASKS_PER_VARIANT_CLASS ))
FOLD_IDX=$(( (SLURM_ARRAY_TASK_ID-1) % TASKS_PER_VARIANT_CLASS ))

# Get fold ID (starting from 0)
FOLD_ID=$FOLD_IDX

# Define variant class arrays
VARIANT_CLASSES=("mFNCV" "nFNCV" "unFNCV")
VARIANT_FILES=(
    "${HOMEDIR}/chrombpnet_formatted_variants/GA4K/mFNCV.tsv"
    "${HOMEDIR}/chrombpnet_formatted_variants/GA4K/nFNCV.tsv"
    "${HOMEDIR}/chrombpnet_formatted_variants/GA4K/unFNCV.tsv"
)

# Get variant class name and file
VARIANT_CLASS=${VARIANT_CLASSES[$VARIANT_CLASS_IDX]}
variant_tsv=${VARIANT_FILES[$VARIANT_CLASS_IDX]}

# Check if variant class index is valid
if [[ -z "$VARIANT_CLASS" ]]; then
    echo "Error: Variant class index $VARIANT_CLASS_IDX is out of bounds." >&2
    exit 1
fi

# Echo for debugging
echo "Processing variant class: $VARIANT_CLASS, fold: $FOLD_ID"

# Define output directory for this variant class
OUTPUT_DIR="${HOMEDIR}/outputs/variant_prediction_scores/${VARIANT_CLASS}/perfold_perchrom/fold_${FOLD_ID}"

genome="/gs/gsfs0/shared-lab/greally-lab/David/reference_genomes/hg38/GRCh38_full_analysis_set_plus_decoy_hla.fa"
model="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training/outputs/pbmc_merged/chrombpnet_model_b1.0/fold_${FOLD_ID}/models/chrombpnet.h5"
model_nobias="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training/outputs/pbmc_merged/chrombpnet_model_b1.0/fold_${FOLD_ID}/models/chrombpnet_nobias.h5"
chromsizes="/gs/gsfs0/shared-lab/greally-lab/chynna/osteo_chynna/chromBPnet/indexes/hg38.autosomes.chrom.sizes"
peaks="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/peak_calling/outputs/pbmc_merged/pbmc_merged_peaks.final.narrowPeak"
out_prefix="${OUTPUT_DIR}/pbmc_merged/GA4K_12-15-2025"
singularity_image="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/singularity_image/chrombpnet_latest.sif"
LOCAL_PYTHON_PACKAGES="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/variant_scoring/python_packages"
HOST_SCRIPT_SRC_DIR="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/variant_scoring/variant-scorer/src"

# Run variant scoring ensuring output directory is created inside container
singularity exec --nv \
    --bind "${HOST_SCRIPT_SRC_DIR}":/scripts \
    --bind /gs/gsfs0/shared-lab/greally-lab:/gs/gsfs0/shared-lab/greally-lab \
    --bind /gs/gsfs0/users/davyang:/gs/gsfs0/users/davyang \
    "$singularity_image" \
    bash -c "
        export PYTHONPATH=\"$LOCAL_PYTHON_PACKAGES:\$PYTHONPATH\"
        mkdir -p '$OUTPUT_DIR/pbmc_merged'
        python /gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/variant_scoring/variant-scorer/src/variant_scoring.py \
            --list '$variant_tsv' \
            --genome '$genome' \
            --model '$model_nobias' \
            --out_prefix '$out_prefix' \
            --chrom_sizes '$chromsizes' \
            --peaks '$peaks' \
            --schema chrombpnet \
            --batch_size=128
    "

echo "--------------------------------------------------------"
echo "Completed Variant Scoring for variant class ${VARIANT_CLASS}, fold ${FOLD_ID}"
echo "--------------------------------------------------------"
