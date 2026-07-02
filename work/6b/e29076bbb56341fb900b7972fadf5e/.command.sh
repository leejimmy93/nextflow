#!/bin/bash -ue
plink         --bfile /home/sagemaker-user/GWASTutorial/01_Dataset/1KG.EAS.auto.snp.norm.nodup.split.rare002.common015.missing         --keep-allele-order         --r square         --extract locus_1_167562605.snplist         --out locus_1_167562605
