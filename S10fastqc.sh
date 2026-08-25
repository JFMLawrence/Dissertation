#!/bin/bash
#SBATCH -p shared # You select the queue(cluster) here
#SBATCH -c 1                # number of CPU cores to allocate, one per thread, up to 128.
#SBATCH --mem=2G            # memory required, in units of k,M or G, up to 250G.
#SBATCH --gres=tmp:3G       # $TMPDIR space required on each compute node, up to 400G.
#SBATCH -t 01:00:00     # time limit in format dd-hh:mm:ss
#SBATCH --job-name=S10fastqc # This name will let you follow your job
#SBATCH --output=../log/S10fastqc%A_%a.out
#SBATCH --error=../log/S10fastqc%A_%a.err
#SBATCH --array=1-56
#Runtime about 2 minutes
data_dir=~/diss/fastq
output_dir=~/diss/fastqc
#Check if the output_dir exists. If not, create one.
if [ ! -d $output_dir ]
then
    mkdir $output_dir
fi
cd ${data_dir}

run_names=(""  ERR149430{04..59} )
run_name=${run_names[$SLURM_ARRAY_TASK_ID]}
echo $run_name
module load bioinformatics
module load fastqc/0.12.1
fastqc -o $output_dir -t 1 ${run_name}_1.fastq.gz ${run_name}_2.fastq.gz
