#!/bin/bash
#SBATCH -p shared # You select the queue(cluster) here
#SBATCH -c 1                # number of CPU cores to allocate, one per thread, up to 128.
#SBATCH --mem=2G            # memory required, in units of k,M or G, up to 250G.
#SBATCH --gres=tmp:3G       # $TMPDIR space required on each compute node, up to 400G.
#SBATCH -t 01:00:00     # time limit in format dd-hh:mm:ss
#SBATCH --job-name=S14multiqc2 # This name will let you follow your job
#SBATCH --output=../log/S14multiqc2%A_%a.out
#SBATCH --error=../log/S14multiqc2%A_%a.err
#SBATCH --array=1
out_dir=~/diss/multiqc_report
if [ ! -d $out_dir ]
then
  mkdir $out_dir
fi

module load bioinformatics
module load  multiqc/1.35
export PYTHONIOENCODING=utf-8 #Set the Python encoding to UTF-8
#multiqc  --help # to display the help page
multiqc --force \
  --outdir ${out_dir} \
  --filename multiqc2 \
  ~/diss/trimmed
