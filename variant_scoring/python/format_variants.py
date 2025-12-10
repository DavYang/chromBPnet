#!/usr/bin/env python3
"""
Convert variant TSV files to chromBPnet format.

This script reads TSV files with standard variant columns and converts them
to chromBPnet format: ['chr', 'pos', 'allele1', 'allele2', 'variant_id']
"""

import os
import pandas as pd
import argparse
from pathlib import Path


def convert_tsv_to_chrombpnet(input_file, output_file):
    """
    Convert a single TSV file to chromBPnet format.
    
    Args:
        input_file (str): Path to input TSV file
        output_file (str): Path to output TSV file
    """
    # Read the TSV file
    df = pd.read_csv(input_file, sep='\t')
    
    # Check if required columns exist
    required_cols = ['CHROM', 'POS', 'REF', 'ALT', 'ID']
    missing_cols = [col for col in required_cols if col not in df.columns]
    if missing_cols:
        raise ValueError(f"Missing required columns in {input_file}: {missing_cols}")
    
    # Create chromBPnet format dataframe
    chrombpnet_df = pd.DataFrame({
        'chr': df['CHROM'],
        'pos': df['POS'],
        'allele1': df['REF'],
        'allele2': df['ALT'],
        'variant_id': df['ID']
    })
    
    # Ensure chromosome has 'chr' prefix
    chrombpnet_df['chr'] = chrombpnet_df['chr'].astype(str).apply(
        lambda x: x if x.startswith('chr') else f'chr{x}'
    )
    
    # Write to output file
    chrombpnet_df.to_csv(output_file, sep='\t', index=False)
    print(f"Converted {input_file} -> {output_file} ({len(chrombpnet_df)} variants)")


def main():
    parser = argparse.ArgumentParser(description='Convert variant TSVs to chromBPnet format')
    parser.add_argument('--input-dir', required=True, 
                       help='Directory containing input TSV files')
    parser.add_argument('--output-dir', default='chrombpnet_formatted',
                       help='Output directory for formatted files (default: chrombpnet_formatted)')
    parser.add_argument('--pattern', default='*.tsv',
                       help='File pattern to match (default: *.tsv)')
    
    args = parser.parse_args()
    
    # Create output directory
    output_dir = Path(args.output_dir)
    output_dir.mkdir(exist_ok=True)
    
    input_dir = Path(args.input_dir)
    if not input_dir.exists():
        raise FileNotFoundError(f"Input directory does not exist: {input_dir}")
    
    # Find all TSV files
    tsv_files = list(input_dir.glob(args.pattern))
    if not tsv_files:
        print(f"No {args.pattern} files found in {input_dir}")
        return
    
    print(f"Found {len(tsv_files)} TSV files to convert:")
    for tsv_file in tsv_files:
        print(f"  - {tsv_file.name}")
    
    # Convert each file
    for tsv_file in tsv_files:
        output_file = output_dir / f"{tsv_file.stem}_chrombpnet.tsv"
        try:
            convert_tsv_to_chrombpnet(tsv_file, output_file)
        except Exception as e:
            print(f"Error converting {tsv_file}: {e}")
    
    print(f"\nConversion complete! Files saved to {output_dir}")


if __name__ == "__main__":
    main()
