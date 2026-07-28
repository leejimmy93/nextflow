# Image for LD calculation (CALCULATE_LD)
FROM mambaorg/micromamba:1.5.8

USER root
RUN apt-get update && apt-get install -y \
    procps \
    && rm -rf /var/lib/apt/lists/*

USER $MAMBA_USER

# Install PLINK 1.9
RUN micromamba install -y -n base -c bioconda \
    plink=1.90b6.21 \
    && micromamba clean --all --yes

ENV PATH="/opt/conda/bin:$PATH"
WORKDIR /work

# Verify plink is available
RUN plink --version
