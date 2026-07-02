# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains Nextflow pipelines for genomics workflows on AWS SageMaker:
- `sarek.ipynb`: [nf-core/sarek](https://nf-co.re/sarek) germline/somatic variant calling pipeline
- `finemapping_susie.nf`: SuSiE-RSS statistical fine-mapping pipeline (built from GWASTutorial notebook)
- `run_finemapping_pipeline.ipynb`: Interactive notebook for running the fine-mapping pipeline

## Environment Setup

The notebook documents a one-time setup sequence that must be run on a fresh SageMaker instance:

1. **Install Java** (OpenJDK 18) to `~/jdk-18` — required by Nextflow
2. **Install Nextflow** via `mamba install -c bioconda nextflow`
3. **Set AWS credentials** as environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`) — these are temporary session credentials and expire
4. **Write Nextflow config** to `/tmp/$USER/config` (see below)

## Nextflow Configuration

The pipeline runs on AWS Batch. The config written to `/tmp/$USER/config`:

```
process {
    executor = 'awsbatch'
    queue = 'nextflow-base-v1'
}
aws {
    region = 'us-east-1'
    batch {
        cliPath = '/root/miniconda/bin/aws'
        jobRole = 'arn:aws:iam::335777049998:role/ecsTaskExecutionRole'
    }
}
```

## Running the Pipeline

From `/tmp/$USER`, with the config file in place:

```sh
nextflow run nf-core/sarek -r 3.5.1 \
  -profile test \
  -c config \
  -with-trace \
  -work-dir s3://darp-dad-repos/RL/nextflow_workdir_test \
  --outdir s3://darp-dad-repos/RL/nextflow_sarek_output_test
```

- `-profile test` uses nf-core's built-in test dataset (no real input data needed)
- `-with-trace` generates a `trace.txt` execution report in the working directory
- Work and output are written to the `s3://darp-dad-repos/RL/` bucket

## Fine-mapping Pipeline (finemapping_susie.nf)

### Overview
Translates the statistical fine-mapping workflow from `/home/sagemaker-user/GWASTutorial/12_fine_mapping/finemapping_susie.ipynb` into a Nextflow pipeline.

**Workflow**: Load GWAS summary stats → QC → Extract lead variants → Define loci → Calculate LD matrices → Run SuSiE fine-mapping → Generate results

### Critical Conda Environment Configuration

**THE PROBLEM**: The pipeline requires specific Python packages (gwaslab, rpy2, susieR) from the `gwas_tutorial` conda environment, but Nextflow defaults to using whatever Python is in PATH.

**SOLUTION THAT WORKS**: Run Nextflow FROM the gwas_tutorial environment
```bash
# Activate the environment with all the tools
conda activate gwas_tutorial

# Install nextflow in this environment if not present
conda install -c bioconda nextflow

# Run pipeline WITHOUT -profile conda
nextflow run finemapping_susie.nf \
  --sumstats /home/sagemaker-user/GWASTutorial/12_fine_mapping/1kgeas.B1.glm.firth \
  --genotype_prefix /home/sagemaker-user/GWASTutorial/01_Dataset/1KG.EAS.auto.snp.norm.nodup.split.rare002.common015.missing \
  --outdir finemapping_results
```

**ALTERNATIVE (still debugging)**: Use `-profile conda` to switch environments
- Config sets `process.conda = '/home/sagemaker-user/.conda/envs/gwas_tutorial'`
- Run with: `nextflow run finemapping_susie.nf -profile conda ...`
- **Issue**: Python scripts wrapped in `python3 << 'EOF' ... EOF` heredocs to ensure correct Python interpreter is used after conda activation
- **Known problem**: Conda environment switching with Nextflow DSL2 can be finicky

### Conda Environments on This System

1. **nextflow-env** (`/home/sagemaker-user/.conda/envs/nextflow-env`)
   - Contains: Nextflow, basic bioinformatics tools
   - Created for: Running Nextflow engine itself
   - **Issue**: Has incompatible gwaslab version (causes `AttributeError: 'DataFrame' object has no attribute 'dtype'`)

2. **gwas_tutorial** (`/home/sagemaker-user/.conda/envs/gwas_tutorial`)
   - Contains: gwaslab (working version), rpy2, susieR, plink, all Python/R packages
   - Created for: GWASTutorial notebooks
   - **This is what pipeline processes need to use**

### Pipeline Structure

**Input Files**:
- `--sumstats`: PLINK2 GWAS summary statistics (`.glm.firth` format)
- `--genotype_prefix`: PLINK binary genotype files prefix (needs .bed/.bim/.fam)

**Key Parameters**:
- `--sig_threshold`: Genome-wide significance (default: 5e-8)
- `--window_size`: Window around lead variants in bp (default: 500000)
- `--L`: Max causal variants per locus (default: 1)
- `--coverage`: Credible set coverage (default: 0.95)

**Processes**:
1. `LOAD_SUMSTATS`: Load and QC GWAS summary statistics using gwaslab
2. `EXTRACT_LEADS`: Identify genome-wide significant loci, create Manhattan plot
3. `DEFINE_LOCI`: Extract variants in ±500kb windows around lead variants
4. `CALCULATE_LD`: Compute LD matrices using PLINK (`--r square`)
5. `RUN_SUSIE`: Fine-mapping with SuSiE-RSS, identify credible sets
6. `SUMMARIZE_RESULTS`: Aggregate results across all loci

**Output Structure**:
```
results/
├── qc/
│   ├── cleaned_sumstats.tsv
│   └── qc_report.txt
├── leads/
│   ├── lead_variants.tsv
│   └── manhattan.png
├── finemapping/
│   ├── finemapping_CHR_POS.tsv
│   ├── plot_CHR_POS.png
│   └── credible_sets_CHR_POS.txt
└── summary/
    ├── all_credible_sets.tsv
    └── summary_report.txt
```

### Nextflow DSL2 Lessons Learned

1. **No executable statements at script level**: `if` statements, `log.info`, etc. must be inside `workflow {}` blocks
2. **Groovy variable interpolation**: Do math in the script language (Python/R), not in Groovy template substitution
   - ❌ Wrong: `windowsizekb=${params.window_size / 1000}` (Groovy tries to divide)
   - ✅ Right: `window_kb = ${params.window_size} / 1000` (Python does the division)
3. **Python shebangs with conda**: 
   - `#!/usr/bin/env python3` gets resolved BEFORE conda activation
   - Solution: Remove shebangs, wrap code in `python3 << 'EOF' ... EOF` heredocs
4. **Conda profile configuration**:
   - Must set `conda.enabled = true` in profile
   - Specify environment: `process.conda = '/path/to/env'`
   - Activate with: `-profile conda`

### Running from Jupyter Notebook

The `run_finemapping_pipeline.ipynb` notebook provides an interactive interface:
- Cell-by-cell execution
- Automatic visualization of results
- Parameter configuration
- **Important**: Add `"-profile", "conda"` to the command list if using conda profile approach

### Debugging Tips

1. **Check which Python is being used**:
   ```bash
   find work -name ".command.err" -type f | xargs ls -t | head -1 | xargs cat
   # Look at the paths in error messages - should be /gwas_tutorial/ not /nextflow-env/
   ```

2. **Verify conda activation in run scripts**:
   ```bash
   find work -name ".command.run" -type f | head -1 | xargs grep "conda activate"
   ```

3. **Clean cache between major changes**:
   ```bash
   rm -rf work/ .nextflow*
   ```

4. **Resume failed runs** (if only fixing downstream issues):
   ```bash
   nextflow run finemapping_susie.nf -resume ...
   ```

## Key Notes

- Nextflow's `-log` flag is not a valid option; logs are written to `.nextflow.log` in the working directory automatically
- The AWS IAM role `ecsTaskExecutionRole` is used by Batch workers; the SageMaker user account does not have `iam:GetRole` permissions to inspect it directly
- Nextflow version in use: 26.04.4
- nf-core/sarek version pinned to: 3.5.1
- Python version in gwas_tutorial: 3.12.13
- Critical: Always verify which conda environment is actually being used by checking error traces
