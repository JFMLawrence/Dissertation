#!/bin/bash
#SBATCH -p shared
#SBATCH -c 4
#SBATCH --mem=8G
#SBATCH --gres=tmp:12G
#SBATCH -t 01:00:00
#SBATCH --job-name=S13fastp
#SBATCH --output=../log/S13fastp%A_%a.out
#SBATCH --error=../log/S13fastp%A_%a.err
#SBATCH --array=1-48

data_dir=~/diss/fastq
output_dir=~/diss/trimmed

mkdir -p $output_dir
cd ${data_dir}

sample_names=(ERR14943004 ERR14943005 ERR14943006 ERR14943007 ERR14943008 ERR14943009 \
              ERR14943010 ERR14943011 ERR14943012 ERR14943013 ERR14943014 ERR14943015 \
              ERR14943016 ERR14943017 ERR14943018 ERR14943019 ERR14943020 ERR14943021 \
              ERR14943022 ERR14943023 ERR14943024 ERR14943025 ERR14943026 ERR14943027 \
              ERR14943028 ERR14943030 ERR14943031 ERR14943032 ERR14943033 ERR14943034 \
              ERR14943035 ERR14943036 ERR14943038 ERR14943039 ERR14943040 ERR14943041 \
              ERR14943043 ERR14943044 ERR14943045 ERR14943046 ERR14943047 ERR14943048 \
              ERR14943049 ERR14943050 ERR14943051 ERR14943056 ERR14943057 ERR14943059)

sample=${sample_names[$SLURM_ARRAY_TASK_ID - 1]}
echo "Processing sample: $sample"

module load bioinformatics
module load fastp/1.0.1

fastp \
  -i ${sample}_1.fastq.gz \
  -I ${sample}_2.fastq.gz \
  -o ${output_dir}/${sample}_R1.trimmed.fastq.gz \
  -O ${output_dir}/${sample}_R2.trimmed.fastq.gz \
  --html ${output_dir}/${sample}.fastp.html \
  --json ${output_dir}/${sample}.fastp.json \
  --thread 4

