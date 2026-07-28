# Image for GWAS statistics processing (LOAD_SUMSTATS, EXTRACT_LEADS, DEFINE_LOCI)
FROM mambaorg/micromamba:1.5.8

USER root
RUN apt-get update && apt-get install -y \
    build-essential \
    libcurl4-openssl-dev \
    libssl-dev \
    procps \
    && rm -rf /var/lib/apt/lists/*

USER $MAMBA_USER

# Install gwaslab and dependencies
RUN micromamba install -y -n base -c conda-forge -c bioconda \
    python=3.12 \
    pip \
    pandas \
    numpy \
    scipy \
    matplotlib \
    seaborn \
    && micromamba clean --all --yes

# Install gwaslab via pip (not available in conda)
RUN pip install --no-cache-dir gwaslab

ENV PATH="/opt/conda/bin:$PATH"
WORKDIR /work

# Test that gwaslab imports correctly
RUN python -c "import gwaslab; print(f'gwaslab version: {gwaslab.__version__}')"
