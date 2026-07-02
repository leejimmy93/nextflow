# Fine-mapping Pipeline with SuSiE-RSS

A Nextflow pipeline for statistical fine-mapping of GWAS summary statistics using Sum of Single Effects Regression (SuSiE).

## Overview

This pipeline performs:
1. **Quality control** of GWAS summary statistics
2. **Lead variant extraction** at genome-wide significant loci
3. **LD matrix calculation** for each locus using genotype data
4. **Fine-mapping** with SuSiE-RSS to identify credible sets
5. **Visualization** of results with regional plots

## Requirements

### Software Dependencies
- Nextflow (≥22.0)
- Python 3.8+
- R (≥4.0) with susieR package
- PLINK (1.9 or 2.0)

### Python Packages
```bash
pip install gwaslab rpy2 pandas numpy matplotlib seaborn
```

### R Packages
```r
install.packages("susieR")
```

## Quick Start

### 1. Prepare Input Files

You need:
- **GWAS summary statistics** in PLINK2 format (.glm.linear or .glm.firth)
- **Genotype data** in PLINK binary format (.bed/.bim/.fam)

### 2. Run the Pipeline

```bash
nextflow run finemapping_susie.nf \
  --sumstats gwas_results.glm.firth \
  --genotype_prefix genotypes/1KG.EAS \
  --outdir results \
  --sig_threshold 5e-8 \
  --window_size 500000 \
  --L 1
```

### 3. Using Parameters File

Create a JSON parameter file:
```json
{
  "sumstats": "data/gwas_results.glm.firth",
  "genotype_prefix": "data/1KG.EAS",
  "outdir": "results",
  "sig_threshold": 5e-8,
  "window_size": 500000,
  "L": 1
}
```

Run with:
```bash
nextflow run finemapping_susie.nf -params-file params.json
```

## Parameters

### Required
- `--sumstats`: Path to GWAS summary statistics file
- `--genotype_prefix`: Prefix for PLINK binary files (without .bed/.bim/.fam)

### Optional
- `--outdir`: Output directory (default: 'results')
- `--sig_threshold`: Genome-wide significance threshold (default: 5e-8)
- `--window_size`: Window size around lead variants in bp (default: 500000)
- `--coverage`: Credible set coverage probability (default: 0.95)
- `--min_abs_corr`: Minimum absolute correlation for credible sets (default: 0.5)
- `--L`: Maximum number of causal variants per locus (default: 1)
- `--ref_genome`: Path to reference genome FASTA for harmonization (optional)

## Output Structure

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
├── summary/
│   ├── all_credible_sets.tsv
│   └── summary_report.txt
└── reports/
    ├── execution_report.html
    ├── timeline.html
    └── trace.txt
```

## Understanding the Output

### Credible Sets
- **PIP (Posterior Inclusion Probability)**: Probability that a variant is causal
- **cs column**: Credible set membership (0 = not in any set, 1+ = set number)
- Variants with high PIP (>0.5) are more likely to be causal

### Regional Plots
- **Top panel**: -log10(P) values colored by LD with lead variant
- **Bottom panel**: PIP values from fine-mapping
- Black circles highlight variants in credible sets

## Advanced Usage

### Running on AWS Batch

```bash
nextflow run finemapping_susie.nf \
  -profile awsbatch \
  --sumstats s3://bucket/gwas_results.tsv \
  --genotype_prefix s3://bucket/genotypes/1KG.EAS \
  --outdir s3://bucket/results \
  -work-dir s3://bucket/work
```

### Using Docker

```bash
nextflow run finemapping_susie.nf \
  -profile docker \
  --sumstats gwas_results.tsv \
  --genotype_prefix genotypes/1KG.EAS
```

### Using Conda

```bash
nextflow run finemapping_susie.nf \
  -profile conda \
  --sumstats gwas_results.tsv \
  --genotype_prefix genotypes/1KG.EAS
```

### Resume from Checkpoint

If the pipeline fails or is interrupted:
```bash
nextflow run finemapping_susie.nf -resume
```

## Execution Profiles

The pipeline includes several execution profiles:

- `standard`: Local execution (default)
- `cluster`: SLURM cluster execution
- `awsbatch`: AWS Batch execution
- `docker`: Use Docker containers
- `conda`: Use Conda environments

Combine profiles:
```bash
nextflow run finemapping_susie.nf -profile cluster,conda
```

## Expected Runtime

- **Small dataset** (~100K variants, 1 locus): ~5 minutes
- **Medium dataset** (~1M variants, 5 loci): ~30 minutes
- **Large dataset** (~10M variants, 50 loci): ~3-5 hours

Time scales with:
- Number of genome-wide significant loci
- Size of LD windows
- Number of variants per locus

## Troubleshooting

### Issue: No credible sets identified
**Solution**: Try adjusting parameters:
- Increase `--L` (allow more causal variants)
- Decrease `--coverage` (lower credible set threshold)
- Decrease `--min_abs_corr` (allow weaker LD structure)

### Issue: PLINK command not found
**Solution**: Install PLINK and ensure it's in your PATH:
```bash
conda install -c bioconda plink
```

### Issue: R package susieR not found
**Solution**: Install susieR in R:
```r
install.packages("susieR")
```

### Issue: Memory errors in SuSiE
**Solution**: Increase memory allocation in nextflow.config:
```groovy
process {
    withName: RUN_SUSIE {
        memory = '32 GB'
    }
}
```

## Citation

If you use this pipeline, please cite:

- **SuSiE**: Wang, G. et al. (2020). A simple new approach to variable selection in regression, with application to genetic fine mapping. *Journal of the Royal Statistical Society: Series B*, 82(5), 1273-1300.

- **Nextflow**: Di Tommaso, P. et al. (2017). Nextflow enables reproducible computational workflows. *Nature Biotechnology*, 35(4), 316-319.

## Example Data

Test the pipeline with example data from the GWASTutorial:

```bash
# Using data from the notebook
nextflow run finemapping_susie.nf \
  --sumstats /home/sagemaker-user/GWASTutorial/12_fine_mapping/1kgeas.B1.glm.firth \
  --genotype_prefix /home/sagemaker-user/GWASTutorial/01_Dataset/1KG.EAS.auto.snp.norm.nodup.split.rare002.common015.missing \
  --outdir test_results
```

## Notes

- The pipeline processes each locus **in parallel** for efficiency
- LD matrices are calculated from your genotype data, not external references
- Fine-mapping results depend heavily on LD structure and sample ancestry
- Always validate credible sets with functional data or replication studies

## Support

For issues or questions:
- Open an issue on GitHub
- Check the Nextflow documentation: https://www.nextflow.io/docs/latest/
- Check SuSiE documentation: https://stephenslab.github.io/susieR/
