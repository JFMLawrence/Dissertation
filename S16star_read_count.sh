#!/bin/bash
#SBATCH -p shared
#SBATCH -c 24
#SBATCH --mem=48G
#SBATCH --gres=tmp:72G
#SBATCH -t 12:00:00
#SBATCH --job-name=S16_star_read_count
#SBATCH --output=../log/S16_star_read_count_%A_%a.out
#SBATCH --error=../log/S16_star_read_count_%A_%a.err
#SBATCH --array=1-48

module load bioinformatics
module load star/2.7.11b

fa_dir=~/diss/genome
index_dir=$fa_dir/starIndex
data_dir=~/diss/trimmed
output_dir=~/diss/star_output

mkdir -p $output_dir

# ALL ERR samples from PRJEB89260
sample_names=(
ERR14943004 ERR14943005 ERR14943006 ERR14943007 ERR14943008 ERR14943009
ERR14943010 ERR14943011 ERR14943012 ERR14943013 ERR14943014 ERR14943015
ERR14943016 ERR14943017 ERR14943018 ERR14943019 ERR14943020 ERR14943021
ERR14943022 ERR14943023 ERR14943024 ERR14943025 ERR14943026 ERR14943027
ERR14943028 ERR14943030 ERR14943031 ERR14943032 ERR14943033 ERR14943034
ERR14943035 ERR14943036 ERR14943038 ERR14943039 ERR14943040 ERR14943041
ERR14943043 ERR14943044 ERR14943045 ERR14943046 ERR14943047 ERR14943048
ERR14943049 ERR14943050 ERR14943051 ERR14943056 ERR14943057 ERR14943059
)

# SLURM arrays start at 1, bash arrays at 0
sample=${sample_names[$SLURM_ARRAY_TASK_ID - 1]}
echo "Processing sample: $sample"

STAR \
  --genomeDir $index_dir \
  --runThreadN 24 \
  --readFilesCommand zcat \
  --readFilesIn \
    ${data_dir}/${sample}_R1.trimmed.fastq.gz \
    ${data_dir}/${sample}_R2.trimmed.fastq.gz \
  --outFileNamePrefix ${output_dir}/${sample} \
  --outSAMtype BAM SortedByCoordinate \
  --quantMode GeneCounts

