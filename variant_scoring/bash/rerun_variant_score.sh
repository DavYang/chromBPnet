#!/bin/bash
#SBATCH --job-name=rerun_variant_score
#SBATCH --partition=gpu
#SBATCH --gpus=1
#SBATCH --mem=100G
#SBATCH --time=7-00:00:00
#SBATCH --output=logs/rerun_variant_score_%A_%a.out
#SBATCH --error=logs/rerun_variant_score_%A_%a.err

# Rerun a single variant scoring task (useful after an h5py locking failure)
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: rerun_variant_score.sh <variant_class> <fold_id> <chromosome>

Example:
  rerun_variant_score.sh mFNCV 2 chr4

This mirrors the corresponding task from score_variants.sh but runs a
single ChromBPNet job so the HDF5 outputs can be created without concurrent
writes.
EOF
    exit 1
}

if [[ $# -ne 3 ]]; then
    echo "Error: missing arguments." >&2
    usage
fi

VARIANT_CLASS=$1
FOLD_ID=$2
CHROM=$3

VALID_CLASSES=("mFNCV" "nFNCV" "unFNCV")
if [[ ! " ${VALID_CLASSES[*]} " =~ " ${VARIANT_CLASS} " ]]; then
    echo "Error: variant_class must be one of ${VALID_CLASSES[*]}" >&2
    exit 1
fi

HOMEDIR="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/variant_scoring"
OUTPUT_DIR="${HOMEDIR}/outputs/variant_prediction_scores/${VARIANT_CLASS}/perfold_perchrom/fold_${FOLD_ID}"
chromsizes="/gs/gsfs0/shared-lab/greally-lab/chynna/osteo_chynna/chromBPnet/indexes/hg38.autosomes.chrom.sizes"
genome="/gs/gsfs0/shared-lab/greally-lab/David/reference_genomes/hg38/GRCh38_full_analysis_set_plus_decoy_hla.fa"
model_nobias="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training/outputs/pbmc_merged/chrombpnet_model_b1.0/fold_${FOLD_ID}/models/chrombpnet_nobias.h5"
peaks="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/peak_calling/outputs/pbmc_merged/pbmc_merged_peaks.final.narrowPeak"
out_prefix="${OUTPUT_DIR}/pbmc_merged"
singularity_image="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/singularity_image/chrombpnet_latest.sif"
HOST_SCRIPT_SRC_DIR="${HOMEDIR}/variant-scorer/src"

declare -A VARIANT_FILE_MAP=(
    [mFNCV]="functional_methylated_outlier_variants_chrombpnet_corrected.tsv"
    [nFNCV]="non_functional_variants_chrombpnet_corrected.tsv"
    [unFNCV]="functional_unmethylated_outlier_variants_chrombpnet_corrected.tsv"
)

VARIANT_TSV="${HOMEDIR}/chrombpnet_formatted_variants/${VARIANT_FILE_MAP[$VARIANT_CLASS]}"
if [[ ! -f "$VARIANT_TSV" ]]; then
    echo "Error: missing variant list $VARIANT_TSV" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "Rerunning ${VARIANT_CLASS} fold ${FOLD_ID} chromosome ${CHROM}"\

module load singularity
module load cuda/11.6

singularity exec --nv \
    --bind "${HOST_SCRIPT_SRC_DIR}":/scripts \
    --bind /gs/gsfs0/shared-lab/greally-lab:/gs/gsfs0/shared-lab/greally-lab \
    --bind /gs/gsfs0/users/davyang:/gs/gsfs0/users/davyang \
    "$singularity_image" \
    bash -c "
        python /scripts/variant_scoring.py \
            --list '${VARIANT_TSV}' \
            --genome '$genome' \
            --model '$model_nobias' \
            --out_prefix '$out_prefix' \
            --chrom_sizes '$chromsizes' \
            --peaks '$peaks' \
            --schema chrombpnet \
            --batch_size=128 \
            --chrom '$CHROM'
    "

echo "Rerun complete."

