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
    r-base=4.4 \
    pip \
    pandas \
    numpy \
    scipy \
    matplotlib \
    seaborn \
    rpy2 \
    && micromamba clean --all --yes

ENV PATH="/opt/conda/bin:$PATH"
ENV LD_LIBRARY_PATH="/opt/conda/lib:$LD_LIBRARY_PATH"

# Install susieR and dependencies from CRAN
RUN R -e "\
  pkgs <- c('Matrix', 'irlba', 'mixsqp', 'susieR'); \
  install.packages(pkgs, repos='https://cloud.r-project.org/', dependencies=TRUE, Ncpus=2); \
  for (p in pkgs) { if (!requireNamespace(p, quietly=TRUE)) stop(paste('Failed to install:', p)) }; \
  message('All packages installed successfully')"

# Verify installations
RUN python -c "import rpy2; from rpy2.robjects.packages import importr; susieR = importr('susieR'); print('susieR loaded successfully')"

WORKDIR /work
