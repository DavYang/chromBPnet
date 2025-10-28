### Date: 8-12-25

In each directory are indivudal steps for training chromBPnet models and analyzing variants. 

1) data_downloads: This directory is dedicated to downloading fastq files for ATAC-seq results in different blood cell types.
2) nf-core_atac: This directory is dedicated to running nf-core/atac to align fastq files to hg38 and generate bam files (bwa was used for alignment, all other results ignored). Once aligned, bam files are filtered to contain only autosomes to prepare for downstream analysis. 
3) peak_calling: This directory is dedicated to running MACS3 to call ATAC-seq peaks, using settings from the ChromBPNet paper.
4) generate_folds: This directory is dedicated to generating folds for cross-validation.
5) bias_model_training: This directory is dedicated to training the Tn5 bias model. 1 model will be trained for each cell type. 
6) variant_scoring: Dedicated to scoring NCVs using trained chrombpnet models.

