#!/bin/bash -ue
python3 << 'EOF'
import gwaslab as gl
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

# Load cleaned sumstats (already in gwaslab format, skip re-processing)
df = pd.read_csv("cleaned_sumstats.tsv", sep="\t")
sumstats = gl.Sumstats(df, fmt="gwaslab", verbose=False)

# Extract lead variants (convert window size from bp to kb)
window_kb = 500000 / 1000
lead_variants = sumstats.get_lead(sig_level=5e-08,
                                  windowsizekb=window_kb)

# Save lead variants
lead_variants.to_csv("lead_variants.tsv", sep="\t", index=False)

# Create Manhattan plot
sumstats.plot_mqq(save="manhattan.png", dpi=300)
plt.close('all')
EOF
