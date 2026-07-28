# Base image with Python and R
FROM mambaorg/micromamba:1.5.8

USER root

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Switch to micromamba user
USER $MAMBA_USER

# Create base conda environment with Python and R
RUN micromamba install -y -n base -c conda-forge -c bioconda \
    python=3.12 \
    r-base=4.3 \
    pip \
    && micromamba clean --all --yes

# Set PATH to use base environment
ENV PATH="/opt/conda/bin:$PATH"

WORKDIR /work
