rm(list=ls())

## load libraries to be used
library(DESeq2)
library(RColorBrewer)
library(pheatmap)
library(geneplotter)

work_dir <- "~/diss"
setwd(work_dir)

data <- readRDS("star_output/diss.RDS")

colnames(data) <- sub("ReadsPerGene.out.tab", "", colnames(data))

meta <- read.table("metadata/SraRunTable.csv",
                   header=TRUE, sep=",", stringsAsFactors=FALSE)

meta <- subset(meta, Run %in% colnames(data))

meta <- meta[, c("Run", "disease")]
meta <- meta[!duplicated(meta), ]

rownames(meta) <- meta$Run
rownames(data) <- data$GeneID
data <- data[, meta$Run]

if (! all(colnames(data) == rownames(meta)) ){
  stop("Column names of count data do not match the rownames of meta data!")
}

meta$disease <- trimws(meta$disease)
meta$disease <- tolower(meta$disease)
meta$disease <- gsub("[^a-z ]", "", meta$disease)
meta$disease <- gsub(" +", " ", meta$disease)

meta$disease[meta$disease == "normal"] <- "normal"
meta$disease[grepl("deep", meta$disease)] <- "DIE"
meta$disease[grepl("ovarian", meta$disease)] <- "OE"
meta$disease[grepl("peritoneal", meta$disease)] <- "PE"
meta$disease[meta$disease == "endometriosis"] <- "endometriosis"

meta$disease <- factor(meta$disease)
meta$disease <- relevel(meta$disease, ref="normal")

dds <- DESeqDataSetFromMatrix(countData = data, colData = meta, design = ~disease)

nrow(dds)
keep <- rowSums(counts(dds)) >= 10
dds <- dds[keep, ]
nrow(dds)

dds <- DESeq(dds)

raw_counts <- counts(dds, normalized = FALSE, replaced = FALSE)
norm_counts <- counts(dds, normalized = TRUE, replaced = FALSE)

output_dir <- "Deseq2_output/"
dir.create(output_dir, showWarnings = FALSE)   # FIX: dir was never created before png() calls

r1 <- cor(raw_counts, method = "spearman")
r2 <- cor(norm_counts, method = "spearman")
all(r1 == r2)
min(r1)

anno <- data.frame(Disease = meta$disease)
rownames(anno) <- rownames(meta)

if (! all(colnames(r1) == rownames(anno))) {
  stop("Names of correlation data are not in the same order as those in the annotation!")
}


pheatmap(r1, col = dChip.colors(50),
         main = "Spearman correlation", annotation_col = anno)
dev.off()


png(filename = paste0(output_dir, "Spearman_correlation_heatmap.png"),
  width = 6000, height = 6000, units = "px", res = 300, pointsize = 8)

pheatmap(r1, col = dChip.colors(50), main = "Spearman correlation", annotation_col = anno,
  cellwidth = 25, cellheight = 25, fontsize = 15, fontsize_row = 10, fontsize_col = 10,
  border_color = NA, annotation_names_col = TRUE, annotation_names_row = TRUE, annotation_legend = TRUE)

dev.off()


vsd <- vst(dds, blind = FALSE)

plotPCA(vsd, intgroup = c("disease"))
dev.off()

png(filename = paste0(output_dir, "diss_sample_PCA_plot.png"),
    width = 2250, height = 2250, units = "px", pointsize = 12,
    bg = "white", res = 300)
plotPCA(vsd, intgroup = c("disease"))
dev.off()
