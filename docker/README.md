# Docker Images for Fine-mapping Pipeline

This directory contains Dockerfiles for running the fine-mapping pipeline in containerized environments.

## Image Overview

The pipeline uses three specialized Docker images:

1. **finemapping-gwaslab** - For GWAS statistics processing
   - Used by: `LOAD_SUMSTATS`, `EXTRACT_LEADS`, `DEFINE_LOCI`
   - Contains: Python 3.12, gwaslab, pandas, matplotlib

2. **finemapping-plink** - For LD matrix calculation
   - Used by: `CALCULATE_LD`
   - Contains: PLINK 1.9

3. **finemapping-susie** - For statistical fine-mapping
   - Used by: `RUN_SUSIE`, `SUMMARIZE_RESULTS`
   - Contains: Python 3.12, R 4.3, susieR, rpy2, pandas, matplotlib

## Building Images

### Local Build (for local execution)

```bash
cd docker
./build_all.sh finemapping
```

This creates images named:
- `finemapping-gwaslab:latest`
- `finemapping-plink:latest`
- `finemapping-susie:latest`

### Build for Docker Hub

```bash
cd docker
./build_all.sh <your-dockerhub-username>
./push_all.sh <your-dockerhub-username>
```

Example:
```bash
./build_all.sh johndoe
./push_all.sh johndoe
```

### Build for AWS ECR

First, create ECR repositories:
```bash
aws ecr create-repository --repository-name finemapping-gwaslab --region us-east-1
aws ecr create-repository --repository-name finemapping-plink --region us-east-1
aws ecr create-repository --repository-name finemapping-susie --region us-east-1
```

Then build and push:
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.us-east-1.amazonaws.com

# Build and push
cd docker
./build_all.sh 123456789012.dkr.ecr.us-east-1.amazonaws.com/finemapping
./push_all.sh 123456789012.dkr.ecr.us-east-1.amazonaws.com/finemapping
```

## Running the Pipeline with Docker

### Local execution with Docker

```bash
nextflow run finemapping_susie_docker.nf \
  -c nextflow.docker.config \
  --registry finemapping \
  --sumstats /path/to/sumstats.tsv \
  --genotype_prefix /path/to/genotypes \
  --outdir results_docker
```

### With Docker Hub images

```bash
nextflow run finemapping_susie_docker.nf \
  -c nextflow.docker.config \
  --registry johndoe \
  --sumstats /path/to/sumstats.tsv \
  --genotype_prefix /path/to/genotypes \
  --outdir results_docker
```

### With AWS Batch + ECR

```bash
nextflow run finemapping_susie_docker.nf \
  -c nextflow.docker.config \
  -profile awsbatch \
  --sumstats s3://bucket/sumstats.tsv \
  --genotype_prefix s3://bucket/genotypes \
  --outdir s3://bucket/results \
  -work-dir s3://bucket/work
```

## Testing Images Locally

Test each image individually:

```bash
# Test gwaslab image
docker run --rm finemapping-gwaslab:latest python -c "import gwaslab; print(gwaslab.__version__)"

# Test plink image
docker run --rm finemapping-plink:latest plink --version

# Test susie image
docker run --rm finemapping-susie:latest python -c "from rpy2.robjects.packages import importr; susieR = importr('susieR'); print('susieR loaded')"
```

## Customizing Images

### Adding packages to gwaslab image

Edit `docker/gwaslab/Dockerfile`:
```dockerfile
RUN micromamba install -y -n base -c conda-forge \
    your-package-here \
    && micromamba clean --all --yes
```

### Adding R packages to susie image

Edit `docker/susie/Dockerfile`:
```dockerfile
RUN R -e "install.packages(c('package1', 'package2'), repos='https://cloud.r-project.org/')"
```

## Image Sizes

Approximate sizes:
- **finemapping-gwaslab**: ~1.5 GB
- **finemapping-plink**: ~500 MB
- **finemapping-susie**: ~2.5 GB

## Troubleshooting

### Permission issues

If you encounter permission errors, the Docker containers run as the host user. Ensure:
- Input files are readable by your user
- Output directories are writable by your user

### Out of memory errors

Increase memory allocation in `nextflow.docker.config`:
```groovy
process {
    withName: RUN_SUSIE {
        memory = '32 GB'  // Increase from default 16 GB
    }
}
```

### Container not found

Ensure images are built and available:
```bash
docker images | grep finemapping
```

For remote registries, verify you're logged in:
```bash
docker login  # For Docker Hub
# OR
aws ecr get-login-password --region us-east-1 | docker login ...  # For ECR
```
