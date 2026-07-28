# Image for SuSiE fine-mapping (RUN_SUSIE, SUMMARIZE_RESULTS)
FROM mambaorg/micromamba:1.5.8

USER root
RUN apt-get update && apt-get install -y \
    build-essential \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    gfortran \
    procps \
    && rm -rf /var/lib/apt/lists/*

USER $MAMBA_USER

# Install Python, R, and required packages
RUN micromamba install -y -n base -c conda-forge -c bioconda \
    python=3.12 \
    r-base=4.3 \
    pip \
    pandas \
    numpy \
    scipy \
    matplotlib \
    seaborn \
    rpy2 \
    && micromamba clean --all --yes

ENV PATH="/opt/conda/bin:$PATH"

# Install susieR from CRAN
RUN R -e "install.packages('susieR', repos='https://cloud.r-project.org/')"

# Verify installations
RUN python -c "import rpy2; from rpy2.robjects.packages import importr; susieR = importr('susieR'); print('susieR loaded successfully')"

WORKDIR /work
