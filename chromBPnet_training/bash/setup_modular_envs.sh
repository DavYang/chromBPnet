#!/bin/bash
#SBATCH --job-name=setup_modular_envs
#SBATCH --output=logs/setup_modular_envs.log
#SBATCH --error=logs/setup_modular_envs.error
#SBATCH --time=04:00:00
#SBATCH --partition=quick
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB

# Modular environment setup for chromBPnet analysis
# Creates separate environments to avoid dependency conflicts

echo "Setting up modular chromBPnet environments..."

# Load conda
source /gs/gsfs0/hpc01/rhel8/apps/conda3/etc/profile.d/conda.sh

# Function to create environment if it doesn't exist
create_env_if_not_exists() {
    local env_name=$1
    local python_version=$2

    if conda env list | grep -q "^${env_name} "; then
        echo "Environment ${env_name} already exists, skipping creation..."
    else
        echo "Creating environment: ${env_name}"
        conda create -n ${env_name} python=${python_version} -y
    fi
}

# Create separate environments
echo "Creating Python environment..."
create_env_if_not_exists "chrombpnet_python" "3.9"

echo "Creating wiggletools environment..."
create_env_if_not_exists "chrombpnet_wiggletools" "3.9"

echo "Creating UCSC tools environment..."
create_env_if_not_exists "chrombpnet_ucsc" "3.9"

# Setup Python environment
echo "Setting up Python environment..."
conda activate chrombpnet_python
conda install -c conda-forge numpy h5py -y
pip install hdf5plugin
conda deactivate

# Setup wiggletools environment
echo "Setting up wiggletools environment..."
conda activate chrombpnet_wiggletools
conda install -c bioconda wiggletools -y
conda install -c bioconda htslib -y

# Fix library dependencies for wiggletools
cd $CONDA_PREFIX/lib
if [ ! -f libhts.so.1 ]; then
    ln -sf libhts.so.* libhts.so.1 2>/dev/null || echo "Could not create HTS symlink"
fi
if [ ! -f libgsl.so.19 ]; then
    ln -sf libgsl.so.* libgsl.so.19 2>/dev/null || echo "Could not create GSL symlink"
fi
conda deactivate

# Setup UCSC environment
echo "Setting up UCSC environment..."
conda activate chrombpnet_ucsc

# Try conda first
conda install -c bioconda ucsc-bedgraphtobigwig ucsc-wigtobigwig -y 2>/dev/null || {
    echo "Conda UCSC install failed, installing manually..."
    # Manual installation fallback
    mkdir -p $CONDA_PREFIX/bin/ucsc_tools
    cd $CONDA_PREFIX/bin/ucsc_tools
    wget -q http://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/wigToBigWig
    wget -q http://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/bedGraphToBigWig
    chmod +x wigToBigWig bedGraphToBigWig
    cd $CONDA_PREFIX/bin
    ln -sf ucsc_tools/wigToBigWig .
    ln -sf ucsc_tools/bedGraphToBigWig .
}
conda deactivate

echo "Modular environments setup complete!"
echo ""
echo "Available environments:"
echo "  - chrombpnet_python: for Python scripts (numpy, h5py, hdf5plugin)"
echo "  - chrombpnet_wiggletools: for wiggletools operations"
echo "  - chrombpnet_ucsc: for UCSC genome browser tools"
echo ""
echo "To test:"
echo "  conda activate chrombpnet_wiggletools && wiggletools --help"
echo "  conda activate chrombpnet_ucsc && wigToBigWig"
