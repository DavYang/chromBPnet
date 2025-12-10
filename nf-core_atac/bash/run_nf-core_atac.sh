#!/bin/bash
#SBATCH --job-name=nf-core_atac
#SBATCH --output=logs/nf-core_atac_%A_%a.out
#SBATCH --error=logs/nf-core_atac_%A_%a.err
#SBATCH --time=2-00:00:00
#SBATCH --partition=normal  
#SBATCH --mem=16G
#SBATCH --nodes=1
#SBATCH --ntasks=1

# srun --partition=normal --mem=64G --time=48:00:00 --pty bash

source /gs/gsfs0/hpc01/rhel8/apps/conda3/etc/profile.d/conda.sh
conda activate nextflow
# module load nextflow
module load singularity
# module unload java
module load java/jdk-18.0.2


input_file="$1"
outdir="$2"
nextflow run nf-core/atacseq \
    -profile singularity \
    --input $input_file \
    --outdir $outdir \
    --genome GRCh38 \
    -params-file /gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/nf-core_atac/params.yaml \
    -c /gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/nf-core_atac/nextflow.config \
    -r 2.1.2 