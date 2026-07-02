#!/bin/bash -ue
plink         --bfile /home/sagemaker-user/GWASTutorial/01_Dataset/1KG.EAS.auto.snp.norm.nodup.split.rare002.common015.missing         --keep-allele-order         --r square         --extract locus_7_134368632.snplist         --out locus_7_134368632
