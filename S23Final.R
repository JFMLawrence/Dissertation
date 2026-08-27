rm(list = ls())

library(openxlsx)
library(clusterProfiler)
library(ggplot2)
library(patchwork)
library(scales)

work_dir <- "~/diss/Deseq2_output"
gofile   <- "~/diss/genome/mart_export_human_ensembl116_GO.txt"

setwd(work_dir)

# ---- GO annotation data ----
go <- read.csv(gofile, stringsAsFactors = FALSE)

gobp <- subset(go, GO.domain == "biological_process")

term2gene <- unique(gobp[, c("GO.term.accession", "Gene.stable.ID")])
term2name <- unique(gobp[, c("GO.term.accession", "GO.term.name")])

# ---- Identify DESeq2 input workbooks ----
all_gene_files <- sort(list.files(
  pattern = "_Deseq2\\.xlsx$",
  full.names = FALSE
))

if (length(all_gene_files) == 0) {
  stop("No files ending in '_Deseq2.xlsx' were found.")
}

# Optional: enforce exactly three plots
if (length(all_gene_files) != 3) {
  warning(
    "Found ", length(all_gene_files),
    " DESeq2 files. All will be plotted; select three files manually if needed."
  )
}

plot_list <- list()

for (file in all_gene_files) {
  
  analysis_name <- sub("_Deseq2\\.xlsx$", "", file)
  comparison    <- gsub("_", " ", analysis_name)
  
  all_genes_df <- read.xlsx(file)
  
  # Keep valid Ensembl IDs and significant genes
  universe_genes <- unique(na.omit(all_genes_df$Gene.stable.ID))
  
  siggenes_df <- subset(
    all_genes_df,
    !is.na(padj) &
      padj < 0.05 &
      !is.na(Gene.stable.ID)
  )
  
  sig_genes <- unique(siggenes_df$Gene.stable.ID)
  
  enrich_go <- enricher(
    gene = sig_genes,
    universe = universe_genes,
    pvalueCutoff = 0.05,
    pAdjustMethod = "BH",
    qvalueCutoff = 0.20,
    minGSSize = 10,
    maxGSSize = 500,
    TERM2GENE = term2gene,
    TERM2NAME = term2name
  )
  
  # Save enrichment table, including a useful output when no terms are found
  if (is.null(enrich_go) || nrow(as.data.frame(enrich_go)) == 0) {
    write.xlsx(
      data.frame(message = "No significantly enriched GO biological-process terms."),
      file = paste0(analysis_name, "_enrich_gobp.xlsx"),
      overwrite = TRUE
    )
    message("Skipping ", analysis_name, ": no enriched GO terms.")
    next
  }
  
  enrich_df <- as.data.frame(enrich_go)
  
  write.xlsx(
    enrich_df,
    file = paste0(analysis_name, "_enrich_gobp.xlsx"),
    overwrite = TRUE
  )
  
  # showCategory is applied here, so p$data contains only plotted terms
  p <- barplot(
    enrich_go,
    showCategory = 20,
    x = "FoldEnrichment",
    color = "p.adjust",
    label_format = 60,
    title = paste(comparison, "enriched GO biological processes")
  ) +
    xlab("Fold enrichment") +
    theme_classic(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      axis.title.y = element_blank()
    )
  
  plot_list[[analysis_name]] <- p
}

if (length(plot_list) == 0) {
  stop("No plots were created because no comparisons had enriched GO terms.")
}

# ---- Find common x-axis and p.adjust ranges from displayed terms only ----
all_fold_enrichment <- unlist(lapply(
  plot_list,
  function(p) p$data$FoldEnrichment
))

all_padj <- unlist(lapply(
  plot_list,
  function(p) p$data$p.adjust
))

all_fold_enrichment <- all_fold_enrichment[
  is.finite(all_fold_enrichment)
]

# log10 cannot use zero; replace any numerical underflow safely
all_padj <- pmax(
  all_padj[is.finite(all_padj) & all_padj >= 0],
  .Machine$double.xmin
)

if (length(all_fold_enrichment) == 0 || length(all_padj) == 0) {
  stop("Could not calculate common plotting scales.")
}

x_limit <- max(all_fold_enrichment) * 1.08
padj_limits <- range(all_padj)

# ---- Apply one shared x-axis scale, while retaining default plot colours ----
plot_list <- lapply(plot_list, function(p) {
  p +
    scale_x_continuous(
      limits = c(0, x_limit),
      breaks = breaks_pretty(n = 6),
      labels = label_number(accuracy = 0.1),
      expand = expansion(mult = c(0, 0))
    )
})

# ---- Individual plots ----
for (analysis_name in names(plot_list)) {
  png(
    filename = paste0(analysis_name, "_enrich_gobp_barplot.png"),
    width = 3000,
    height = 1500,
    units = "px",
    res = 300,
    bg = "white"
  )
  print(plot_list[[analysis_name]])
  dev.off()
}

# ---- Stacked plot ----
plot_list[c(1,3)] <- lapply(
  plot_list[c(1,3)],
  function(p) p + theme(legend.position = "none")
)

combined_plot <- wrap_plots(plot_list, ncol = 1) +
  plot_layout(guides = "keep") 

pdf(
  "combined_enrich_gobp_barplots.pdf",
  width = 10,
  height = 5 * length(plot_list),
  useDingbats = FALSE
)

print(combined_plot)
dev.off()

png(
  filename = "combined_enrich_gobp_barplots.png",
  width = 3000,
  height = 1500 * length(plot_list),
  units = "px",
  res = 300,
  bg = "white"
)

print(combined_plot)
dev.off()


