# Nextflow Learning Guide - Local Execution (No AWS Required)

## Overview
All nf-core pipelines support **local execution** - no AWS Batch needed! They default to running on your current machine.

---

## 🎯 Best Pipelines for Learning (Easy → Advanced)

### **1. nf-core/demo** ⭐ BEST FOR BEGINNERS
**Why:** Specifically designed for training/workshops
**Resources:** 1 CPU, <1GB RAM, ~5 minutes
**What it does:** Minimal example showing Nextflow patterns

```bash
# Install
nextflow pull nf-core/demo

# Run with test data (all data auto-downloaded)
nextflow run nf-core/demo \
    -profile test,conda \
    --outdir results_demo

# What you'll learn:
# - Basic pipeline structure
# - Channel operations
# - Process definitions
# - Output publishing
```

**Files to study after running:**
- `~/.nextflow/assets/nf-core/demo/main.nf` - Main workflow
- `~/.nextflow/assets/nf-core/demo/workflows/demo.nf` - Workflow logic
- `~/.nextflow/assets/nf-core/demo/modules/` - Individual processes

---

### **2. nf-core/fastqc** ⭐ SIMPLE & PRACTICAL
**Why:** Single-purpose QC pipeline, easy to understand
**Resources:** 2 CPUs, 4GB RAM, ~10 minutes
**What it does:** Quality control for sequencing reads

```bash
# Install
nextflow pull nf-core/fastqc

# Run with test data
nextflow run nf-core/fastqc \
    -profile test,conda \
    --outdir results_fastqc

# What you'll learn:
# - File handling with channels
# - MultiQC report generation
# - Publishing strategies
```

---

### **3. nf-core/methylseq** (Already on your system's wishlist)
**Why:** Mid-complexity, well-documented
**Resources:** 4 CPUs, 8GB RAM, ~30 minutes
**What it does:** DNA methylation analysis (bisulfite sequencing)

```bash
nextflow pull nf-core/methylseq

nextflow run nf-core/methylseq \
    -profile test,conda \
    --outdir results_methylseq

# What you'll learn:
# - Branching workflows
# - Conditional execution
# - Multiple alignment strategies
```

---

### **4. nf-core/rnaseq** (Already installed!)
**Why:** Production-grade but has excellent test profile
**Resources:** 2-6 CPUs, 6GB RAM, ~45 minutes
**What it does:** RNA-seq quantification pipeline

```bash
# Already on your system! Just run:
cd /home/sagemaker-user/inari-soy-germplasm-GRM

nextflow run nf-core/rnaseq \
    -profile test,conda \
    --outdir results_rnaseq \
    --skip_multiqc

# What you'll learn:
# - Complex multi-step workflows
# - Subworkflows
# - Skip flags and conditional logic
# - Multiple quantification tools
```

**Study these files:**
```bash
# Main workflow entry
cat ~/.nextflow/assets/nf-core/rnaseq/workflows/rnaseq.nf | less

# Key subworkflows
ls ~/.nextflow/assets/nf-core/rnaseq/subworkflows/local/

# Process modules
ls ~/.nextflow/assets/nf-core/rnaseq/modules/nf-core/
```

---

## 📚 Learning Path

### **Week 1: Basics with nf-core/demo**
1. Run the test profile
2. Read `main.nf` - understand the structure
3. Explore `work/` directory - see how Nextflow stages files
4. Check `.nextflow.log` - understand execution order
5. Modify a process (e.g., change a parameter) and re-run with `-resume`

**Key concepts:**
- Processes
- Channels
- Work directory
- Resume feature

---

### **Week 2: Intermediate with nf-core/rnaseq**
1. Run test profile successfully
2. Study the workflow structure:
   ```bash
   # Visualize the DAG
   nextflow run nf-core/rnaseq \
       -profile test,conda \
       --outdir test_rnaseq \
       -with-dag flowchart.html
   ```
3. Examine key processes:
   - `modules/nf-core/fastqc/main.nf` - Quality control
   - `modules/nf-core/salmon/quant/main.nf` - Quantification
4. Try modifying parameters:
   ```bash
   nextflow run nf-core/rnaseq \
       -profile test,conda \
       --pseudo_aligner salmon \
       --skip_alignment \
       --outdir results_salmon_only
   ```

**Key concepts:**
- Subworkflows
- Module reuse
- Skip parameters
- DAG visualization
- Profile inheritance

---

### **Week 3: Advanced - Custom Pipeline**
Create your own simple pipeline using patterns from rnaseq:

```bash
mkdir -p ~/my_first_pipeline
cd ~/my_first_pipeline

# Create basic structure
mkdir -p modules/local workflows conf
```

**Create `main.nf`:**
```groovy
#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// Include workflow
include { MY_WORKFLOW } from './workflows/my_workflow'

// Entry point
workflow {
    MY_WORKFLOW()
}
```

**Create `workflows/my_workflow.nf`:**
```groovy
// Your VCF filtering workflow inspired by Build_GRM
include { BCFTOOLS_VIEW } from '../modules/local/bcftools_view'
include { BCFTOOLS_STATS } from '../modules/local/bcftools_stats'

workflow MY_WORKFLOW {
    // Create input channel
    vcf_ch = Channel.fromPath(params.vcf)
    
    // Filter VCF
    BCFTOOLS_VIEW(vcf_ch)
    
    // Generate stats
    BCFTOOLS_STATS(BCFTOOLS_VIEW.out.vcf)
}
```

**Study existing modules for templates:**
```bash
# Copy and modify an existing module
cp ~/.nextflow/assets/nf-core/rnaseq/modules/nf-core/fastqc/main.nf \
   modules/local/my_module.nf
```

---

## 🔧 Essential Nextflow Commands

```bash
# List installed pipelines
nextflow list

# Pull/update a pipeline
nextflow pull nf-core/demo

# Run with resume (restart from last successful step)
nextflow run nf-core/demo -profile test,conda -resume

# Clean work directory (free up space)
nextflow clean -f

# View run history
nextflow log

# Get detailed run info
nextflow log <run_name> -f script,hash,name,status,exit,duration

# Generate execution reports
nextflow run nf-core/demo \
    -profile test,conda \
    -with-report report.html \
    -with-timeline timeline.html \
    -with-dag dag.svg
```

---

## 📊 Profile Comparison: Local vs AWS

### **Local Executor (What you'll use for learning)**
```groovy
// In nextflow.config or via -profile
process {
    executor = 'local'
    cpus = 4
    memory = '8.GB'
}
```

**Characteristics:**
- ✅ No AWS setup needed
- ✅ Free (uses your instance)
- ✅ Fast startup
- ✅ Great for learning/testing
- ❌ Limited by instance resources
- ❌ No auto-scaling

### **AWS Batch Executor (For production)**
```groovy
process {
    executor = 'awsbatch'
    queue = 'my-batch-queue'
}

aws {
    region = 'us-east-1'
    batch.cliPath = '/usr/local/bin/aws'
}
```

**When to switch:**
- Processing >100 samples
- Need >128GB RAM for some tasks
- Want cost optimization with Spot
- Long-running jobs (>6 hours)

---

## 🎓 Recommended Study Order

1. **nf-core/demo** (1 day)
   - Understand basic structure
   - Learn channel operations
   
2. **nf-core/fastqc** (2 days)
   - See real bioinformatics tools
   - Study MultiQC integration

3. **nf-core/rnaseq** (1 week)
   - Complex workflows
   - Subworkflows and modules
   - Conditional logic
   
4. **Build your own** (2 weeks)
   - Recreate Build_GRM pipeline in Nextflow
   - Use modules from nf-core
   - Add your R visualization

---

## 🔍 Debugging Tips

### **Check process execution:**
```bash
# Find work directory for a failed process
nextflow log <run_name> -f hash,name,status | grep FAILED

# Inspect that directory
cd work/<hash_from_above>
cat .command.sh    # Script that was run
cat .command.out   # Stdout
cat .command.err   # Stderr
cat .command.log   # Nextflow wrapper log
```

### **Test a single process:**
```bash
# Enter the work directory and run manually
cd work/ab/cd1234...
bash .command.sh
```

### **Enable debug mode:**
```bash
nextflow run nf-core/demo -profile test,conda --outdir results -with-trace
```

---

## 📖 Key Documentation

- **Nextflow docs:** https://nextflow.io/docs/latest/
- **nf-core guidelines:** https://nf-co.re/docs/usage/getting_started/introduction
- **Channel operators:** https://nextflow.io/docs/latest/operator.html
- **Process directives:** https://nextflow.io/docs/latest/process.html

---

## 💡 Pro Tips

1. **Always use `-resume`** when developing - saves hours of re-computation
2. **Study `work/` directories** - they show exactly what Nextflow did
3. **Use `-with-dag`** - visualizing the workflow helps understanding
4. **Start with test profiles** - they're designed to run in <10 minutes
5. **Read module code** - nf-core modules are production-quality templates
6. **Join nf-core Slack** - Amazing community for questions

---

## 🚀 Next Steps After Learning

Once comfortable, you could:

1. **Convert Build_GRM to Nextflow modules:**
   - `BCFTOOLS_VIEW` module for filtering
   - `BCFTOOLS_SORT` module
   - `TASSEL_KINSHIP` module
   - `R_CIRCOS_PLOT` module

2. **Integrate with your GxEdit pipeline:**
   - Create a unified workflow
   - Add preprocessing steps
   - Automate the full GRM generation

3. **Scale to AWS Batch** when needed:
   - Process 1000+ soybean lines
   - Run in parallel across chromosomes
   - Use Spot instances for cost savings

---

## ⚠️ Common Gotchas for Beginners

1. **Conda can be slow** on first run (downloads packages)
   - Solution: Use `-resume` for subsequent runs
   
2. **Work directory grows large**
   - Solution: `nextflow clean -f` regularly
   
3. **Local executor blocks on CPU-heavy tasks**
   - Solution: Use `maxForks` to limit parallelism
   
4. **Relative paths break**
   - Solution: Always use absolute paths in config files
   
5. **Resume doesn't work after code changes**
   - This is correct behavior! Only resumes unchanged processes

---

## 🎯 Your First Exercise

Run this complete learning sequence:

```bash
cd /home/sagemaker-user/inari-soy-germplasm-GRM

# 1. Install demo pipeline
nextflow pull nf-core/demo

# 2. Run it
nextflow run nf-core/demo \
    -profile test,conda \
    --outdir results_demo \
    -with-report demo_report.html \
    -with-dag demo_dag.svg

# 3. Study the files
ls -lh results_demo/
cat ~/.nextflow/assets/nf-core/demo/main.nf
ls -lh work/

# 4. Open the report
# Download demo_report.html to your local machine and open in browser

# 5. Try resume (should complete instantly)
nextflow run nf-core/demo \
    -profile test,conda \
    --outdir results_demo \
    -resume

# You'll see: "[100%] 5 of 5, cached: 5 ✔"
```

---

**Happy Learning! 🚀**

All these pipelines work locally with `-profile conda` - no AWS required!
