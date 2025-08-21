#!/bin/bash
#SBATCH --job-name=download_dependencies
#SBATCH --output=logs/download_dependencies.out
#SBATCH --error=logs/download_dependencies.err
#SBATCH --time=04:00:00
#SBATCH --partition=quick
#SBATCH --mem=16G


source /gs/gsfs0/hpc01/rhel8/apps/conda3/etc/profile.d/conda.sh

conda create -n chromBPnet_DY python=3.8
conda activate chromBPnet_DY

conda install -y -c conda-forge -c bioconda samtools bedtools ucsc-bedgraphtobigwig pybigwig meme

echo "installing pip..."
conda install anaconda::pip 

echo "installing chrombpnet..."
pip install chrombpnet

echo "Installation complete."


