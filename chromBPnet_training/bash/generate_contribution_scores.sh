#!/bin/bash
#SBATCH --job-name=chrombpnet_array         # Job name
#SBATCH --partition=gpu                     # Partition Name
#SBATCH --mem=100G
#SBATCH --gres=gpu
#SBATCH --cpus-per-task=10
#SBATCH --time=infinite                    # total run time limit (HH:MM:SS)
#SBATCH --output=logs/contribution_scores_%A_%a.log  # Standard output with array job ID
#SBATCH --error=logs/contribution_scores_%A_%a.err   # Error log with array job ID
#SBATCH --array=0-4                         # Array range - adjust based on number of folds/splits
                 
source /gs/gsfs0/hpc01/rhel8/apps/conda3/etc/profile.d/conda.sh
module load singularity

# Set TMPDIR and SINGULARITY_TMPDIR to avoid disk space issues
export TMPDIR="/scratch/$USER"
export SINGULARITY_TMPDIR="$TMPDIR"
export SINGULARITY_CACHEDIR="$TMPDIR/singularity_cache"
mkdir -p "$TMPDIR"
mkdir -p "$SINGULARITY_CACHEDIR"

# Debug: Print environment and check temp directories
echo "=========================================="
echo "ENVIRONMENT SETUP"
echo "=========================================="
echo "TMPDIR: $TMPDIR"
echo "SINGULARITY_TMPDIR: $SINGULARITY_TMPDIR"
echo "SINGULARITY_CACHEDIR: $SINGULARITY_CACHEDIR"
echo ""
echo "Checking disk space in temp directory:"
df -h "$TMPDIR" 2>/dev/null || echo "Warning: Could not check disk space for $TMPDIR"
echo ""
echo "Initial memory usage:"
free -h
echo "=========================================="
echo ""

# Define full home path to replace tilde
HOME_DIR="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training"


# Define the singularity image path
# Define singularity image
singularity_image="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/singularity_image/chrombpnet_latest.sif"
# Get the current array task ID
FOLD_ID=${SLURM_ARRAY_TASK_ID}

# Define output directory first so we can use it for other path definitions
OUTPUT_DIR="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training/outputs/pbmc_merged/chrombpnet_model_b1.0/contribution_scores_bw/fold_${FOLD_ID}/"

genome="/gs/gsfs0/shared-lab/greally-lab/David/reference_genomes/hg38/GRCh38_full_analysis_set_plus_decoy_hla.fa"
model="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training/outputs/pbmc_merged/chrombpnet_model_b1.0/fold_${FOLD_ID}/models/chrombpnet.h5"
model_nobias="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training/outputs/pbmc_merged/chrombpnet_model_b1.0/fold_${FOLD_ID}/models/chrombpnet_nobias.h5"
chromsizes="/gs/gsfs0/shared-lab/greally-lab/chynna/osteo_chynna/chromBPnet/indexes/hg38.autosomes.chrom.sizes"
peaks="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/peak_calling/outputs/pbmc_merged/pbmc_merged_peaks.final.narrowPeak"

out_prefix=$OUTPUT_DIR/pbmc-merged

# Create output directory
mkdir -p $OUTPUT_DIR

# Echo the parameters for debugging
echo "=========================================="
echo "JOB PARAMETERS"
echo "=========================================="
echo "Processing fold: $FOLD_ID"
echo "Using bias-corrected model: $model_nobias"
echo "Output directory: $OUTPUT_DIR"
echo "Using singularity image: $singularity_image"
echo "Genome: $genome"
echo "Peaks: $peaks"
echo "Chrom sizes: $chromsizes"
echo "=========================================="
echo ""

module load singularity

# Check singularity version and configuration
echo "Singularity version:"
singularity --version
echo ""

# Run the contribution scores command
echo "=========================================="
echo "STARTING SINGULARITY CONTAINER"
echo "=========================================="
echo "Timestamp: $(date)"
echo ""

# Check temp directory before running
echo "Temp directory contents before execution:"
ls -lah "$TMPDIR" 2>/dev/null | head -20 || echo "Could not list temp directory"
echo ""
echo "Disk space before execution:"
df -h "$TMPDIR" 2>/dev/null || echo "Could not check disk space"
echo ""
echo "Memory before execution:"
free -h
echo "=========================================="
echo ""

echo "Running chromBPnet contribs_bw..."
singularity exec --bind /gs/gsfs0/shared-lab/greally-lab:/gs/gsfs0/shared-lab/greally-lab --nv \
  $singularity_image \
  bash -c "
    set -e
    echo 'Starting chromBPnet contribs_bw...'
    echo 'Memory inside container:'
    free -h
    echo ''
    chrombpnet contribs_bw \
      -g $genome \
      -m $model_nobias \
      -r $peaks \
      -c $chromsizes \
      -op $out_prefix
  "

# Capture exit status
EXIT_STATUS=$?

echo ""
echo "=========================================="
echo "EXECUTION COMPLETED"
echo "=========================================="
echo "Exit status: $EXIT_STATUS"
echo "Timestamp: $(date)"
echo ""
echo "Temp directory contents after execution:"
ls -lah "$TMPDIR" 2>/dev/null | head -20 || echo "Could not list temp directory"
echo ""
echo "Disk space after execution:"
df -h "$TMPDIR" 2>/dev/null || echo "Could not check disk space"
echo ""
echo "Memory after execution:"
free -h
echo ""
echo "Temp directory size:"
du -sh "$TMPDIR" 2>/dev/null || echo "Could not measure temp directory size"
echo "=========================================="

# Check if execution was successful
if [ $EXIT_STATUS -ne 0 ]; then
    echo "ERROR: chromBPnet contribs_bw failed with exit status $EXIT_STATUS" >&2
    echo "Check the error log for details" >&2
    exit $EXIT_STATUS
fi

echo ""
echo "SUCCESS: Contribution scores generated successfully for fold $FOLD_ID"
echo ""

# Cleanup temp files older than 1 day (optional - helps prevent buildup)
echo "Cleaning up old temp files (>1 day old)..."
find "$TMPDIR" -type f -mtime +1 -delete 2>/dev/null || echo "Could not clean temp files (permissions?)"
find "$TMPDIR" -type d -empty -delete 2>/dev/null || true
echo "Cleanup complete"
echo ""
