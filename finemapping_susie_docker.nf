#!/usr/bin/env nextflow

/*
 * Fine-mapping workflow using SuSiE-RSS - DOCKER VERSION
 * Based on statistical genetics fine-mapping approach
 *
 * This version uses Docker containers for each process.
 * Each process has its own specialized container with required dependencies.
 */

nextflow.enable.dsl=2

// Parameters
params.sumstats = null              // GWAS summary statistics file
params.genotype_prefix = null       // PLINK bfile prefix (without .bed/.bim/.fam)
params.outdir = "results"           // Output directory
params.sig_threshold = 5e-8         // Genome-wide significance threshold
params.window_size = 500000         // Window size around lead variant (bp)
params.coverage = 0.95              // Credible set coverage
params.min_abs_corr = 0.5          // Minimum correlation for credible sets
params.L = 1                        // Maximum number of causal variants
params.ref_genome = null            // Optional: reference genome FASTA for harmonization

// Docker image registry prefix (change to your registry)
params.registry = "finemapping"     // e.g., "myusername" for Docker Hub or "123456789012.dkr.ecr.us-east-1.amazonaws.com/finemapping" for ECR
params.version = "latest"           // Docker image version tag

/*
 * Process 1: Load and QC summary statistics
 */
process LOAD_SUMSTATS {
    container "${params.registry}/gwaslab:${params.version}"
    publishDir "${params.outdir}/qc", mode: 'copy'

    input:
    path sumstats

    output:
    path "cleaned_sumstats.tsv", emit: cleaned
    path "qc_report.txt", emit: report

    script:
    def harmonize_cmd = params.ref_genome ?
        "sumstats.harmonize(basic_check=False, ref_seq='${params.ref_genome}')" :
        ""

    """
    python3 << 'EOF'
    import gwaslab as gl
    import pandas as pd

    # Read summary statistics
    df = pd.read_csv("${sumstats}", sep="\\t")
    sumstats = gl.Sumstats(df, fmt="plink2")

    # Basic QC
    sumstats.basic_check()

    # Optional harmonization with reference genome
    ${harmonize_cmd}

    # Save cleaned data
    sumstats.data.to_csv("cleaned_sumstats.tsv", sep="\\t", index=False)

    # Generate QC report
    with open("qc_report.txt", "w") as f:
        f.write(f"Total variants: {len(sumstats.data)}\\n")
        f.write(f"Chromosomes: {sorted(sumstats.data['CHR'].unique())}\\n")
    EOF
    """
}

/*
 * Process 2: Extract lead variants (genome-wide significant loci)
 */
process EXTRACT_LEADS {
    container "${params.registry}/gwaslab:${params.version}"
    publishDir "${params.outdir}/leads", mode: 'copy'

    input:
    path cleaned_sumstats

    output:
    path "lead_variants.tsv", emit: leads
    path "manhattan.png", emit: plot

    script:
    """
    python3 << 'EOF'
    import gwaslab as gl
    import pandas as pd
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt

    # Load cleaned sumstats (already in gwaslab format, skip re-processing)
    df = pd.read_csv("${cleaned_sumstats}", sep="\\t")
    sumstats = gl.Sumstats(df, fmt="gwaslab", verbose=False)

    # Extract lead variants (convert window size from bp to kb)
    window_kb = ${params.window_size} / 1000
    lead_variants = sumstats.get_lead(sig_level=${params.sig_threshold},
                                      windowsizekb=window_kb)

    # Save lead variants
    lead_variants.to_csv("lead_variants.tsv", sep="\\t", index=False)

    # Create Manhattan plot
    sumstats.plot_mqq(save="manhattan.png", dpi=300)
    plt.close('all')
    EOF
    """
}

/*
 * Process 3: Define locus regions around each lead variant
 */
process DEFINE_LOCI {
    container "${params.registry}/gwaslab:${params.version}"
    tag "CHR${chrom}:${pos}"

    input:
    path cleaned_sumstats
    tuple val(chrom), val(pos), val(snpid)

    output:
    tuple val(chrom), val(pos), path("locus_${chrom}_${pos}.tsv"), path("locus_${chrom}_${pos}.snplist"), emit: locus

    script:
    def window = params.window_size as Integer
    def start = (pos as Integer) - window
    def end = (pos as Integer) + window

    """
    python3 << 'EOF'
    import gwaslab as gl
    import pandas as pd
    import numpy as np

    # Load cleaned sumstats (already in gwaslab format, skip re-processing)
    df = pd.read_csv("${cleaned_sumstats}", sep="\\t")
    sumstats = gl.Sumstats(df, fmt="gwaslab", verbose=False)

    # Filter to locus region
    locus = sumstats.filter_value('CHR==${chrom} & POS>${start} & POS<${end}')

    # Convert OR to BETA if needed
    if 'BETA' not in locus.data.columns:
        locus.fill_data(to_fill=["BETA"])

    # Save locus data
    locus.data.to_csv("locus_${chrom}_${pos}.tsv", sep="\\t", index=False)

    # Save SNP list for LD calculation
    locus.data["SNPID"].to_csv("locus_${chrom}_${pos}.snplist",
                                sep="\\t", index=False, header=False)
    EOF
    """
}

/*
 * Process 4: Calculate LD matrix using PLINK
 */
process CALCULATE_LD {
    container "${params.registry}/plink:${params.version}"
    tag "CHR${chrom}:${pos}"

    input:
    tuple val(chrom), val(pos), path(locus_tsv), path(snplist)
    path genotype_bed
    path genotype_bim
    path genotype_fam

    output:
    tuple val(chrom), val(pos), path(locus_tsv), path("locus_${chrom}_${pos}.ld"), emit: locus_with_ld

    script:
    def prefix = params.genotype_prefix

    """
    plink \
        --bfile ${params.genotype_prefix} \
        --keep-allele-order \
        --r square \
        --extract ${snplist} \
        --out locus_${chrom}_${pos}
    """
}

/*
 * Process 5: Run SuSiE fine-mapping
 */
process RUN_SUSIE {
    container "${params.registry}/susie:${params.version}"
    tag "CHR${chrom}:${pos}"
    publishDir "${params.outdir}/finemapping", mode: 'copy', pattern: "*.{tsv,png}"

    input:
    tuple val(chrom), val(pos), path(locus_tsv), path(ld_matrix)

    output:
    tuple val(chrom), val(pos), path("finemapping_${chrom}_${pos}.tsv"), emit: results
    path "plot_${chrom}_${pos}.png", emit: plot
    path "credible_sets_${chrom}_${pos}.txt", emit: credible_sets

    script:
    """
    python3 << 'EOF'

    import pandas as pd
    import numpy as np
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import seaborn as sns
    import rpy2.robjects as ro
    from rpy2.robjects.packages import importr
    from rpy2.robjects import numpy2ri
    from rpy2.robjects.conversion import localconverter

    # Load locus data
    df = pd.read_csv("${locus_tsv}", sep="\\t")

    # Load LD matrix
    ld = pd.read_csv("${ld_matrix}", sep="\\t", header=None)
    R_df = ld.values

    # Import SuSiE
    susieR = importr('susieR')

    # Run SuSiE fine-mapping
    ro.r('set.seed(123)')

    with localconverter(ro.default_converter + numpy2ri.converter):
        fit = susieR.susie_rss(
            bhat = df["BETA"].values,
            shat = df["SE"].values,
            R = R_df,
            L = ${params.L},
            n = int(df["N"].mean())
        )

        # Get credible sets
        cs = susieR.susie_get_cs(fit,
                                 coverage=${params.coverage},
                                 min_abs_corr=${params.min_abs_corr},
                                 Xcorr=R_df)[0]

        # Get PIP values
        ro.globalenv['fit_temp'] = fit
        pip = ro.r('colMeans(fit_temp\$alpha)')

    # Process results
    df["cs"] = 0
    if cs is not ro.NULL:
        n_cs = len(cs)
        for i in range(n_cs):
            cs_index = list(cs[i])
            df.loc[np.array(cs_index)-1, "cs"] = i + 1

    df["pip"] = np.array(pip)

    # Save results
    df.to_csv("finemapping_${chrom}_${pos}.tsv", sep="\\t", index=False)

    # Save credible sets summary
    with open("credible_sets_${chrom}_${pos}.txt", "w") as f:
        if cs is not ro.NULL:
            f.write(f"Number of credible sets: {len(cs)}\\n\\n")
            for i in range(len(cs)):
                cs_index = list(cs[i])
                cs_variants = df.loc[np.array(cs_index)-1, :]
                f.write(f"Credible Set {i+1}:\\n")
                f.write(cs_variants[["SNPID", "CHR", "POS", "EA", "NEA", "BETA", "P", "pip"]].to_string())
                f.write("\\n\\n")
        else:
            f.write("No credible sets identified\\n")

    # Create regional plot
    df["MLOG10P"] = -np.log10(df["P"])

    fig, axes = plt.subplots(nrows=2, sharex=True, figsize=(15, 7),
                             height_ratios=(4, 1))

    # Top panel: -log10(P) values
    lead_idx = df["P"].idxmin()
    axes[0].scatter(df["POS"], df["MLOG10P"],
                    c=ld.iloc[lead_idx, :]**2, cmap='RdYlBu_r')

    # Highlight credible set variants
    if df["cs"].sum() > 0:
        for cs_num in df["cs"].unique():
            if cs_num > 0:
                axes[0].scatter(df.loc[df["cs"]==cs_num, "POS"],
                               df.loc[df["cs"]==cs_num, "MLOG10P"],
                               marker='o', s=80, facecolors='none',
                               edgecolors='black', linewidths=2,
                               label=f"Credible set {cs_num}")

    axes[0].axhline(y=-np.log10(${params.sig_threshold}),
                    color='red', linestyle='--', alpha=0.5)
    axes[0].set_ylabel('-log10(P)')
    axes[0].legend()
    axes[0].set_title(f"Fine-mapping results for CHR${chrom}:${pos}")

    # Bottom panel: PIP values
    axes[1].scatter(df["POS"], df["pip"],
                    c=ld.iloc[lead_idx, :]**2, cmap='RdYlBu_r')

    if df["cs"].sum() > 0:
        for cs_num in df["cs"].unique():
            if cs_num > 0:
                axes[1].scatter(df.loc[df["cs"]==cs_num, "POS"],
                               df.loc[df["cs"]==cs_num, "pip"],
                               marker='o', s=80, facecolors='none',
                               edgecolors='black', linewidths=2)

    axes[1].set_xlabel('Position (bp)')
    axes[1].set_ylabel('PIP')
    axes[1].set_ylim([-0.05, 1.05])

    plt.tight_layout()
    plt.savefig("plot_${chrom}_${pos}.png", dpi=300, bbox_inches='tight')
    plt.close()
    EOF
    """
}

/*
 * Process 6: Summarize all results
 */
process SUMMARIZE_RESULTS {
    container "${params.registry}/susie:${params.version}"
    publishDir "${params.outdir}/summary", mode: 'copy'

    input:
    path finemapping_results

    output:
    path "all_credible_sets.tsv"
    path "summary_report.txt"

    script:
    """
    python3 << 'EOF'

    import pandas as pd
    import glob

    # Collect all finemapping results
    all_files = glob.glob("finemapping_*.tsv")

    all_results = []
    credible_variants = []

    for f in all_files:
        df = pd.read_csv(f, sep="\\t")
        all_results.append(df)

        # Extract variants in credible sets
        cs_variants = df[df["cs"] > 0]
        if len(cs_variants) > 0:
            credible_variants.append(cs_variants)

    # Save all credible set variants
    if credible_variants:
        all_cs = pd.concat(credible_variants, ignore_index=True)
        all_cs = all_cs.sort_values(["CHR", "POS"])
        all_cs.to_csv("all_credible_sets.tsv", sep="\\t", index=False)
    else:
        pd.DataFrame().to_csv("all_credible_sets.tsv", sep="\\t", index=False)

    # Create summary report
    with open("summary_report.txt", "w") as f:
        f.write("Fine-mapping Summary Report\\n")
        f.write("="*60 + "\\n\\n")
        f.write(f"Total loci analyzed: {len(all_files)}\\n")

        if credible_variants:
            f.write(f"Total credible sets identified: {all_cs['cs'].nunique()}\\n")
            f.write(f"Total variants in credible sets: {len(all_cs)}\\n\\n")

            f.write("Top variants by PIP:\\n")
            top_pip = all_cs.nlargest(10, "pip")[["SNPID", "CHR", "POS", "cs", "pip", "P"]]
            f.write(top_pip.to_string())
        else:
            f.write("No credible sets identified\\n")
    """
}

/*
 * Main workflow
 */
workflow {
    // Print parameter summary
    log.info """
    =================================================================
    Fine-mapping with SuSiE-RSS - Nextflow Pipeline (Docker Version)
    =================================================================
    Summary statistics  : ${params.sumstats}
    Genotype prefix     : ${params.genotype_prefix}
    Output directory    : ${params.outdir}
    Significance level  : ${params.sig_threshold}
    Window size         : ${params.window_size} bp
    Credible set cover  : ${params.coverage}
    Min correlation     : ${params.min_abs_corr}
    Max causal (L)      : ${params.L}
    Reference genome    : ${params.ref_genome ?: 'Not provided'}
    -----------------------------------------------------------------
    Docker registry     : ${params.registry}
    Docker version tag  : ${params.version}
    =================================================================
    """

    // Validate required parameters
    if (!params.sumstats) {
        error "Missing required parameter: --sumstats"
    }
    if (!params.genotype_prefix) {
        error "Missing required parameter: --genotype_prefix"
    }

    // Input channels
    sumstats_ch = Channel.fromPath(params.sumstats)

    // Collect genotype files once
    genotype_bed = Channel.fromPath("${params.genotype_prefix}.bed").first()
    genotype_bim = Channel.fromPath("${params.genotype_prefix}.bim").first()
    genotype_fam = Channel.fromPath("${params.genotype_prefix}.fam").first()

    // Step 1: Load and QC summary statistics
    LOAD_SUMSTATS(sumstats_ch)

    // Step 2: Extract lead variants
    EXTRACT_LEADS(LOAD_SUMSTATS.out.cleaned)

    // Step 3: Create channel of lead variants for parallel processing
    lead_variants_ch = EXTRACT_LEADS.out.leads
        .splitCsv(header: true, sep: '\t')
        .map { row -> tuple(row.CHR, row.POS.toInteger(), row.SNPID) }
        .view { chrom, pos, snpid -> "Processing lead variant: CHR${chrom}:${pos} (${snpid})" }

    // Step 4: Define locus regions - use each to replicate cleaned_sumstats for each lead variant
    DEFINE_LOCI(LOAD_SUMSTATS.out.cleaned.first(), lead_variants_ch)

    // Step 5: Calculate LD matrices
    CALCULATE_LD(
        DEFINE_LOCI.out.locus,
        genotype_bed,
        genotype_bim,
        genotype_fam
    )

    // Step 6: Run SuSiE fine-mapping for each locus
    RUN_SUSIE(CALCULATE_LD.out.locus_with_ld)

    // Step 7: Summarize all results
    SUMMARIZE_RESULTS(RUN_SUSIE.out.results.map { it[2] }.collect())
}
