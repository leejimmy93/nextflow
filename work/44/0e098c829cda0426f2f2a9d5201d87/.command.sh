#!/bin/bash -ue
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
df = pd.read_csv("locus_1_167562605.tsv", sep="\t")

# Load LD matrix
ld = pd.read_csv("locus_1_167562605.ld", sep="\t", header=None)
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
        L = 1,
        n = int(df["N"].mean())
    )

    # Get credible sets
    cs = susieR.susie_get_cs(fit,
                             coverage=0.95,
                             min_abs_corr=0.5,
                             Xcorr=R_df)[0]

    # Get PIP values
    ro.globalenv['fit_temp'] = fit
    pip = ro.r('colMeans(fit_temp$alpha)')

# Process results
df["cs"] = 0
if cs is not ro.NULL:
    n_cs = len(cs)
    for i in range(n_cs):
        cs_index = list(cs[i])
        df.loc[np.array(cs_index)-1, "cs"] = i + 1

df["pip"] = np.array(pip)

# Save results
df.to_csv("finemapping_1_167562605.tsv", sep="\t", index=False)

# Save credible sets summary
with open("credible_sets_1_167562605.txt", "w") as f:
    if cs is not ro.NULL:
        f.write(f"Number of credible sets: {len(cs)}\n\n")
        for i in range(len(cs)):
            cs_index = list(cs[i])
            cs_variants = df.loc[np.array(cs_index)-1, :]
            f.write(f"Credible Set {i+1}:\n")
            f.write(cs_variants[["SNPID", "CHR", "POS", "EA", "NEA", "BETA", "P", "pip"]].to_string())
            f.write("\n\n")
    else:
        f.write("No credible sets identified\n")

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

axes[0].axhline(y=-np.log10(5e-08),
                color='red', linestyle='--', alpha=0.5)
axes[0].set_ylabel('-log10(P)')
axes[0].legend()
axes[0].set_title(f"Fine-mapping results for CHR1:167562605")

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
plt.savefig("plot_1_167562605.png", dpi=300, bbox_inches='tight')
plt.close()
EOF
