#!/bin/bash
#SBATCH --job-name=format_variants
#SBATCH --partition=quick   
#SBATCH --mem=20G
#SBATCH --time=4:00:00
#SBATCH --output=logs/format_variants/format_variants.out
#SBATCH --error=logs/format_variants/format_variants.err

source /gs/gsfs0/hpc01/rhel8/apps/conda3/etc/profile.d/conda.sh
conda activate allele_stacker

python_script="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/variant_scoring/python/format_variants.py"
input_dir="$1"
output_dir="$2"    


mkdir -p $output_dir
python $python_script --input-dir $input_dir --output-dir $output_dir

echo "Conversion complete! Files saved to $output_dir"