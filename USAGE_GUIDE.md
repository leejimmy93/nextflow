# Fine-mapping Pipeline Usage Guide

## Quick Start (Conda on SageMaker)

### 1. Setup Environment (First Time Only)
```bash
# If you don't have the environment yet, create it:
conda env create -f environment_minimal.yml
conda activate gwas_tutorial

# Install susieR (not available in conda)
R -e "install.packages('susieR', repos='https://cloud.r-project.org/')"
```

### 2. Activate Environment (Subsequent Runs)
```bash
conda activate gwas_tutorial
```

### 3. Run Pipeline
```bash
cd /home/sagemaker-user/nextflow

nextflow run finemapping_susie.nf \
  --sumstats /home/sagemaker-user/GWASTutorial/12_fine_mapping/1kgeas.B1.glm.firth \
  --genotype_prefix /home/sagemaker-user/GWASTutorial/01_Dataset/1KG.EAS.auto.snp.norm.nodup.split.rare002.common015.missing \
  --outdir results
```

### 4. Check Results
```bash
ls -la results/
# results/
# ├── qc/                  # QC reports and cleaned sumstats
# ├── leads/               # Lead variants and Manhattan plot
# ├── finemapping/         # Fine-mapping results per locus
# └── summary/             # Combined results and summary report
```

## Available Pipeline Versions

### 1. Conda Version (Recommended for SageMaker)
**File:** `finemapping_susie.nf`

**Use when:**
- Working on SageMaker directly
- Quick iteration and testing
- Development phase

**Run:**
```bash
conda activate gwas_tutorial
nextflow run finemapping_susie.nf \
  --sumstats <path> \
  --genotype_prefix <path> \
  --outdir results
```

### 2. Docker Version (For Production/Sharing)
**File:** `finemapping_susie_docker.nf`

**Use when:**
- Sharing with collaborators
- Running on AWS Batch at scale
- Need guaranteed reproducibility
- Running on machines without conda setup

**Prerequisites:**
- Docker images built and pushed to ECR (see docker/BUILD_INSTRUCTIONS.md)

**Run:**
```bash
nextflow run finemapping_susie_docker.nf \
  -c nextflow.docker.config \
  --registry YOUR_ECR_REGISTRY/finemapping \
  --sumstats <path> \
  --genotype_prefix <path> \
  --outdir results
```

## Parameters

### Required
- `--sumstats`: GWAS summary statistics file (PLINK2 format)
- `--genotype_prefix`: PLINK binary files prefix (without .bed/.bim/.fam)

### Optional
- `--outdir`: Output directory (default: "results")
- `--sig_threshold`: Genome-wide significance (default: 5e-8)
- `--window_size`: Window around lead variants in bp (default: 500000)
- `--L`: Max causal variants per locus (default: 1)
- `--coverage`: Credible set coverage (default: 0.95)
- `--min_abs_corr`: Min correlation for credible sets (default: 0.5)
- `--ref_genome`: Reference genome FASTA for harmonization (optional)

### Docker-specific
- `--registry`: Docker registry prefix (default: "finemapping")
- `--version`: Docker image version tag (default: "latest")

## Examples

### Basic run with test data
```bash
nextflow run finemapping_susie.nf \
  --sumstats test_data/gwas.tsv \
  --genotype_prefix test_data/genotypes \
  --outdir test_results
```

### Custom parameters
```bash
nextflow run finemapping_susie.nf \
  --sumstats data/gwas.tsv \
  --genotype_prefix data/genotypes \
  --outdir results_custom \
  --sig_threshold 1e-6 \
  --window_size 1000000 \
  --L 3 \
  --coverage 0.99
```

### Resume failed run
```bash
nextflow run finemapping_susie.nf -resume \
  --sumstats data/gwas.tsv \
  --genotype_prefix data/genotypes \
  --outdir results
```

### Run with AWS Batch (Docker version)
```bash
nextflow run finemapping_susie_docker.nf \
  -c nextflow.docker.config \
  -profile awsbatch \
  --registry 335777049998.dkr.ecr.us-east-1.amazonaws.com/finemapping \
  --sumstats s3://bucket/gwas.tsv \
  --genotype_prefix s3://bucket/genotypes \
  --outdir s3://bucket/results \
  -work-dir s3://bucket/work
```

## Troubleshooting

### Conda environment issues
```bash
# Make sure gwas_tutorial environment exists
conda env list

# Reinstall if needed
conda env create -f environment.yml
```

### Nextflow cache issues
```bash
# Clean cache and restart
rm -rf work/ .nextflow*
nextflow run finemapping_susie.nf ...
```

### Memory issues
Edit `nextflow.config` and increase memory:
```groovy
process {
    withName: RUN_SUSIE {
        memory = '32 GB'  // Increase from default 16 GB
    }
}
```

## Output Files

### QC Directory (`results/qc/`)
- `cleaned_sumstats.tsv`: QC'd summary statistics
- `qc_report.txt`: QC metrics

### Leads Directory (`results/leads/`)
- `lead_variants.tsv`: Genome-wide significant lead variants
- `manhattan.png`: Manhattan plot

### Fine-mapping Directory (`results/finemapping/`)
For each locus:
- `finemapping_CHR_POS.tsv`: Fine-mapping results with PIP values
- `plot_CHR_POS.png`: Regional association plot
- `credible_sets_CHR_POS.txt`: Credible set variants

### Summary Directory (`results/summary/`)
- `all_credible_sets.tsv`: All credible set variants combined
- `summary_report.txt`: Summary statistics across all loci

## Migration Path: Conda → Docker

**When you're ready to use Docker:**

1. Build images on your laptop (see `docker/BUILD_INSTRUCTIONS.md`)
2. Push to ECR
3. Switch to Docker version:
   ```bash
   nextflow run finemapping_susie_docker.nf \
     -c nextflow.docker.config \
     --registry YOUR_REGISTRY/finemapping \
     ... (same parameters as conda version)
   ```

The workflow is identical - only the execution environment changes!
