#!/bin/bash
#SBATCH --job-name=32_train_bias_model                
#SBATCH --partition=gpu                     
#SBATCH --mem=100G
#SBATCH --gres=gpu
#SBATCH --cpus-per-task=10
#SBATCH --time=2-00:00:00         
#SBATCH --output=logs/train_bias_model_%A.log              
#SBATCH --error=logs/train_bias_model_%A.err

source /gs/gsfs0/hpc01/rhel8/apps/conda3/etc/profile.d/conda.sh
module load singularity

bam_file="$1"
peaks_file="$2"
non_peaks_file="$3"
fold_file="$4"
bias_threshold="$5"
output_dir="$6"
sample_name="$7"

# Define singularity image
singularity_image=/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/generate_folds/chrombpnet_latest.sif
GENOME_FILE="/gs/gsfs0/shared-lab/greally-lab/David/reference_genomes/hg38/GRCh38_full_analysis_set_plus_decoy_hla.fa"
CHROM_SIZES="/gs/gsfs0/shared-lab/greally-lab/chynna/osteo_chynna/chromBPnet/indexes/hg38.autosomes.chrom.sizes" 
BLACKLIST_FILE="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/peak_calling/dependency_files/hg38-blacklist.v2.bed.gz" 

mkdir -p /gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/bias_model_training/outputs/bias_model_f0_b7

# Run singularity with environment isolation
singularity exec --bind /gs/gsfs0/shared-lab/greally-lab:/gs/gsfs0/shared-lab/greally-lab --nv \
  $singularity_image \
  chrombpnet bias pipeline \
  -ibam $bam_file \
  -d "ATAC" \
  -g $GENOME_FILE \
  -c $CHROM_SIZES \
  -p $peaks_file \
  -n $non_peaks_file \
  -fl $fold_file \
  -b $bias_threshold \
  -o $output_dir \
  -fp $sample_name \
  -bs 32
