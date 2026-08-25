#!/bin/bash
#SBATCH -p shared # You select the queue(cluster) here
#SBATCH -c 1                # number of CPU cores to allocate, one per thread, up to 128.
#SBATCH --mem=16G            # memory required, in units of k,M or G, up to 250G.
#SBATCH --gres=tmp:24G       # $TMPDIR space required on each compute node, up to 400G.
#SBATCH -t 01:00:00     # time limit in format dd-hh:mm:ss
#SBATCH --job-name=S17multiqc3 # This name will let you follow your job
#SBATCH --output=../log/S17multiqc3%A_%a.out
#SBATCH --error=../log/S17multiqc3%A_%a.err
#SBATCH --array=1
#Runtime is about 2 minute

#The mapping statistics for all samples can be combined using multiqc as follows:
cd ~/diss/multiqc_report
module load bioinformatics
module load multiqc/1.35
export PYTHONIOENCODING=utf-8 #Set the Python encoding to UTF-8
multiqc --force -n multiqc3 ~/diss/star_output

multiqc --force -n multiqc_all ~/diss
