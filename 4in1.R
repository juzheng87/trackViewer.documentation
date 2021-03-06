library(grid)

set.seed(123)

library(trackViewer) # load package
gr <- parse2GRanges("chr3:108,476,000-108,485,000")
gr # interesting genomic locations
library(GenomicFeatures) # load GenomicFeatures to create TxDb from UCSC
mm8KG <- loadDb("mm8KG.sqlite")

library(org.Mm.eg.db) # load annotation database
## create the gene model tracks information
trs1A <- geneModelFromTxdb(mm8KG, org.Mm.eg.db, gr=gr)
## import data from bedGraph/bigWig/BED ... files, see ?importScore for details
CLIP <- importScore("CLIP.bedGraph", format="bedGraph", ranges=gr)
control <- importScore("control.bedGraph", format="bedGraph", ranges=gr)
knockdown <- importScore("knockdown.bedGraph", format="bedGraph", ranges=gr)
## create styles by preset theme
optSty <- optimizeStyle(trackList(trs1A, knockdown, control, CLIP), theme="safe")
trackList <- optSty$tracks
viewerStyle <- optSty$style
## adjust the styles for this track
### rename the trackList for each track
names(trackList)[1:2] <- paste0("Sort1: ", names(trackList)[1:2])
names(trackList)[3] <- "RNA-seq TDP-43 KD"
names(trackList)[4] <- "RNA-seq control"
### change the lab positions for gene model track to bottomleft
setTrackStyleParam(trackList[[1]], "ylabpos", "bottomleft")
setTrackStyleParam(trackList[[2]], "ylabpos", "bottomleft")
### change the color of gene model track
for(i in 1:5){
  setTrackStyleParam(trackList[[i]], "ylabgp", list(cex=.5, col="#000000"))
}
for(i in 3:5){
  setTrackYaxisParam(trackList[[i]], "gp", list(cex=.5))
}
setTrackStyleParam(trackList[[4]], "ylim", c(0, 650))
setTrackStyleParam(trackList[[5]], "ylim", c(0, 80))
### remove the xaxis
setTrackViewerStyleParam(viewerStyle, "xaxis", FALSE)
### add a scale bar in CLIP track
setTrackXscaleParam(trackList[[5]], "draw", TRUE)
setTrackXscaleParam(trackList[[5]], "label", "1000 bp")
setTrackXscaleParam(trackList[[5]], "from", new("pos", x=108478000, y=20, unit="native"))
setTrackXscaleParam(trackList[[5]], "to", new("pos", x=108479000, y=20, unit="native"))
setTrackXscaleParam(trackList[[5]], "gp", list(cex=.5))
## plot the tracks
trackList1A <- trackList
gr1A <- gr
viewerStyle1A <- viewerStyle


library(trackViewer) # load package
library(VariantAnnotation)
library(TxDb.Hsapiens.UCSC.hg19.knownGene)
library(org.Hs.eg.db)
library(rtracklayer)
fl <- system.file("extdata", "chr22.vcf.gz", package="VariantAnnotation")
## set the track range
gr <- GRanges("22", IRanges(50968014, 50970514, names="TYMP"))
## read in vcf file
tab <- TabixFile(fl)
vcf <- readVcf(fl, "hg19", param=gr)
## get GRanges from VCF object 
mutation.frequency <- rowRanges(vcf)
## keep the metadata
mcols(mutation.frequency) <- 
  cbind(mcols(mutation.frequency), 
        VariantAnnotation::info(vcf))
## set colors
mutation.frequency$border <- "gray30"
mutation.frequency$color <-
  ifelse(grepl("^rs", names(mutation.frequency)), 
         "lightcyan", "lavender")
mutation.frequency$lwd <- .3
## plot Global Allele Frequency based on AC/AN
mutation.frequency$score <- round(mutation.frequency$AF*100)
## change the SNPs label rotation angle
mutation.frequency$label.parameter.rot <- 45
mutation.frequency$label.parameter.gp <- gpar(cex=.4)
## keep sequence level style same
seqlevelsStyle(gr) <- seqlevelsStyle(mutation.frequency) <- "UCSC"
## extract transcripts in the range
trs <- geneModelFromTxdb(TxDb.Hsapiens.UCSC.hg19.knownGene, 
                         org.Hs.eg.db, gr=gr)
## subset the features to show the interested transcripts only
features <- GRangesList(trs[[1]]$dat, trs[[5]]$dat, trs[[6]]$dat)
flen <- elementNROWS(features)
features <- unlist(features)
## define the feature track layers
features$featureLayerID <- rep(1:2, c(sum(flen[-3]), flen[3]))
## define the feature labels
names(features) <- features$symbol
## define the feature colors
features$fill <- rep(c("lightblue", "mistyrose", "mistyrose"), flen)
## define the feature heights
features$height <- ifelse(features$feature=="CDS", .04, .02)
features$cex <- .5
features$lwd <- .5
## import methylation data from a bed file
methy <- import(system.file("extdata", "methy.bed", package="trackViewer"), "BED")
## subset the data
methy <- methy[methy$score > 20]
## simulate multiple patients
rand.id <- sample.int(length(methy), 3*length(methy), replace=TRUE)
rand.id <- sort(rand.id)
methy.mul.patient <- methy[rand.id]
## pie.stack require metadata "stack.factor", and the metadata can not be 
## stack.factor.order or stack.factor.first
len.max <- max(table(rand.id))
stack.factors <- paste0("patient", 
                        formatC(1:len.max, 
                                width=nchar(as.character(len.max)), 
                                flag="0"))
methy.mul.patient$stack.factor <- 
  unlist(lapply(table(rand.id), sample, x=stack.factors))
methy.mul.patient$score <- 
  sample.int(100, length(methy.mul.patient), replace=TRUE)
## for a pie plot, two or more numeric meta-columns are required.
methy.mul.patient$score2 <- 100 - methy.mul.patient$score
## set different color set for different patient
safeColors <- c("#D55E00", "#009E73", "#0072B2",
                "#56B4E9", "#CC79A7", "#E69F00", "#F0E442", "#BEBEBE")
patient.color.set <- as.list(as.data.frame(rbind(safeColors[seq_along(stack.factors)], 
                                                 "#FFFFFFFF"), 
                                           stringsAsFactors=FALSE))
names(patient.color.set) <- stack.factors
methy.mul.patient$color <- 
  patient.color.set[methy.mul.patient$stack.factor]
methy.mul.patient$lwd <- .3
## set the legends
legends <- list(list(labels=c("known", "unkown"), 
                     fill=c("lightcyan", "lavender"), 
                     color=c("gray80", "gray80"),
                     cex=.5), 
                list(labels=stack.factors, col="black", 
                     fill=sapply(patient.color.set, `[`, 1),
                     cex=.5))
## lollipop plot
data1B <- list(mutaions=mutation.frequency, methylations=methy.mul.patient)
features1B <- features
gr1B <- gr
legend1B <- legends
legend1B$cex <- .5
features1BA <- features1B
names(features1BA) <- NULL

library(trackViewer) #load package
## loading data.
data <- read.delim("IARC-TP53/datasets/somaticMutationDataIARC TP53 Database, R19.txt", 
                   stringsAsFactors = FALSE)
data <- data[data$Morphology %in% "Small cell carcinoma, NOS" & 
               data$Effect %in% c("nonsense", "missense", "silent", "intronic"), 
             c("hg38_Chr17_coordinates", "g_description_GRCh38", "Effect")]
counts <- table(data$g_description_GRCh38)
data$counts <- as.numeric(counts[data$g_description_GRCh38])
data <- unique(data)
## prepare a GRanges object for mutations
snps <- with(data, GRanges("chr17", IRanges(hg38_Chr17_coordinates, width=1), 
                           effect=factor(Effect), score=counts))
## set the bristles head colors of the pappus by mutation types
snps$color <- safeColors[as.numeric(snps$effect)]
## parepare the legends
legends <- list(list(labels=levels(snps$effect), 
                     fill=safeColors[seq.int(length(levels(snps$effect)))],
                     cex = .5))
## set the beak color of dandelion seeds.
snps$border <- "gray"
snps$lwd <- .3
## set plotting region
gr <- GRanges("chr17", IRanges(7669000, 7677000))
## extract transcripts in the range
library(TxDb.Hsapiens.UCSC.hg38.knownGene)
library(org.Hs.eg.db)
trs <- geneModelFromTxdb(TxDb.Hsapiens.UCSC.hg38.knownGene, 
                         org.Hs.eg.db, gr=gr)
## subset the features to show the interested transcripts only
features <- c(trs[[1]]$dat, trs[[3]]$dat, trs[[4]]$dat)
lens <- sapply(trs[c(1, 3, 4)], function(.e) length(.e$dat))
## define the feature legend name
names(features) <- rep(names(trs)[c(1, 3, 4)], lens)
## define the feature track layers
features$featureLayerID <- rep(seq.int(3), lens)
## define the feature colors
features$fill <- rep(c("lightblue", "mistyrose", "orange"), lens)
## define the feature heights
features$height <- ifelse(features$feature=="CDS", 0.02, 0.01)
## feature border lwd
features$lwd <- .5
## plot, use mean function to calculate the height of beak of dandelion seeds.
features1C <- features
gr1C <- gr
legend1C <- legends
features1C$cex <- .5
features1C$height <- features1C$height*2

library(trackViewer) #load package
library(Biostrings)
library(motifStack)
motif <- importMatrix("TET1.PWM.txt", format = "cisbp") ## motif was downloaded from cis-bp
pwm <- pfm2pwm(motif[[1]])
fa <- readDNAStringSet("FMR1.ups3K.dws3K.fasta")
names(fa) <- "FMR1"
TET1.binding.sites.v <- matchPWM(pwm, subject = fa[[1]], 
                                 min.score = "95%", with.score = TRUE)
TET1.binding.sites <- shift(ranges(TET1.binding.sites.v), shift = 147908950)
TET1.binding.sites <- GRanges("chrX", TET1.binding.sites, strand = "+", 
                              score=mcols(TET1.binding.sites.v)$score)
width(TET1.binding.sites) <- 1
TET1.binding.sites$border <- "gray80"
TET1.binding.sites$color <- "#009E73"
## set lollipop plot type to pin.
TET1.binding.sites$type <- "pin"
TET1.binding.sites$cex <- .5
TET1.binding.sites <- new("track", dat=TET1.binding.sites, type="lollipopData")
gr <- GRanges("chrX", IRanges(147910500, 147914000))
## extract transcripts in the range
library(TxDb.Hsapiens.UCSC.hg38.knownGene)
library(org.Hs.eg.db)
FMR1 <- geneTrack(get("FMR1", org.Hs.egSYMBOL2EG), TxDb.Hsapiens.UCSC.hg38.knownGene)[[1]]
FMR1$dat2 <- GRanges("chrX", 
                     IRanges(c(147911604, 147911617, 147911727, 147911743, 147911758, 
                               147911768, 147911810, 147911821, 147911854, 147911877,
                               147911882, 147911902, 147911963), width = 1, 
                             names = c("AP2", "UBP1", "Sp1", "Sp1", "NRF1", 
                                       "Sp1", "AGP", "NRF1", "Sp1", "AP2", 
                                       "Sp1-like", "Myc", "Zeste")))
FMR1$dat2$color <- safeColors[as.numeric(factor(names(FMR1$dat2)))]
FMR1$dat2$border <- "gray"
## set lollipop label parameter.
FMR1$dat2$label.parameter.rot <- 45
FMR1$dat2$label.parameter.gp <- gpar(cex=.4)
FMR1$dat2$cex <- .5
FMR1$dat2$lwd <- .3
## add methylation counts
maxX <- GRanges("chrX", IRanges(147911550, width=1), score=9, 
                color="white", border="white")
FX52_mock_methy <- GRanges("chrX", IRanges(147911556+seq.int(35)*4, width=1),
                           score=c(8, 8, 8, 7, 8, 9, 9, 9, 8, 9, 9, 9, 9, 8, 9,
                                   9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
                                   9, 9, 9, 8, 9), color=5, border="gray", lwd=.3)
FX52_mock_methy <- new("track", dat=c(FX52_mock_methy, maxX), type="lollipopData")
FX52_dC_T_methy <- GRanges("chrX", IRanges(147911556+seq.int(35)*4, width=1),
                           score=c(3, 5, 3, 2, 0, 1, 1, 2, 0, 1, 1, 0, 0, 1, 0,
                                   0, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
                                   0, 1, 0, 0, 1), color=4, border="gray", lwd=.3)
FX52_dC_T_methy$color[FX52_dC_T_methy$score==0] <- "white"
FX52_dC_T_methy <- new("track", dat=c(FX52_dC_T_methy, maxX), type="lollipopData")
## import RNA-seq tracks
iPSC_dC_T.RNAseq <- importScore("iPSC_dC-T.bw", ranges = gr, format = "BigWig") 
iPSC_mock.RNAseq <- importScore("iPSC_mock.bw", ranges = gr, format = "BigWig")
## import ChIP-Bisulfite-Seq tracks
iPSC_dC_T.BSseq <- importScore("IPSC_dC-T.methy.bedgraph", "IPSC_dC-T.demethy.bedgraph", ranges = gr, format = "bedGraph")
iPSC_dC_dT.BSseq <- importScore("IPSC_dC-dT.methy.bedgraph", "IPSC_dC-dT.demethy.bedgraph", ranges = gr, format = "bedGraph")
##stronger the signals
width(iPSC_dC_T.BSseq$dat) <- width(iPSC_dC_T.BSseq$dat) + 1
width(iPSC_dC_dT.BSseq$dat) <- width(iPSC_dC_dT.BSseq$dat) + 1
## optimize stlye
optSty <- optimizeStyle(trackList(FMR1, TET1.binding.sites,
                                  FX52_dC_T_methy, FX52_mock_methy, 
                                  iPSC_dC_dT.BSseq, iPSC_dC_T.BSseq, 
                                  iPSC_mock.RNAseq, iPSC_dC_T.RNAseq, 
                                  heightDist=c(2, 1, 1, 1, 1, 1, 1, 1)), 
                        theme="safe")
trackList <- optSty$tracks
viewerStyle <- optSty$style
## adjust y scale
for(i in c("iPSC_dC_T.RNAseq", "iPSC_mock.RNAseq")){
  setTrackStyleParam(trackList[[i]], "ylim", c(0, 20))
}
## adjust track stlyes
setTrackStyleParam(trackList[["iPSC_dC_T.BSseq"]], "color", c("#E69F00", "pink"))
setTrackStyleParam(trackList[["iPSC_dC_T.BSseq"]], "ylabgp", 
                   list(cex=trackList[["iPSC_dC_T.BSseq"]]$style@ylabgp$cex,
                        col="black"))
setTrackStyleParam(trackList[["iPSC_dC_dT.BSseq"]], "color", c("#E69F00", "pink"))
for(i in seq_along(trackList)){
  setTrackStyleParam(trackList[[i]], "ylabgp", list(cex=.5, col=trackList[[i]]$style@ylabgp$col))
}

for(i in 5:8){
  setTrackYaxisParam(trackList[[i]], "gp", list(cex=.5))
}
setTrackViewerStyleParam(viewerStyle, "margin", c(.07, .05, .02, .05))
setTrackStyleParam(trackList[["iPSC_dC_dT.BSseq"]], "ylabpos", "underbaseline")

trackList1D <- trackList
gr1D <- gr
viewerStyle1D <- viewerStyle
viewerStyle1D@xgp$cex <- .5 

plotFigure <- function(){
  vp <- viewport(.275, .8, .55, .38)
  pushViewport(vp)
  grid.text("A)", 0.05, .95, just = c(0, 1), gp=gpar(fontface="bold", cex=1))
  vp <- viewTracks(trackList1A, gr=gr1A, viewerStyle=viewerStyle1A, newpage = FALSE)
  ### add guide lines to show the range of CLIP-seq signal
  addGuideLine(c(108481252, 108481887), vp=vp)
  ### add arrow mark to show the alternative splicing event
  addArrowMark(list(x=c(108483570, 108483570), 
                    y=c(3, 4)), ##layer 3 and 4
               label=c("Inclusive exon", ""), 
               col=c("black", "black"), 
               vp=vp, quadrant=2, cex=.5,
               length=unit(.125, "inches"))
  popViewport()
  
  
  vp <- viewport(.275, .31, .55, .6)
  pushViewport(vp)
  grid.text("C)", 0.05, .99, just = c(0, 1), gp=gpar(fontface="bold", cex=1))
  vp <- viewTracks(trackList1D, gr=gr1D, viewerStyle=viewerStyle1D, newpage = FALSE)
  addGuideLine(c(147911556, 147911695, 147912052, 147912111), 
               col = c("#CC79A7", "#CC79A7", "#0072B2", "#0072B2"), vp=vp)
  addArrowMark(pos = list(x=c(147911626, 147912070), y=c(4, 1)), 
               label = c("CpG island", "(CGG)n"),
               col = c("black", "black"), vp=vp, cex=.5,
               length=unit(.125, "inches"))
  popViewport()
  
  vp <- viewport(.76, .68, .5, .6)
  pushViewport(vp)
  grid.text("B)", 0.12, .99, just = c(0, 1), gp=gpar(fontface="bold", cex=1))
  lolliplot(data1B, 
            list(features1B, features1BA), ranges=gr1B, type=c("circle", "pie.stack"), 
            legend=legend1B, newpage = FALSE, cex = .5, xaxis = TRUE, yaxis = FALSE,
            xaxis.gp=gpar(cex=.5), yaxis.gp=gpar(cex=.5), ylab.gp=gpar(cex=.65))
  popViewport()
  
  vp <- viewport(.775, .19, .45, .4)
  pushViewport(vp)
  grid.text("D)", .05, .95, just = c(0, 1), gp=gpar(fontface="bold", cex=1))
  dandelion.plot(snps, features1C, ranges=gr1C, legend = legend1C, type="circle",
                 heightMethod = mean, yaxis = TRUE, ylab='mean of mutation counts', 
                 xaxis.gp=gpar(cex=.5), yaxis.gp=gpar(cex=.5), ylab.gp=gpar(cex=.65),
                 newpage = FALSE, cex = .5)
  popViewport()
  
}

pdf("4in1.pdf", width = 7, height = 4)
plotFigure()
dev.off()

# pdf("4in1.14.pdf", width = 14, height = 8)
# plotFigure()
# dev.off()
