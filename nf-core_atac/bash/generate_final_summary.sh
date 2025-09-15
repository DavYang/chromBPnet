#!/bin/bash

#
# Generate final summary after parallel BAM filtering and merging
# This script should be run after all array jobs have completed
#

set -e

# --- Usage ---
if [ "$#" -ne 1 ]; then
    echo "Generate final summary after parallel BAM filtering and merging"
    echo "Usage: $0 <output_dir>"
    echo ""
    echo "This script will:"
    echo "  1. Collect summaries from all processed samples"
    echo "  2. Generate a comprehensive final summary"
    echo "  3. Create a merged directory with all final BAM files"
    exit 1
fi

# --- Arguments ---
OUT_DIR=$1

# --- Validation ---
if [ ! -d "${OUT_DIR}" ]; then
    echo "Error: Output directory not found: ${OUT_DIR}"
    exit 1
fi

echo "Generating final summary for: ${OUT_DIR}"

# --- Create Final Summary ---
FINAL_SUMMARY="${OUT_DIR}/final_read_summary.txt"
echo "Final Read Summary for Autosome-Filtered BAMs" > "${FINAL_SUMMARY}"
echo "Generated on $(date)" >> "${FINAL_SUMMARY}"
echo "Output directory: ${OUT_DIR}" >> "${FINAL_SUMMARY}"
echo "" >> "${FINAL_SUMMARY}"

# --- Collect Individual Sample Summaries ---
echo "Collecting individual sample summaries..."

# Section for individual filtered replicates
echo "--- Individual Filtered Replicates ---" >> "${FINAL_SUMMARY}"
echo "======================================" >> "${FINAL_SUMMARY}"

TOTAL_INDIVIDUAL_READS=0
INDIVIDUAL_COUNT=0

for SAMPLE_DIR in "${OUT_DIR}"/*/; do
    if [ -d "${SAMPLE_DIR}" ] && [ "$(basename "${SAMPLE_DIR}")" != "logs" ] && [ "$(basename "${SAMPLE_DIR}")" != "merged" ]; then
        SAMPLE_NAME=$(basename "${SAMPLE_DIR}")
        echo "Processing sample: ${SAMPLE_NAME}"
        
        for BAM_FILE in "${SAMPLE_DIR}"/*.bam; do
            if [ -f "${BAM_FILE}" ] && [[ "$(basename "${BAM_FILE}")" != *"_merged.bam" ]]; then
                FILENAME="${SAMPLE_NAME}/$(basename "${BAM_FILE}")"
                READ_COUNT=$(samtools view -c "${BAM_FILE}")
                printf "%-55s %'d reads\n" "${FILENAME}:" "${READ_COUNT}" >> "${FINAL_SUMMARY}"
                TOTAL_INDIVIDUAL_READS=$((TOTAL_INDIVIDUAL_READS + READ_COUNT))
                INDIVIDUAL_COUNT=$((INDIVIDUAL_COUNT + 1))
            fi
        done
    fi
done

echo "" >> "${FINAL_SUMMARY}"
echo "Total individual replicates: ${INDIVIDUAL_COUNT}" >> "${FINAL_SUMMARY}"
echo "Total reads in individual replicates: ${TOTAL_INDIVIDUAL_READS}" >> "${FINAL_SUMMARY}"
echo "" >> "${FINAL_SUMMARY}"

# Section for merged samples
echo "--- Merged Samples ---" >> "${FINAL_SUMMARY}"
echo "=====================" >> "${FINAL_SUMMARY}"

TOTAL_MERGED_READS=0
MERGED_COUNT=0

for SAMPLE_DIR in "${OUT_DIR}"/*/; do
    if [ -d "${SAMPLE_DIR}" ] && [ "$(basename "${SAMPLE_DIR}")" != "logs" ] && [ "$(basename "${SAMPLE_DIR}")" != "merged" ]; then
        SAMPLE_NAME=$(basename "${SAMPLE_DIR}")
        MERGED_BAM="${SAMPLE_DIR}/${SAMPLE_NAME}_merged.bam"
        
        if [ -f "${MERGED_BAM}" ]; then
            FILENAME="${SAMPLE_NAME}/${SAMPLE_NAME}_merged.bam"
            READ_COUNT=$(samtools view -c "${MERGED_BAM}")
            printf "%-55s %'d reads\n" "${FILENAME}:" "${READ_COUNT}" >> "${FINAL_SUMMARY}"
            TOTAL_MERGED_READS=$((TOTAL_MERGED_READS + READ_COUNT))
            MERGED_COUNT=$((MERGED_COUNT + 1))
        fi
    fi
done

echo "" >> "${FINAL_SUMMARY}"
echo "Total merged samples: ${MERGED_COUNT}" >> "${FINAL_SUMMARY}"
echo "Total reads in merged samples: ${TOTAL_MERGED_READS}" >> "${FINAL_SUMMARY}"
echo "" >> "${FINAL_SUMMARY}"

# --- Create Merged Directory ---
MERGED_DIR="${OUT_DIR}/merged"
mkdir -p "${MERGED_DIR}"

echo "Creating merged directory with all final BAM files..."

for SAMPLE_DIR in "${OUT_DIR}"/*/; do
    if [ -d "${SAMPLE_DIR}" ] && [ "$(basename "${SAMPLE_DIR}")" != "logs" ] && [ "$(basename "${SAMPLE_DIR}")" != "merged" ]; then
        SAMPLE_NAME=$(basename "${SAMPLE_DIR}")
        MERGED_BAM="${SAMPLE_DIR}/${SAMPLE_NAME}_merged.bam"
        
        if [ -f "${MERGED_BAM}" ]; then
            echo "Copying ${SAMPLE_NAME}_merged.bam to merged directory"
            cp "${MERGED_BAM}" "${MERGED_DIR}/"
            cp "${MERGED_BAM}.bai" "${MERGED_DIR}/"
        fi
    fi
done

# --- Summary Statistics ---
echo "--- Summary Statistics ---" >> "${FINAL_SUMMARY}"
echo "=========================" >> "${FINAL_SUMMARY}"
echo "Total samples processed: ${MERGED_COUNT}" >> "${FINAL_SUMMARY}"
echo "Total individual replicates: ${INDIVIDUAL_COUNT}" >> "${FINAL_SUMMARY}"
echo "Average replicates per sample: $(echo "scale=2; ${INDIVIDUAL_COUNT} / ${MERGED_COUNT}" | bc -l 2>/dev/null || echo "N/A")" >> "${FINAL_SUMMARY}"
echo "Total reads in individual replicates: ${TOTAL_INDIVIDUAL_READS}" >> "${FINAL_SUMMARY}"
echo "Total reads in merged samples: ${TOTAL_MERGED_READS}" >> "${FINAL_SUMMARY}"

if [ ${TOTAL_INDIVIDUAL_READS} -gt 0 ]; then
    READ_RETENTION=$(echo "scale=2; ${TOTAL_MERGED_READS} * 100 / ${TOTAL_INDIVIDUAL_READS}" | bc -l 2>/dev/null || echo "N/A")
    echo "Read retention rate: ${READ_RETENTION}%" >> "${FINAL_SUMMARY}"
fi

echo ""
echo "Final summary saved to: ${FINAL_SUMMARY}"
echo "Merged BAM files copied to: ${MERGED_DIR}"
echo "Summary generation complete!"
