#######################################################################################################
# Analysis RNA-seq data of the components of synthetic gut communities in monoculture vs tri-cultures #
#                                                                                                     # 
# Manuscript (in preparation): Emergent behavior in a synthetic human gut community                   #  
#                                                                                                     #  
# Verónica Lloréns Rico                                                                               #
# Lab. of Molecular Bacteriology                                                                      #
# VIB-KU Leuven Center for Microbiology                                                               #
# Rega Institute - Herestraat 49 Box 1028 - 3000 Leuven                                               #
#######################################################################################################


#### PART 1: Load RNA-seq count data and create metadata tables ####

# load required packages and functions

require(ggpubr)
require(DESeq2)
require(clusterProfiler)
require(tidyverse)
source("R/helperFunctions.R") # this loads the function to perform Fisher's exact test for functional enrichment 


# define bacterial (and possible contaminant) indices in the count matrix output from htseq-count

fpra=5:2829 # F. prausnitzii
phiX=2840:2841 # phage PhiX174
rint=2893:6727 # R. intestinalis
bhyd=6735:10049 # B. hydrogenotrophica
ychI=c(1:4,2830:2837,2852:2892,6728:6734,10050:16416) # Yeast



# list count files

directory="data/counts/"
files=list.files(directory)


# create table with metadata

experiments=sapply(files, FUN=function(X){strsplit(X, split="_")[[1]][1]})
species=c(rep("bhyd", times=5), rep("fpra", times=6), rep("rint", times=6), rep("all", times=6))
time=sapply(files, FUN=function(X){strsplit(X, split="[[:punct:]]")[[1]][2]})
metadata=cbind(species, time)



# prepare individual metadata tables for each species

metadata=cbind(metadata,type=c(rep("single", times=17), rep("tri", times=6)),experiment=experiments)
metadataBH=as.data.frame(metadata[metadata[,1]=="bhyd" | metadata[,1]=="all",2:4]) ## extract data from BH
metadataFP=as.data.frame(metadata[metadata[,1]=="fpra" | metadata[,1]=="all",2:4]) ## extract data from FP
metadataRI=as.data.frame(metadata[metadata[,1]=="rint" | metadata[,1]=="all",2:4]) ## extract data from RI
levels(metadataBH$time)=c("15h", "03h", "09h")
levels(metadataFP$time)=c("15h", "03h", "09h")
levels(metadataRI$time)=c("15h", "03h", "09h")

metadataBH$time = factor(metadataBH$time,levels(metadataBH$time)[c(2,3,1)])
metadataFP$time = factor(metadataFP$time,levels(metadataFP$time)[c(2,3,1)])
metadataRI$time = factor(metadataRI$time,levels(metadataRI$time)[c(2,3,1)])



# read files and create a count matrix

countMatrix=data.frame(row.names=read.table(paste(directory,files[1], sep=""), header=F, stringsAsFactors=F, sep="\t")[1:16416,1])
for(exp in files){
  tmp=read.table(paste(directory,exp, sep=""), header=F, stringsAsFactors=F, sep="\t")[1:16416,]
  countMatrix=cbind(countMatrix,tmp[,2])
}
colnames(countMatrix)=experiments



#### PART 2: Plot transcript abundance for each species, normalizing by transcriptome size ####


# retrieve the total counts for each species

statsData=as.data.frame(metadata, stringsAsFactors=F)
statsData$BH=apply(countMatrix[bhyd,], MARGIN=2, FUN=sum, na.rm=T)
statsData$RI=apply(countMatrix[rint,], MARGIN=2, FUN=sum, na.rm=T)
statsData$FP=apply(countMatrix[fpra,], MARGIN=2, FUN=sum, na.rm=T)
statsData$phiX=apply(countMatrix[phiX,], MARGIN=2, FUN=sum, na.rm=T)
statsData$yeast=apply(countMatrix[ychI,], MARGIN=2, FUN=sum, na.rm=T)



# normalize the raw number of counts calculated above, considering the total counts per experiment and the length of the transcriptome, using FPKM formula
# length of the transcriptome was calculated from the gff files, as the sum of the length of all regions labeled as "locus_tag" for each species

countsPerExp=apply(statsData[,5:9], 1, sum)
statsData$BH=statsData$BH*1e9/(countsPerExp*3018073)
statsData$RI=statsData$RI*1e9/(countsPerExp*3543428) 
statsData$FP=statsData$FP*1e9/(countsPerExp*2540563) 
statsData$phiX=statsData$phiX*1e9/(countsPerExp*2*5386) 
statsData$yeast=statsData$yeast*1e9/(countsPerExp*9008924) 



# convert the abundances to percentages to compare the different experiments

percentageSums=apply(statsData[,5:9], MARGIN=1, FUN=sum)
statsData[,5:9]=statsData[,5:9]*100/percentageSums



# reshape data before plotting with ggbarplot

species1=statsData[,c(1:5)]
species1$sp="B. hydrogenotrophica"
species2=statsData[,c(1:4,6)]
species2$sp="R. intestinalis"
species3=statsData[,c(1:4,7)]
species3$sp="F. prausnitzii"
species4=statsData[,c(1:4,8)]
species4$sp="PhiX174"
species5=statsData[,c(1:4,9)]
species5$sp="S. cerevisiae S288c"

colnames(species1)[5]="readCounts"
colnames(species2)[5]="readCounts"
colnames(species3)[5]="readCounts"
colnames(species4)[5]="readCounts"
colnames(species5)[5]="readCounts"

statsData=rbind(species1,species2,species3,species4,species5)



#reorder factors and change species names for visualization

statsData$time=factor(statsData$time, levels = c("3h", "9h", "15h"))
statsData$replicate=sapply(statsData$experiment, FUN=function(X){gsub(strsplit(X, split="-")[[1]][1], pattern="[[:alpha:]]", replacement="")})
statsData$replicate[statsData$replicate==14]=1
statsData$replicate[statsData$replicate==15]=2
statsData$replicate[statsData$replicate==16]=1

statsData$species[statsData$species=="bhyd"]="B. hydrogenotrophica"
statsData$species[statsData$species=="rint"]="R. intestinalis"
statsData$species[statsData$species=="fpra"]="F. prausnitzii"
statsData$species[statsData$species=="all"]="All"

statsData$sp=factor(statsData$sp, levels=c("B. hydrogenotrophica", "F. prausnitzii", "R. intestinalis", "S. cerevisiae S288c", "PhiX174"))



# plot with ggbarplot

pdf("figures/mapping_counts_withphiX174_yeast_normalized.pdf", width=9, height=5)
ggbarplot(statsData, x="time", y="readCounts", color="sp", fill="sp", facet.by =c("replicate", "species"),position = position_dodge(0.8), 
          palette=c(rgb(14, 112, 3, max = 255),rgb(4, 0, 255, max = 255), rgb(251, 0, 6, max = 255), rgb(254, 181, 30, max = 255), rgb(25, 197, 198, max = 255)), 
          legend="right", legend.title="Species", ylab = "Read counts normalized by transcriptome size (%)")+theme_light() +  theme(legend.text = element_text(face = "italic"))

dev.off()






#### PART 3: Differential expression analysis for each species ####


## 3.1. Analysis B. hydrogenotrophica ##

# first, extract the counts for this genome and create the DESeqDataSet object, including time of the culture and type (single vs tri-culture) as factors

counts_genome=countMatrix[bhyd,as.character(metadataBH$experiment)]
rownames(metadataBH)=metadataBH$experiments
dds=DESeqDataSetFromMatrix(countData = counts_genome,
                           colData = metadataBH,
                           design = ~ type + time)



# ignore all features with ≤10 counts

keep <- rowSums(counts(dds)) > 10
dds=dds[keep,]



# calculate differential expression in tricultures vs single cultures for Blautia + produce an MA-plot

ddseq = DESeq(dds)
res = results(ddseq, contrast=c("type", "tri", "single"))
plotMA(res)



# extract genes up- vs down- regulated, without imposing any threshold

resfilt=res[!is.na(res$padj) & res$padj<0.05,]
genesUP=rownames(resfilt)[resfilt$log2FoldChange>0] # UP in triculture vs monoculture
genesDW=rownames(resfilt)[resfilt$log2FoldChange<0] # DW in triculture vs monoculture



# load annotation table and perform COG category enrichment using Fisher's exact test

blautia_annot=read.delim("data/blautia_annotation.txt", header=T, stringsAsFactors = F, sep="\t")

all_COGs=blautia_annot[blautia_annot$Source=="COG_category",3]
UP_COGs=blautia_annot[blautia_annot$Source=="COG_category" & blautia_annot$New_locus_tag %in% genesUP,3]

enrichment(UP_COGs, all_COGs)

all_COGs=blautia_annot[blautia_annot$Source=="COG_category",3]
DOWN_COGs=blautia_annot[blautia_annot$Source=="COG_category" & blautia_annot$New_locus_tag %in% genesDW,3]

enrichment(DOWN_COGs, all_COGs) 



# GSEA using package clusterProfiler

T2G=blautia_annot[blautia_annot$Source=="COG_category",c(3,5)]
genelist=res$log2FoldChange #retrieve list of log2 fold changes for GSEA
names(genelist)=rownames(res)
GSEAgenes=GSEA(sort(genelist, decreasing = T), TERM2GENE = T2G)



# plot GSEA result 

pdf("figures/GSEA_bhydrogenotrophica.pdf")
for(i in rownames(slot(object = GSEAgenes, name = "result"))){
  gseaplot(GSEAgenes, i, title = i, color.line="#E64B35FF", color.vline = "#4DBBD5FF")
  plot.new()
}
dev.off()



# retrieve results and annotations for Blautia

COG_numbers=c()
COG_categories=c()
KO_numbers=c()
Species=c()
Change=c()
Pval=c()
Padj=c()
Locus_tag=c()
COG_annotations=c()
line=1
for(i in 1:nrow(resfilt)){
  Species[line]="B. hydrogenotrophica"
  Change[line]=resfilt[i,2]
  Pval[line]=resfilt[i,5]
  Padj[line]=resfilt[i,6]
  Locus_tag[line]=rownames(resfilt)[i]
  COG_categories[line]=paste(na.omit(blautia_annot[blautia_annot$Source=="COG_category" & blautia_annot$New_locus_tag==rownames(resfilt)[i],3]),collapse=" - ")
  COG_numbers[line]=paste(na.omit(blautia_annot[blautia_annot$Source=="COG_number" & blautia_annot$New_locus_tag==rownames(resfilt)[i],3]),collapse=" - ")
  KO_numbers[line]=paste(na.omit(blautia_annot[blautia_annot$Source=="KO_number" & blautia_annot$New_locus_tag==rownames(resfilt)[i],3]),collapse=" - ")
  COG_annotations[line]=paste(na.omit(blautia_annot[blautia_annot$Source=="COG_number" & blautia_annot$New_locus_tag==rownames(resfilt)[i],4]),collapse=" - ")
  line=line+1
}





## 3.2. Analysis F. prausnitzii ##

# first, extract the counts for this genome and create the DESeqDataSet object, including time of the culture and type (single vs tri-culture) as factors

counts_genome=countMatrix[fpra,as.character(metadataFP$experiment)]
rownames(metadataFP)=metadataFP$experiments
dds=DESeqDataSetFromMatrix(countData = counts_genome,
                           colData = metadataFP,
                           design = ~ type + time)



# ignore all features with ≤10 counts

keep <- rowSums(counts(dds)) > 10
dds=dds[keep,]



# calculate differential expression in tricultures vs single cultures for Faecalibacterium + produce an MA-plot

ddseq = DESeq(dds)
res = results(ddseq, contrast=c("type", "tri", "single")) 
plotMA(res)



# extract genes up- vs down- regulated, without imposing any threshold

resfilt=res[!is.na(res$padj) & res$padj<0.05,]
genesUP=rownames(resfilt)[resfilt$log2FoldChange>0] ## UP in triculture vs mono
genesDW=rownames(resfilt)[resfilt$log2FoldChange<0] ## DW in triculture vs mono


# load annotation table and perform COG category enrichment using Fisher's exact test

faecalibacterium_annot=read.delim("data/faecalibacterium_annotation.txt", header=T, stringsAsFactors = F, sep="\t")

all_COGs=faecalibacterium_annot[faecalibacterium_annot$Source=="COG_category",3]
UP_COGs=faecalibacterium_annot[faecalibacterium_annot$Source=="COG_category" & faecalibacterium_annot$New_locus_tag %in% genesUP,3]

enrichment(UP_COGs, all_COGs)

all_COGs=faecalibacterium_annot[faecalibacterium_annot$Source=="COG_category",3]
DOWN_COGs=faecalibacterium_annot[faecalibacterium_annot$Source=="COG_category" & faecalibacterium_annot$New_locus_tag %in% genesDW,3]

enrichment(DOWN_COGs, all_COGs) 



# GSEA using package clusterProfiler

T2G=faecalibacterium_annot[faecalibacterium_annot$Source=="COG_category",c(3,5)] # parse annotation file to use as an input for clusterProfiler
genelist=res$log2FoldChange # retrieve list of log2 fold changes for GSEA
names(genelist)=rownames(res)
GSEAgenes=GSEA(sort(genelist, decreasing = T), TERM2GENE = T2G)



# plot GSEA result 

pdf("figures/GSEA_fprausnitzii.pdf")
for(i in rownames(slot(object = GSEAgenes, name = "result"))){
  gseaplot(GSEAgenes, i, title = i, color.line="#E64B35FF", color.vline = "#4DBBD5FF")
  plot.new()
}
dev.off()



# retrieve results and annotations for Faecalibacterium

for(i in 1:nrow(resfilt)){
  Species[line]="F. prausnitzii"
  Change[line]=resfilt[i,2]
  Pval[line]=resfilt[i,5]
  Padj[line]=resfilt[i,6]
  Locus_tag[line]=rownames(resfilt)[i]
  COG_categories[line]=paste(na.omit(faecalibacterium_annot[faecalibacterium_annot$Source=="COG_category" & faecalibacterium_annot$New_locus_tag==rownames(resfilt)[i],3]),collapse=" - ")
  COG_numbers[line]=paste(na.omit(faecalibacterium_annot[faecalibacterium_annot$Source=="COG_number" & faecalibacterium_annot$New_locus_tag==rownames(resfilt)[i],3]),collapse=" - ")
  KO_numbers[line]=paste(na.omit(faecalibacterium_annot[faecalibacterium_annot$Source=="KO_number" & faecalibacterium_annot$New_locus_tag==rownames(resfilt)[i],3]),collapse=" - ")
  COG_annotations[line]=paste(na.omit(faecalibacterium_annot[faecalibacterium_annot$Source=="COG_number" & faecalibacterium_annot$New_locus_tag==rownames(resfilt)[i],4]),collapse=" - ")
  line=line+1
}




## 3.2. Analysis R. intestinalis ##

# first, extract the counts for this genome and create the DESeqDataSet object, including time of the culture and type (single vs tri-culture) as factors

counts_genome=countMatrix[rint,as.character(metadataRI$experiment)]
rownames(metadataRI)=metadataRI$experiments
dds=DESeqDataSetFromMatrix(countData = counts_genome,
                           colData = metadataRI,
                           design = ~ type + time)



# ignore all features with ≤10 counts

keep <- rowSums(counts(dds)) > 10
dds=dds[keep,]



# calculate differential expression in tricultures vs single cultures for Faecalibacterium + produce an MA-plot

ddseq = DESeq(dds)
res = results(ddseq, contrast=c("type", "tri", "single")) 
plotMA(res)



# extract genes up- vs down- regulated, in this case in genes whose average expresion (baseMean) is > 10, because the disparity in library sizes is causing a bias in low expression genes

resfilt=res[!is.na(res$padj) & res$padj<0.05 & res$baseMean>10,]
genesUP=rownames(resfilt)[resfilt$log2FoldChange>0] ## UP in triculture vs mono
genesDW=rownames(resfilt)[resfilt$log2FoldChange<0] ## DW in triculture vs mono



# load annotation table and perform COG category enrichment using Fisher's exact test

roseburia_annot=read.delim("data/roseburia_annotation.txt", header=T, stringsAsFactors = F, sep="\t")

all_COGs=roseburia_annot[roseburia_annot$Source=="COG_category",3]
UP_COGs=roseburia_annot[roseburia_annot$Source=="COG_category" & roseburia_annot$New_locus_tag %in% genesUP,3]

enrichment(UP_COGs, all_COGs)

all_COGs=roseburia_annot[roseburia_annot$Source=="COG_category",3]
DOWN_COGs=roseburia_annot[roseburia_annot$Source=="COG_category" & roseburia_annot$New_locus_tag %in% genesDW,3]

enrichment(DOWN_COGs, all_COGs) 



# GSEA using package clusterProfiler

T2G=roseburia_annot[roseburia_annot$Source=="COG_category",c(3,5)] # parse annotation file to use as an input for clusterProfiler
genelist=res$log2FoldChange #retrieve list of log2 fold changes for GSEA
names(genelist)=rownames(res)
GSEAgenes=GSEA(sort(genelist, decreasing = T), TERM2GENE = T2G)



# plot GSEA result 
# do not plot as there is no significant GSEA result
# pdf("figures/GSEA_rintestinalis.pdf")
# for(i in rownames(slot(object = GSEAgenes, name = "result"))){
#   gseaplot(GSEAgenes, i, title = i, color.line="#E64B35FF", color.vline = "#4DBBD5FF")
#   # plot.new()
# }
# dev.off()



# retrieve results and annotations for Roseburia

for(i in 1:nrow(resfilt)){
  Species[line]="R. intestinalis"
  Change[line]=resfilt[i,2]
  Pval[line]=resfilt[i,5]
  Padj[line]=resfilt[i,6]
  Locus_tag[line]=rownames(resfilt)[i]
  COG_categories[line]=paste(na.omit(roseburia_annot[roseburia_annot$Source=="COG_category" & roseburia_annot$New_locus_tag==rownames(resfilt)[i],3]),collapse=" - ")
  COG_numbers[line]=paste(na.omit(roseburia_annot[roseburia_annot$Source=="COG_number" & roseburia_annot$New_locus_tag==rownames(resfilt)[i],3]),collapse=" - ")
  KO_numbers[line]=paste(na.omit(roseburia_annot[roseburia_annot$Source=="KO_number" & roseburia_annot$New_locus_tag==rownames(resfilt)[i],3]),collapse=" - ")
  COG_annotations[line]=paste(na.omit(roseburia_annot[roseburia_annot$Source=="COG_number" & roseburia_annot$New_locus_tag==rownames(resfilt)[i],4]),collapse=" - ")
  line=line+1
}



# make and write table for all three species 

results=cbind(Species,Locus_tag, Change, Pval, Padj, COG_categories, COG_numbers, KO_numbers, COG_annotations)
write.table(results, "data_output/results_triculture_vs_monoculture.txt", col.names=T, row.names=F, quote=F, sep="\t")






#### PART 4: Differential expression of F. prausnitzii at 15h vs 3h only in monoculture ####


# first, extract the counts for this genome and create the DESeqDataSet object, this time only in monoculture. The only factor to consider is time

counts_genome=countMatrix[fpra,as.character(metadataFP[metadataFP$type=="single",3])]
metadataFP=metadataFP[metadataFP$type=="single",]
rownames(metadataFP)=metadataFP$experiments
dds=DESeqDataSetFromMatrix(countData = counts_genome,
                           colData = metadataFP,
                           design = ~ time)



# ignore all features with ≤10 counts

keep <- rowSums(counts(dds)) > 10
dds=dds[keep,]



# calculate differential expression at 15h vs 3h for Faecalibacterium + produce an MA-plot

ddseq = DESeq(dds)
res = results(ddseq, contrast=c("time", "15h", "03h"))
plotMA(res)



# extract genes up- vs down- regulated, without imposing any threshold

resfilt=res[!is.na(res$padj) & res$padj<0.05,]
genesUP=rownames(resfilt)[resfilt$log2FoldChange>0] ## UP at 15h vs 3h
genesDW=rownames(resfilt)[resfilt$log2FoldChange<0] ## DW at 15h vs 3h


# load annotation table and perform COG category enrichment using Fisher's exact test

faecalibacterium_annot=read.delim("data/faecalibacterium_annotation.txt", header=T, stringsAsFactors = F, sep="\t")

all_COGs=faecalibacterium_annot[faecalibacterium_annot$Source=="COG_category",3]
UP_COGs=faecalibacterium_annot[faecalibacterium_annot$Source=="COG_category" & faecalibacterium_annot$New_locus_tag %in% genesUP,3]

enrichment(UP_COGs, all_COGs)

all_COGs=faecalibacterium_annot[faecalibacterium_annot$Source=="COG_category",3]
DOWN_COGs=faecalibacterium_annot[faecalibacterium_annot$Source=="COG_category" & faecalibacterium_annot$New_locus_tag %in% genesDW,3]

enrichment(DOWN_COGs, all_COGs) 



# GSEA using package clusterProfiler

T2G=faecalibacterium_annot[faecalibacterium_annot$Source=="COG_category",c(3,5)] # parse annotation file to use as an input for clusterProfiler
genelist=res$log2FoldChange # retrieve list of log2 fold changes for GSEA
names(genelist)=rownames(res)
GSEAgenes=GSEA(sort(genelist, decreasing = T), TERM2GENE = T2G)



# plot GSEA result 

pdf("figures/GSEA_fprausnitzii_15h_vs_3h.pdf")
for(i in rownames(slot(object = GSEAgenes, name = "result"))){
  gseaplot(GSEAgenes, i, title = i, color.line="#E64B35FF", color.vline = "#4DBBD5FF")
  # plot.new()
}
dev.off()



# retrieve results and annotations for Faecalibacterium

COG_numbers=c()
COG_categories=c()
KO_numbers=c()
Species=c()
Change=c()
Pval=c()
Padj=c()
Locus_tag=c()
COG_annotations=c()
line=1
for(i in 1:nrow(resfilt)){
  Species[line]="F. prausnitzii"
  Change[line]=resfilt[i,2]
  Pval[line]=resfilt[i,5]
  Padj[line]=resfilt[i,6]
  Locus_tag[line]=rownames(resfilt)[i]
  COG_categories[line]=paste(na.omit(faecalibacterium_annot[faecalibacterium_annot$Source=="COG_category" & faecalibacterium_annot$New_locus_tag==rownames(resfilt)[i],3]),collapse=" - ")
  COG_numbers[line]=paste(na.omit(faecalibacterium_annot[faecalibacterium_annot$Source=="COG_number" & faecalibacterium_annot$New_locus_tag==rownames(resfilt)[i],3]),collapse=" - ")
  KO_numbers[line]=paste(na.omit(faecalibacterium_annot[faecalibacterium_annot$Source=="KO_number" & faecalibacterium_annot$New_locus_tag==rownames(resfilt)[i],3]),collapse=" - ")
  COG_annotations[line]=paste(na.omit(faecalibacterium_annot[faecalibacterium_annot$Source=="COG_number" & faecalibacterium_annot$New_locus_tag==rownames(resfilt)[i],4]),collapse=" - ")
  line=line+1
}


# make and write table

resultsFP=cbind(Species,Locus_tag, Change, Pval, Padj, COG_categories, COG_numbers, KO_numbers, COG_annotations)
write.table(resultsFP, "data_output/results_fprausnitzii_15h_vs_3h_monoculture.txt", col.names=T, row.names=F, quote=F, sep="\t")

