#!/bin/bash
#SBATCH -p shared # You select the queue(cluster) here
#SBATCH -c 24                # number of CPU cores to allocate, one per thread, up to 128.
#SBATCH --mem=48G            # memory required, in units of k,M or G, up to 250G.
#SBATCH --gres=tmp:72G       # $TMPDIR space required on each compute node, up to 400G.
#SBATCH -t 03:00:00     # time limit in format dd-hh:mm:ss
#SBATCH --job-name=S15star_index # This name will let you follow your job
#SBATCH --output=../log/S15star_index_%A_%a.out
#SBATCH --error=../log/S15star_index_%A_%a.err
#SBATCH --array=1
#Run-time is about 21 minutes
fa_dir=~/diss/genome
index_dir=$fa_dir/starIndex
if [ ! -d $index_dir ]
then
    mkdir $index_dir
fi
module load bioinformatics
module load star/2.7.11b
STAR --version
STAR \
--runThreadN 24 \
--runMode genomeGenerate \
--genomeDir $index_dir \
--genomeFastaFiles ${fa_dir}/Homo_sapiens.GRCh38.dna.primary_assembly.fa \
--sjdbGTFfile ${fa_dir}/Homo_sapiens.GRCh38.116.gtf  \
--sjdbOverhang 150 \
--genomeSAindexNbases 14
