#!/bin/bash
#SBATCH --job-name=average_prediction_scores         # Job name
#SBATCH --partition=unlimited                     # Partition Name
#SBATCH --mem=120G
#SBATCH --time=7-00:00:00                     # total run time limit (HH:MM:SS)
#SBATCH --output=logs/average_prediction_scores_%A_%a.log  # Standard output with array job ID
#SBATCH --error=logs/average_prediction_scores_%A_%a.err   # Error log with array job ID

# Summary: This script averages the prediction scores and contribution scores across the 5 folds of the ChromBPNet model.

# Load conda environment
source /gs/gsfs0/hpc01/rhel8/apps/conda3/etc/profile.d/conda.sh 

# Define full home path to replace tilde

# Define directories
CONTRIB_INPUT_DIR="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training/outputs/neutrophil_merged/chrombpnet_model_b1.0/contribution_scores_bw"
CONTRIB_OUTPUT_DIR="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training/outputs/neutrophil_merged/chrombpnet_model_b1.0/contribution_scores_bw/averaged_scores"

PRED_INPUT_DIR="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training/outputs/neutrophil_merged/chrombpnet_model_b1.0/prediction_scores_bw"
PRED_OUTPUT_DIR="/gs/gsfs0/shared-lab/greally-lab/David/chromBPnet_analysis/chromBPnet_training/outputs/neutrophil_merged/chrombpnet_model_b1.0/prediction_scores_bw/averaged_scores"
chromsizes="/gs/gsfs0/shared-lab/greally-lab/chynna/osteo_chynna/chromBPnet/indexes/hg38.autosomes.chrom.sizes"

# Create output directories if they don't exist
mkdir -p $CONTRIB_OUTPUT_DIR
mkdir -p $PRED_OUTPUT_DIR
mkdir -p $CONTRIB_OUTPUT_DIR/temp
mkdir -p $PRED_OUTPUT_DIR/temp


# Process contribution scores
echo "Processing contribution scores..."
cd $CONTRIB_INPUT_DIR/fold_0
CONTRIB_FILES=$(ls *.bw)

for FILE in $CONTRIB_FILES; do
    echo "Processing contribution file: $FILE..."

    # Activate wiggletools environment for averaging
    conda activate chrombpnet_wiggletools

    # Use wiggletools to average the files and output in wiggle format
    wiggletools mean \
      $CONTRIB_INPUT_DIR/fold_0/$FILE \
      $CONTRIB_INPUT_DIR/fold_1/$FILE \
      $CONTRIB_INPUT_DIR/fold_2/$FILE \
      $CONTRIB_INPUT_DIR/fold_3/$FILE \
      $CONTRIB_INPUT_DIR/fold_4/$FILE \
      > $CONTRIB_OUTPUT_DIR/${FILE%.bw}.wig

    conda deactivate
    
    echo "Created wiggle file: $CONTRIB_OUTPUT_DIR/${FILE%.bw}.wig"
    
    # Convert this wiggle file to bigWig (instead of bedGraphToBigWig)
    if [ -f "$chromsizes" ]; then
        WIGGLE=$CONTRIB_OUTPUT_DIR/${FILE%.bw}.wig
        BIGWIG="${WIGGLE%.wig}.bw"

        # Activate UCSC environment for conversion
        conda activate chrombpnet_ucsc

        # Convert wiggle to bigWig directly
        wigToBigWig $WIGGLE $chromsizes $BIGWIG
        echo "Created bigWig: $BIGWIG"

        conda deactivate

        # Optionally remove wiggle to save space
        # rm $WIGGLE
    fi
done

# Process prediction scores
echo "Processing prediction scores..."
cd $PRED_INPUT_DIR/fold_0
PRED_FILES=$(ls *.bw)

for FILE in $PRED_FILES; do
    echo "Processing prediction file: $FILE..."

    # Activate wiggletools environment for averaging
    conda activate chrombpnet_wiggletools

    # Use wiggletools to average the files and output in wiggle format
    wiggletools mean \
      $PRED_INPUT_DIR/fold_0/$FILE \
      $PRED_INPUT_DIR/fold_1/$FILE \
      $PRED_INPUT_DIR/fold_2/$FILE \
      $PRED_INPUT_DIR/fold_3/$FILE \
      $PRED_INPUT_DIR/fold_4/$FILE \
      > $PRED_OUTPUT_DIR/${FILE%.bw}.wig

    conda deactivate
    
    echo "Created wiggle file: $PRED_OUTPUT_DIR/${FILE%.bw}.wig"
    
    # Convert this wiggle file to bigWig (compressed) because the output is in wiggle format (uncompressed)
    if [ -f "$chromsizes" ]; then
        WIGGLE=$PRED_OUTPUT_DIR/${FILE%.bw}.wig
        BIGWIG="${WIGGLE%.wig}.bw"

        # Activate UCSC environment for conversion
        conda activate chrombpnet_ucsc

        # Convert wiggle to bigWig directly
        wigToBigWig $WIGGLE $chromsizes $BIGWIG
        echo "Created bigWig: $BIGWIG"

        conda deactivate

        # Optionally remove wiggle to save space
        # rm $WIGGLE
    fi
done


# =====================================================================================
# Convert existing wig files to bigWig using wiggletools and deeptools
# =====================================================================================

echo "Converting existing wig files to bigWig format..."

# Process contribution score wig files
echo "Processing contribution wig files..."
cd $CONTRIB_OUTPUT_DIR
WIG_FILES=$(ls *.wig 2>/dev/null)

if [ -n "$WIG_FILES" ]; then
    for WIG_FILE in $WIG_FILES; do
        echo "Converting $WIG_FILE to bedGraph and then to bigWig..."
        
        # Activate wiggletools environment for conversion
        conda activate chrombpnet_wiggletools

        # Convert wig to bedGraph using wiggletools
        wiggletools write_bg $CONTRIB_OUTPUT_DIR/temp/${WIG_FILE%.wig}.bedGraph $WIG_FILE
        echo "Created bedGraph: $CONTRIB_OUTPUT_DIR/temp/${WIG_FILE%.wig}.bedGraph"

        conda deactivate
        
        # Sort bedGraph file (required for conversion)
        sort -k1,1 -k2,2n $CONTRIB_OUTPUT_DIR/temp/${WIG_FILE%.wig}.bedGraph > \
            $CONTRIB_OUTPUT_DIR/temp/${WIG_FILE%.wig}.sorted.bedGraph
        

        # Activate UCSC environment for bedGraph to bigWig conversion
        conda activate chrombpnet_ucsc

        # Convert bedGraph to bigWig using deeptools
        bedGraphToBigWig $CONTRIB_OUTPUT_DIR/temp/${WIG_FILE%.wig}.sorted.bedGraph \
            $chromsizes \
            $CONTRIB_OUTPUT_DIR/${WIG_FILE%.wig}.bw

        echo "Created bigWig: $CONTRIB_OUTPUT_DIR/${WIG_FILE%.wig}.bw"

        conda deactivate
    
    done
else
    echo "No wig files found in $CONTRIB_OUTPUT_DIR"
fi

# Process prediction score wig files
echo "Processing prediction wig files..."
cd $PRED_OUTPUT_DIR
WIG_FILES=$(ls *.wig 2>/dev/null)

if [ -n "$WIG_FILES" ]; then
    for WIG_FILE in $WIG_FILES; do
        echo "Converting $WIG_FILE to bedGraph and then to bigWig..."
        
        # Activate wiggletools environment for conversion
        conda activate chrombpnet_wiggletools

        # Convert wig to bedGraph using wiggletools
        wiggletools write_bg $PRED_OUTPUT_DIR/temp/${WIG_FILE%.wig}.bedGraph $WIG_FILE
        echo "Created bedGraph: $PRED_OUTPUT_DIR/temp/${WIG_FILE%.wig}.bedGraph"

        conda deactivate
        
        # Sort bedGraph file (required for conversion)
        sort -k1,1 -k2,2n $PRED_OUTPUT_DIR/temp/${WIG_FILE%.wig}.bedGraph > \
            $PRED_OUTPUT_DIR/temp/${WIG_FILE%.wig}.sorted.bedGraph
        
        
        # Activate UCSC environment for bedGraph to bigWig conversion
        conda activate chrombpnet_ucsc

        # Convert bedGraph to bigWig using deeptools
        bedGraphToBigWig $PRED_OUTPUT_DIR/temp/${WIG_FILE%.wig}.sorted.bedGraph \
            $chromsizes \
            $PRED_OUTPUT_DIR/${WIG_FILE%.wig}.bw

        echo "Created bigWig: $PRED_OUTPUT_DIR/${WIG_FILE%.wig}.bw"

        conda deactivate
    done
else
    echo "No wig files found in $PRED_OUTPUT_DIR"
fi

# Clean up temporary files (optional)
# rm -r $CONTRIB_OUTPUT_DIR/temp
# rm -r $PRED_OUTPUT_DIR/temp

echo "All wig files have been converted to bigWig format."
