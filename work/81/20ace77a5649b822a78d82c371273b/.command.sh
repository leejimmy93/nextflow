#!/bin/bash -ue
python3 << 'EOF'
import gwaslab as gl
import pandas as pd

# Read summary statistics
df = pd.read_csv("1kgeas.B1.glm.firth", sep="\t")
sumstats = gl.Sumstats(df, fmt="plink2")

# Basic QC
sumstats.basic_check()

# Optional harmonization with reference genome


# Save cleaned data
sumstats.data.to_csv("cleaned_sumstats.tsv", sep="\t", index=False)

# Generate QC report
with open("qc_report.txt", "w") as f:
    f.write(f"Total variants: {len(sumstats.data)}\n")
    f.write(f"Chromosomes: {sorted(sumstats.data['CHR'].unique())}\n")
EOF
