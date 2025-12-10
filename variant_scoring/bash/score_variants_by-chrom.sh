#!/bin/bash
#SBATCH --job-name=variant_score                # Job name
#SBATCH --partition=gpu                   # Partition Name
#SBATCH --mem=100G
#SBATCH --time=7-00:00:00                       # total run time limit (D-HH:MM:SS)
#SBATCH --output=logs/variant_scores_%A_%a.log  # Standard output with array job ID
#SBATCH --error=logs/variant_scores_%A_%a.err   # Error log with array job ID
#SBATCH --gres=gpu:1
#SBATCH --array=1-330%10                    # 3 variant classes × 5 folds × 22 chromosomes = 330 total tasks, limit to 10 concurrent


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

# Define chromosomes array
CHROMOSOMES=(
    "chr1" "chr2" "chr3" "chr4" "chr5" "chr6" "chr7" "chr8" "chr9" "chr10"
    "chr11" "chr12" "chr13" "chr14" "chr15" "chr16" "chr17" "chr18" "chr19"
    "chr20" "chr21" "chr22"
)

# Number of chromosomes and folds
NUM_CHROMS=22
NUM_FOLDS=5

# Check if SLURM_ARRAY_TASK_ID is set and is a number
if [[ -z "$SLURM_ARRAY_TASK_ID" ]] || ! [[ "$SLURM_ARRAY_TASK_ID" =~ ^[0-9]+$ ]]; then
    echo "Error: SLURM_ARRAY_TASK_ID is not set or not a number." >&2
    exit 1
fi

# Calculate variant class, fold, and chromosome from array task ID
# Layout: variant_class changes every (NUM_FOLDS * NUM_CHROMS) tasks
TASKS_PER_VARIANT_CLASS=$((NUM_FOLDS * NUM_CHROMS))
VARIANT_CLASS_IDX=$(( (SLURM_ARRAY_TASK_ID-1) / TASKS_PER_VARIANT_CLASS ))
TASK_WITHIN_CLASS=$(( (SLURM_ARRAY_TASK_ID-1) % TASKS_PER_VARIANT_CLASS ))
FOLD_IDX=$(( TASK_WITHIN_CLASS / NUM_CHROMS ))
CHROM_IDX=$(( TASK_WITHIN_CLASS % NUM_CHROMS ))

# Get fold ID (starting from 0) and chromosome name
FOLD_ID=$FOLD_IDX
CHROM=${CHROMOSOMES[$CHROM_IDX]}

# Check if chromosome index is valid
if [[ -z "$CHROM" ]]; then
    echo "Error: Chromosome index $CHROM_IDX is out of bounds." >&2
    exit 1
fi

# Define variant class arrays
VARIANT_CLASSES=("mFNCV" "nFNCV" "unFNCV")
VARIANT_FILES=(
    "${HOMEDIR}/chrombpnet_formatted_variants/functional_methylated_outlier_variants_chrombpnet_corrected.tsv"
    "${HOMEDIR}/chrombpnet_formatted_variants/non_functional_variants_chrombpnet_corrected.tsv"
    "${HOMEDIR}/chrombpnet_formatted_variants/functional_unmethylated_outlier_variants_chrombpnet_corrected.tsv"
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
echo "Processing variant class: $VARIANT_CLASS, fold: $FOLD_ID, chromosome: $CHROM"

# Define output directory for this variant class
OUTPUT_DIR="${HOMEDIR}/outputs/variant_prediction_scores/${VARIANT_CLASS}/perfold_perchrom/fold_${FOLD_ID}/"

genome="/gs/gsfs0/shared-lab/greally-lab/David/reference_genomes/hg38/GRCh38_full_analysis_set_plus_decoy_hla.fa"
model="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training/outputs/pbmc_merged/chrombpnet_model_b1.0/fold_${FOLD_ID}/models/chrombpnet.h5"
model_nobias="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training/outputs/pbmc_merged/chrombpnet_model_b1.0/fold_${FOLD_ID}/models/chrombpnet_nobias.h5"
chromsizes="/gs/gsfs0/shared-lab/greally-lab/chynna/osteo_chynna/chromBPnet/indexes/hg38.autosomes.chrom.sizes"
peaks="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/peak_calling/outputs/pbmc_merged/pbmc_merged_peaks.final.narrowPeak"
out_prefix="${OUTPUT_DIR}/pbmc_merged"
singularity_image="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/singularity_image/chrombpnet_latest.sif"
LOCAL_PYTHON_PACKAGES="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/variant_scoring/python_packages"
HOST_SCRIPT_SRC_DIR="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/variant_scoring/variant-scorer/src"

# Run variant scoring
singularity exec --nv \
    --bind "${HOST_SCRIPT_SRC_DIR}":/scripts \
    --bind /gs/gsfs0/shared-lab/greally-lab:/gs/gsfs0/shared-lab/greally-lab \
    --bind /gs/gsfs0/users/davyang:/gs/gsfs0/users/davyang \
    "$singularity_image" \
    bash -c "
        mkdir -p '$OUTPUT_DIR' && \
        python /scripts/variant_scoring.py \
            --list '$variant_tsv' \
            --genome '$genome' \
            --model '$model_nobias' \
            --out_prefix '$out_prefix' \
            --chrom_sizes '$chromsizes' \
            --peaks '$peaks' \
            --schema chrombpnet \
            --batch_size=128 \
            --chrom '$CHROM'
    "

echo "--------------------------------------------------------"
echo "Completed Variant Scoring for fold ${FOLD_ID}, chromosome ${CHROM}"
echo "--------------------------------------------------------"
