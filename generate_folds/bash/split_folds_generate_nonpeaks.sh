#!/bin/bash
#SBATCH --job-name=splitfolds              
#SBATCH --partition=normal                      
#SBATCH --mem=16G
#SBATCH --time=4:00:00
#SBATCH --output=logs/splitfolds_%A.out         
#SBATCH --error=logs/splitfolds_%A.err


source /gs/gsfs0/hpc01/rhel8/apps/conda3/etc/profile.d/conda.sh
module load singularity

# singularity pull docker://kundajelab/chrombpnet:latest

# --- Usage ---
if [ "$#" -ne 2 ]; then
    echo "Generates cross-validation folds and non-peak regions for a given sample."
    echo "Usage: $0 <input_peak_file.narrowPeak> <base_output_dir>"
    exit 1
fi

# --- Arguments ---
PEAK_FILE=$1
BASE_OUT_DIR=$2

# --- Static Files ---
GENOME_FILE="/gs/gsfs0/shared-lab/greally-lab/David/reference_genomes/hg38/GRCh38_full_analysis_set_plus_decoy_hla.fa"
CHROM_SIZES="/gs/gsfs0/shared-lab/greally-lab/chynna/osteo_chynna/chromBPnet/indexes/hg38.autosomes.chrom.sizes" 
BLACKLIST_FILE="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/peak_calling/dependency_files/hg38-blacklist.v2.bed.gz" 

# --- Dynamic Paths ---
# Extract a clean sample name from the input file (e.g., "cd14_monocyte_merged_peaks.final.narrowPeak" -> "cd14_monocyte_merged")
SAMPLE_NAME=$(basename "${PEAK_FILE}" | sed -e 's/_peaks.final.narrowPeak//')

# Define sample-specific output directories
OUTPUT_DIR_SPLITS="${BASE_OUT_DIR}/${SAMPLE_NAME}/splits"
OUTPUT_DIR_FOLDS="${BASE_OUT_DIR}/${SAMPLE_NAME}/folds"
mkdir -p "$OUTPUT_DIR_SPLITS"
mkdir -p "$OUTPUT_DIR_FOLDS"

echo "---"
echo "Starting fold generation for sample: ${SAMPLE_NAME}"
echo "Input Peak File: ${PEAK_FILE}"
echo "Output Directory: ${BASE_OUT_DIR}/${SAMPLE_NAME}"
echo "---"

# Predefined test and validation chromosomes for each fold
test_fold0=("chr1" "chr3" "chr6" "chr14")
test_fold1=("chr2" "chr8" "chr9" "chr16")
test_fold2=("chr4" "chr11" "chr12" "chr15")
test_fold3=("chr5" "chr10" "chr18" "chr20" "chr22")
test_fold4=("chr7" "chr13" "chr17" "chr19" "chr21")

val_fold0=("chr8" "chr20")
val_fold1=("chr12" "chr17")
val_fold2=("chr22" "chr7")
val_fold3=("chr6" "chr21")
val_fold4=("chr10" "chr18")



# Loop through each fold (0-4)
for fold_num in {0..4}; do
    echo "Processing fold ${fold_num}..."
    
    # Get the test and validation chromosomes for this fold
    # Convert array to space-separated string for the command arguments
    test_var="test_fold${fold_num}[@]"
    val_var="val_fold${fold_num}[@]"
    
    test_chrs="${!test_var}"
    valid_chrs="${!val_var}"
    
    echo "Test chromosomes: $test_chrs"
    echo "Validation chromosomes: $valid_chrs"
    
    # Define the output path correctly for the splits JSON file
    fold_output_prefix="${OUTPUT_DIR_SPLITS}/fold_${fold_num}"
    
    # Step 1: Generate chromosome splits
    echo "Generating chromosome splits for fold ${fold_num}..."

    singularity exec --bind /gs/gsfs0/shared-lab/greally-lab:/gs/gsfs0/shared-lab/greally-lab \
        chrombpnet_latest.sif chrombpnet prep splits \
        -c "$CHROM_SIZES" \
        -tcr $test_chrs \
        -vcr $valid_chrs \
        -op "$fold_output_prefix"
    
    # Check if the splits generation was successful
    if [ ! -f "${fold_output_prefix}.json" ]; then
        echo "Error: Failed to generate splits for fold ${fold_num}"
        continue
    fi
    
    # Step 2: Prepare nonpeaks using the generated splits file
    echo "Preparing nonpeaks for fold ${fold_num}..."
    
    # Define the final output path for this fold's nonpeaks
    nonpeak_output_prefix="${OUTPUT_DIR_FOLDS}/f${fold_num}_output"

    singularity exec --bind /gs/gsfs0/shared-lab/greally-lab:/gs/gsfs0/shared-lab/greally-lab \
        chrombpnet_latest.sif chrombpnet prep nonpeaks \
        -g "$GENOME_FILE" \
        -p "$PEAK_FILE" \
        -c "$CHROM_SIZES" \
        -fl "${fold_output_prefix}.json" \
        -br "$BLACKLIST_FILE" \
        -o "$nonpeak_output_prefix" #  output BED file prefix to store the gc content of binned genome. 
    
    echo "Completed processing for fold ${fold_num}"
    echo "----------------------------------------"
done

echo "All folds processed successfully"
