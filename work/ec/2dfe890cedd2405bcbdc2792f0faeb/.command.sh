#!/bin/bash -ue
python3 << 'EOF'

import pandas as pd
import glob

# Collect all finemapping results
all_files = glob.glob("finemapping_*.tsv")

all_results = []
credible_variants = []

for f in all_files:
    df = pd.read_csv(f, sep="\t")
    all_results.append(df)

    # Extract variants in credible sets
    cs_variants = df[df["cs"] > 0]
    if len(cs_variants) > 0:
        credible_variants.append(cs_variants)

# Save all credible set variants
if credible_variants:
    all_cs = pd.concat(credible_variants, ignore_index=True)
    all_cs = all_cs.sort_values(["CHR", "POS"])
    all_cs.to_csv("all_credible_sets.tsv", sep="\t", index=False)
else:
    pd.DataFrame().to_csv("all_credible_sets.tsv", sep="\t", index=False)

# Create summary report
with open("summary_report.txt", "w") as f:
    f.write("Fine-mapping Summary Report\n")
    f.write("="*60 + "\n\n")
    f.write(f"Total loci analyzed: {len(all_files)}\n")

    if credible_variants:
        f.write(f"Total credible sets identified: {all_cs['cs'].nunique()}\n")
        f.write(f"Total variants in credible sets: {len(all_cs)}\n\n")

        f.write("Top variants by PIP:\n")
        top_pip = all_cs.nlargest(10, "pip")[["SNPID", "CHR", "POS", "cs", "pip", "P"]]
        f.write(top_pip.to_string())
    else:
        f.write("No credible sets identified\n")
