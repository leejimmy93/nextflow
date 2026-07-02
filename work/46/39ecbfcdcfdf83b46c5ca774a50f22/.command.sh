#!/bin/bash -ue
python3 << 'EOF'
import gwaslab as gl
import pandas as pd
import numpy as np

# Load cleaned sumstats (already in gwaslab format, skip re-processing)
df = pd.read_csv("cleaned_sumstats.tsv", sep="\t")
sumstats = gl.Sumstats(df, fmt="gwaslab", verbose=False)

# Filter to locus region
locus = sumstats.filter_value('CHR==20 & POS>42258834 & POS<43258834')

# Convert OR to BETA if needed
if 'BETA' not in locus.data.columns:
    locus.fill_data(to_fill=["BETA"])

# Save locus data
locus.data.to_csv("locus_20_42758834.tsv", sep="\t", index=False)

# Save SNP list for LD calculation
locus.data["SNPID"].to_csv("locus_20_42758834.snplist",
                            sep="\t", index=False, header=False)
EOF
