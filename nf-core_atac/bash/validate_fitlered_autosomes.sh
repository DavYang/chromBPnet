#!/bin/bash
#SBATCH --time=04:00:00
#SBATCH --partition=unlimited
#SBATCH --mem=16G
#SBATCH --output=logs/validate_autosome_filtering_%j.out
#SBATCH --error=logs/validate_autosome_filtering_%j.err

# Quick validation script to check that BAM files contain only autosomal primary alignments
# Usage: ./validate_autosome_filtering.sh <directory_with_bam_files>
#
module load samtools

set -e

# Check arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <directory_with_bam_files>"
    echo "Validates that all BAM files contain only autosomal primary alignments (chr1-22)"
    exit 1
fi

BAM_DIR="$1"

# Validate directory exists
if [ ! -d "${BAM_DIR}" ]; then
    echo "Error: Directory not found: ${BAM_DIR}"
    exit 1
fi

echo "Validating autosome filtering in directory: ${BAM_DIR}"
echo "=================================================="
echo

# Track overall results
TOTAL_FILES=0
CLEAN_FILES=0
CONTAMINATED_FILES=0

# Process each BAM file
for BAM_FILE in "${BAM_DIR}"/*.bam; do
    # Check if any BAM files exist
    if [ ! -f "${BAM_FILE}" ]; then
        echo "No BAM files found in ${BAM_DIR}"
        exit 0
    fi
    
    TOTAL_FILES=$((TOTAL_FILES + 1))
    FILENAME=$(basename "${BAM_FILE}")
    
    echo "Checking: ${FILENAME}"
    
    # Extract unique chromosomes from primary alignments (column 3)
    # Skip header lines and extract chromosome column
    CHROMOSOMES=$(samtools view "${BAM_FILE}" | cut -f3 | sort -u)
    
    # Check for non-autosomal chromosomes
    NON_AUTOSOMAL=$(echo "${CHROMOSOMES}" | grep -v -E '^chr([1-9]|1[0-9]|2[0-2])$' || true)
    
    if [ -z "${NON_AUTOSOMAL}" ]; then
        echo "  ✓ CLEAN - Only autosomal chromosomes found"
        CLEAN_FILES=$((CLEAN_FILES + 1))
    else
        echo "  ✗ CONTAMINATED - Non-autosomal chromosomes found:"
        echo "${NON_AUTOSOMAL}" | sed 's/^/    /'
        CONTAMINATED_FILES=$((CONTAMINATED_FILES + 1))
    fi
    echo
done

# Summary
echo "=================================================="
echo "VALIDATION SUMMARY"
echo "=================================================="
echo "Total files checked: ${TOTAL_FILES}"
echo "Clean files (autosomal only): ${CLEAN_FILES}"
echo "Contaminated files (contains non-autosomal): ${CONTAMINATED_FILES}"
echo

if [ ${CONTAMINATED_FILES} -eq 0 ]; then
    echo "✓ SUCCESS: All BAM files contain only autosomal primary alignments"
    exit 0
else
    echo "✗ WARNING: ${CONTAMINATED_FILES} file(s) contain non-autosomal chromosomes"
    exit 1
fi
