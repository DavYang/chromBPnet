#!/bin/bash
#SBATCH --job-name=download-SRA
#SBATCH --output=logs/download_SRA_%A_%a.out
#SBATCH --error=logs/download_SRA_%A_%a.err
#SBATCH --time=2-00:00:00
#SBATCH --partition=normal  
#SBATCH --mem=16G
#SBATCH --nodes=1
#SBATCH --ntasks=1


export PATH=/gs/gsfs0/shared-lab/greally-lab/David/software/sratoolkit.3.2.1-alma_linux64/bin:$PATH

SRA_RUN_ID="$1"

prefetch "$SRA_RUN_ID" # downloads the SRA file for this sample
vdb-validate "$SRA_RUN_ID" # validates the SRA file
fasterq-dump "$SRA_RUN_ID" --outdir ./"$SRA_RUN_ID"/ # downloads the FASTQ files for this sample
gzip "$SRA_RUN_ID"/*.fastq # compress the FASTQ files
