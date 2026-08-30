## GWAS Manhattan Plot & Candidate Gene Mapping

# Install Packages
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager")
}

# CRAN and Bioconductor packages used 
packages <- c(
  "data.table",   
  "dplyr",        
  "ggplot2",      
  "ggrepel",      
  "GenomicRanges",
  "ensembldb",    
  "EnsDb.Hsapiens.v75" 
)

bioc_packages <- c("GenomicRanges", "ensembldb", "EnsDb.Hsapiens.v75")

# Install any missing packages 
for (p in packages) {
  if (!requireNamespace(p, quietly = TRUE)) {
    if (p %in% bioc_packages) {
      BiocManager::install(p)
    } else {
      install.packages(p)
    }
  }
}

library(data.table)
library(dplyr)
library(ggplot2)
library(ggrepel)
library(GenomicRanges)
library(ensembldb)
library(EnsDb.Hsapiens.v75)


# Input Parameters
input_file <- "GCST90205183_buildGRCh37.tsv.gz"   

output_gene_file <- "significant_genes.csv"                   
output_plot_file <- "manhattan_GWAS_labeled.png"     

pvalue_threshold  <- 5e-8    
max_gene_distance <- 100000  

chrom_levels <- c(as.character(1:22), "X")  


# Load and Clean GWAS Data
gwas <- fread(input_file)

# Confirm the columns we depend on downstream are actually present
required_cols <- c("p_value", "chromosome", "base_pair_location")
stopifnot(all(required_cols %in% colnames(gwas)))

# Drop any rows missing the core fields needed for QC / plotting / mapping
gwas <- gwas[!is.na(p_value) & !is.na(chromosome) & !is.na(base_pair_location)]


# GWAS Quality Control

## Value sanity/confirmation check
cat("Columns present:", all(required_cols %in% names(gwas)), "\n")
cat("Any p-values <= 0?", any(gwas$p_value <= 0), "\n")
cat("Any p-values > 1?", any(gwas$p_value > 1), "\n")

## Duplicate SNP check (only possible if an rsID column exists)
if ("rsid" %in% names(gwas)) {
  dup_snps <- gwas[duplicated(gwas$rsid)]
  cat("Duplicated rsIDs:", nrow(dup_snps), "\n")
} else {
  cat("No rsID column found; skipping duplicate SNP check.\n")
}

## QQ plot: observed vs. expected -log10(p)
observed <- sort(gwas$p_value)
expected <- ppoints(length(observed))

qq_df <- data.frame(
  expected = -log10(expected),
  observed = -log10(observed))

qq_plot <- ggplot(qq_df, aes(expected, observed)) +
  geom_point(size = 1, alpha = 0.6) +
  geom_abline(intercept = 0, slope = 1, colour = "red") +
  theme_minimal() +
  labs(title = "GWAS QQ Plot", x = "Expected -log10(p)", y = "Observed -log10(p)")

ggsave("GWAS_QQ_plot.png", qq_plot, width = 7, height = 5, dpi = 300)

## Genomic inflation factor (lambda GC)
lambda_gc <- median(qchisq(1 - observed, 1)) / qchisq(0.5, 1)
cat("Genomic inflation factor (lambda GC):", round(lambda_gc, 3), "\n")


# Standardise Chromosome Labels & Build Cumulative Genomic Position

# Harmonise chromosome naming: strip any "chr" prefix, and recode "23" as "X"
gwas[, chromosome := gsub("^chr", "", chromosome)]
gwas[chromosome == "23", chromosome := "X"]

gwas_std <- gwas[, .(
  chrom = as.character(chromosome),
  pos   = as.numeric(base_pair_location),
  pval  = p_value
)]

# Cumulative chromosome offsets, so all chromosomes can share one continuous
# x-axis in the Manhattan plot
chrom_sizes <- gwas_std %>%
  mutate(chrom = factor(chrom, levels = chrom_levels)) %>%
  group_by(chrom) %>%
  summarise(max_pos = max(pos, na.rm = TRUE), .groups = "drop") %>%
  arrange(chrom) %>%
  mutate(pos_add = lag(cumsum(max_pos), default = 0))

plot_data <- gwas_std %>%
  mutate(chrom = factor(chrom, levels = chrom_levels)) %>%
  left_join(chrom_sizes, by = "chrom") %>%
  mutate(pos_cum = pos + pos_add)

# Midpoint of each chromosome's cumulative range, used for x-axis tick labels
axis_set <- plot_data %>%
  group_by(chrom) %>%
  summarise(center = mean(pos_cum), .groups = "drop")


# Genome-wide Significant SNPs
sig <- gwas_std[pval < pvalue_threshold]
cat("Significant SNPs:", nrow(sig), "\n")

if (nrow(sig) == 0) {
  stop("No significant SNPs found")
}


# Map Significant SNPs to Genes
edb <- EnsDb.Hsapiens.v75

# Pull gene coordinates (Ensembl release 75 / GRCh37) for nearest-gene search
genes <- genes(edb,
               columns = c("symbol", "seq_name", "gene_seq_start", "gene_seq_end"))

# Restrict to SNPs on chromosomes present in the annotation 
sig <- sig[sig$chrom %in% seqlevels(genes)]

# Convert significant SNPs to a GRanges object
sig_gr <- GRanges(seqnames = sig$chrom, ranges = IRanges(start = sig$pos, end = sig$pos))

# For each SNP, find the nearest gene and the distance to it
nearest <- distanceToNearest(sig_gr, genes)

sig[, gene := NA_character_]
sig[, distance := NA_integer_]

sig$gene[queryHits(nearest)] <- genes$symbol[subjectHits(nearest)]
sig$distance[queryHits(nearest)] <- mcols(nearest)$distance

# Keep only SNP-gene assignments within the maximum allowed distance
sig_gene <- sig[!is.na(gene) & distance <= max_gene_distance]
cat("SNPs assigned to genes:", nrow(sig_gene), "\n")

# Collapse to one candidate SNP per gene: keep the lowest p-value hit
top_hits <- sig_gene[order(pval)]
top_hits <- top_hits[!duplicated(gene)]
cat("Candidate genes:", nrow(top_hits), "\n")

fwrite(top_hits[, .(gene)], output_gene_file)


# Add Cumulative Genomic Position to Candidate Genes
top_hits <- top_hits %>%
  mutate(chrom = factor(chrom, levels = chrom_levels)) %>%
  left_join(chrom_sizes, by = "chrom") %>%
  mutate(pos_cum = pos + pos_add)


# Manhattan plot labeling ALL candidate genes over the threshold
manhattan <- ggplot(plot_data, aes(pos_cum, -log10(pval), colour = chrom)) +
  geom_point(size = 0.8, alpha = 0.7) +
  geom_hline(
    yintercept = -log10(pvalue_threshold),
    linetype = "dashed",
    colour = "red"
  ) +
  geom_label_repel(
    data = top_hits,
    aes(x = pos_cum, y = -log10(pval), label = gene),
    inherit.aes = FALSE,
    size = 3,              
    max.overlaps = Inf,
    min.segment.length = 0,
    box.padding = 0.3,
    segment.size = 0.3
  ) +
  scale_x_continuous(
    breaks = axis_set$center,
    labels = axis_set$chrom
  ) +
  scale_colour_manual(
    values = rep(c("#c52b8a", "#fa9fb5"), length.out = nrow(axis_set))
  ) +
  labs(
    x = "Chromosome",
    y = expression(-log[10](p)),
  ) +
  theme_minimal() +
  theme(
    legend.position = "none",
    axis.text.x = element_text(angle = 90, size = 12),
    axis.title.x = element_text(size = 15),
    axis.title.y = element_text(size = 15)
  )

manhattan

ggsave(
  output_plot_file,
  manhattan,
  width = 16,
  height = 10,
  dpi = 300
)


# Chromosome-level Summary Table of Candidate Genes 
formatted_table <- top_hits %>%
  group_by(chrom) %>%
  summarise(
    n_genes   = dplyr::n_distinct(gene),
    genes     = paste(unique(gene), collapse = ", "),
    min_pval  = min(pval, na.rm = TRUE),
    .groups   = "drop"
  ) %>%
  arrange(chrom)

write.csv(formatted_table, output_summary_file, row.names = FALSE)


# Final summary
cat("Significant SNPs:", nrow(sig), "\n")
cat("SNPs assigned to genes (within", max_gene_distance, "bp):", nrow(sig_gene), "\n")
cat("Unique candidate genes:", nrow(top_hits), "\n")
