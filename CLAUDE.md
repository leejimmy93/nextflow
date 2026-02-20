# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains a Jupyter notebook (`sarek.ipynb`) for running the [nf-core/sarek](https://nf-co.re/sarek) germline/somatic variant calling pipeline using Nextflow on AWS, executed from an AWS SageMaker instance.

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

## Key Notes

- Nextflow's `-log` flag is not a valid option; logs are written to `.nextflow.log` in the working directory automatically
- The AWS IAM role `ecsTaskExecutionRole` is used by Batch workers; the SageMaker user account does not have `iam:GetRole` permissions to inspect it directly
- Nextflow version in use: 25.10.4
- nf-core/sarek version pinned to: 3.5.1
