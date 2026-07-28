# Image for LD calculation (CALCULATE_LD)
# Force amd64: plink 1.9 has no arm64 bioconda build
FROM --platform=linux/amd64 mambaorg/micromamba:1.5.8

USER root
RUN apt-get update && apt-get install -y \
    procps \
    && rm -rf /var/lib/apt/lists/*

USER $MAMBA_USER

# Install PLINK 1.9
RUN micromamba install -y -n base -c conda-forge -c bioconda \
    plink=1.90b6.21 \
    && micromamba clean --all --yes

ENV PATH="/opt/conda/bin:$PATH"
WORKDIR /work

# Verify plink is available
RUN plink --version
