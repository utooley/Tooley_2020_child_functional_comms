# Setup -------------------------------------------------------------------
options(rgl.useNULL=TRUE) #if fsbrain not working!
.rs.restartR()

options(scipen = 9)

library(fsbrain) 
library(freesurferformats)
library(dplyr)
library(R.matlab)
library(stringr)
library(ggplot2)
library(tidyr)
library(data.table)
library(boot)
library(RColorBrewer)

#rearrange the order of the brains in the T9 view of fsbrain
source("~/Documents/tools/fsbrain_fix_t9.R")
environment(brainview.t9) <- asNamespace('fsbrain')
assignInNamespace("brainview.t9", brainview.t9, ns = "fsbrain")

# Paths -------------------------------------------------------------------
#CUBIC cluster filepaths, mounted locally
wsbm_datadir="/cbica/projects/spatial_topography/data/imageData/wsbm/site16_training_sample/brains/"
subjects_dir = "/Users/utooley/Documents/tools/CBIG/stable_projects/brain_parcellation/Schaefer2018_LocalGlobal/Parcellations/FreeSurfer5.3/";
yeo_dev_dir="/cbica/projects/spatial_topography/data/imageData/yeo_clustering_networks/yeo7_n670_2runsonly_1000tries_mot_outliers/"
yeo7_ref_dir="/cbica/projects/spatial_topography/tools/CBIG/stable_projects/brain_parcellation/Yeo2011_fcMRI_clustering/1000subjects_reference/"
task_maps_dir="/cbica/projects/spatial_topography/data/imageData/task_maps/"
output_image_directory="/cbica/projects/spatial_topography/output/images/brains/task_maps/"

# Read in files -----------------------------------------------------------
#Vector of WSBM community assignments
partitions <- readMat(paste0(wsbm_datadir,"n670_training_sample_consensus_partitions_yeorelabeled.mat"), drop = )
consensus_representative_labels <-  partitions$consensus.represent.yeorelabeled
consensus_iterative_labels <- partitions$consensus.iter.mode.yeorelabeled

#Read in entropy of co-occurence matrix for representative partition and the frequency of ties
consensus <- readMat(paste0(wsbm_datadir,"consensus_iter_mode.mat"), drop = )
entropy<- consensus$node.entropy #entropy 
freq<- t(consensus$freq) #frequency of ties in the consensus representative partition

#Read in the Yeo developmental vector of assignments
yeo_dev_partition <- readMat(paste0(yeo_dev_dir,"yeo7_n670_2runsonly_1000tries_mot_outliers.mat"), drop = )
#make yeo colors
yeo_colors=colorRampPalette(c("#000000", "#7B287E", "#5CA1C8", "#0A9045","#C33AF8", "#dcf8a4", "#EF9C23", "#E34A53")) #these are corr

# Set defaults ------------------------------------------------------------
subject_id = 'fsaverage';       # for function which use one subject only

#Get the Schaefer atlas region names
schaefer_atlas_region_names_lh = get.atlas.region.names(atlas, template_subjects_dir = subjects_dir,template_subject=subject_id, hemi="lh");
schaefer_atlas_region_names_rh = get.atlas.region.names(atlas, template_subjects_dir = subjects_dir,template_subject=subject_id, hemi="rh");

#Change the output directory for figures to be on the cluster brains
setwd("/cbica/projects/spatial_topography/output/images/brains/")

#Set RGL defaults, larger window and how to make snapshots!
rgloptions=list("windowRect"=c(50,50,1000,1000));

# Read in task data -------------------------------------------------------
#Read in the task data
#FIRST NEED TO CONVERT TO FSAVERAGE OUTSIDE OF R WITH THE SCRIPTtransform_fsLR_task_maps_to_fsaverage.sh, then read in
lh_nback <- read.fs.morph.gii(paste0(task_maps_dir,"ABCD.nBack_2_back_vs_0_back_performance_2back_.lh.41k_fsavg_L.func.gii"), element_index = 1L)
rh_nback <- read.fs.morph.gii(paste0(task_maps_dir,"ABCD.nBack_2_back_vs_0_back_performance_2back_.rh.41k_fsavg_R.func.gii"), element_index = 1L)
nback_2_vs_0_perf <- c(lh_nback,rh_nback)

#Sanity check of plotting
rgloptions=list("windowRect"=c(50,50,1000,1000));
rglactions=list('shift_hemis_apart'=list('min_dist'=100), "snapshot_png"=paste0(output_image_directory,"nback.png"))
colFn_diverging = grDevices::colorRampPalette(rev(RColorBrewer::brewer.pal(11, name="RdBu")));
makecmap_options=list('colFn'=colFn_diverging, 'n'=100, 'symm'= TRUE)
vis.data.on.subject(subjects_dir, 'fsaverage6',lh_nback, rh_nback, "inflated", views="t9", makecmap_options = makecmap_options,
                    rgloptions = rgloptions, rglactions = rglactions, draw_colorbar = TRUE)

# Make a frontoparietal system conjunction map -----------------------------------
#Just take top of nback 2 vs 0
nback_2_vs_0_top <- rep(0, length(nback_2_vs_0_perf))
nback_2_vs_0_top[nback_2_vs_0_perf>quantile(nback_2_vs_0_perf, probs = 0.80)] <- 1
#Look at this
overlap_colors=colorRampPalette(c("white", "#D6604D"))
rglactions=list("snapshot_png"=paste0(output_image_directory,"nback_top_20.png"))
makecmap_options=list('colFn'=overlap_colors)
vis.data.on.subject(subjects_dir, 'fsaverage6',nback_2_vs_0_top[0:40962], nback_2_vs_0_top[40963:81924], "inflated", views="t4", makecmap_options = makecmap_options,
                    rgloptions = rgloptions,rglactions = rglactions, draw_colorbar = TRUE)

# Make a default system conjunction map -----------------------------------
# Just take bottom 20% of nback
nback_2_vs_0_bottom <- rep(0, length(nback_2_vs_0_perf))
nback_2_vs_0_bottom[nback_2_vs_0_perf<quantile(nback_2_vs_0_perf, probs = 0.20)] <- 1

#Look at this overlap
overlap_colors=colorRampPalette(c("white", "#92C5DE"))
rglactions=list("snapshot_png"=paste0(output_image_directory,"nback_bottom_20.png"))
makecmap_options=list('colFn'=overlap_colors, 'n'=12)
vis.data.on.subject(subjects_dir, 'fsaverage6',yeo7_7[0:40962], yeo7_7[40963:81924], "inflated", views="t4", makecmap_options = makecmap_options,
                    rgloptions = rgloptions, rglactions = rglactions, draw_colorbar = TRUE)

###################################
########## COMPARE TO PARTITIONS ######
###################################
#Yeo adult
#read in the Freesurfer version of Yeo7 in  fsaverage6 space
subjects_dir = "/Users/utooley/Documents/tools/parcellations/Yeo_from_freesurfer/";
lh <- subject.annot(subjects_dir, 'fsaverage6', 'lh','Yeo2011_7Networks_N1000' )
yeo7_lh <- as.numeric(str_split(lh$label_names, "_", simplify = TRUE)[,2])
yeo7_lh[is.na(yeo7_lh)] <- 0
rh <- subject.annot(subjects_dir, 'fsaverage6', 'rh','Yeo2011_7Networks_N1000' )
yeo7_rh <- as.numeric(str_split(rh$label_names, "_", simplify = TRUE)[,2])
yeo7_rh[is.na(yeo7_rh)] <- 0
yeo7 <- c(yeo7_lh,yeo7_rh)

#Yeo dev
yeo_dev_lh <- yeo_dev_partition$lh.labels
yeo_dev_rh <- yeo_dev_partition$rh.labels
yeo_dev <- c(yeo_dev_lh,yeo_dev_rh)
#annotation
yeodev_lh <- subject.annot(subjects_dir, 'fsaverage6', 'lh','yeodev.fsaverage6')
yeodev_rh <- subject.annot(subjects_dir, 'fsaverage6', 'rh','yeodev.fsaverage6')

#WSBM but in fsaverage6 space
get.atlas.region.names("wsbm.consensus.fsaverage6", template_subjects_dir = subjects_dir,template_subject='fsaverage6', hemi="rh");
wsbm_rh_annot <- subject.annot(subjects_dir, 'fsaverage6', 'rh','wsbm.consensus.fsaverage6')
wsbm_rh<- as.numeric(as.character(wsbm_rh_annot$label_names))
wsbm_lh_annot <- subject.annot(subjects_dir, 'fsaverage6', 'lh','wsbm.consensus.fsaverage6')
wsbm_lh<- as.numeric(as.character(wsbm_lh_annot$label_names))
wsbm <- c(wsbm_lh,wsbm_rh)

# Compare partition assignments-Frontoparietal---------------------------------------------
library(igraph);library(aricode);library(mclustcomp)
output_image_directory="/cbica/projects/spatial_topography/output/images/brains/task_maps/"

fs6_lh <- read.fs.surface(paste0(subjects_dir, "fsaverage6/surf/lh.inflated"))
fs6_rh <- read.fs.surface(paste0(subjects_dir, "fsaverage6/surf/rh.inflated"))

#Just binary overlap, Dice coefficient
wsbm_6 =ifelse(wsbm==6,1,0)
yeo_dev_6=ifelse(yeo_dev==6,1,0)
yeo7_6=ifelse(yeo7==6,1,0)#about the same as yeo_dev

wsbm_to_nback <- mclustcomp(wsbm_6,nback_2_vs_0_top, types = c("jaccard", "sdc")) #for binary vectors
yeo_dev_to_nback <- mclustcomp(yeo_dev_6,nback_2_vs_0_top,  types = c("jaccard", "sdc")) #for binary vectors
yeo_adult_to_nback <-  mclustcomp(yeo7_6,nback_2_vs_0_top,  types = c("jaccard", "sdc")) #for binary vectors
cbind(yeo_adult_to_nback,yeo_dev_to_nback,wsbm_to_nback)

###########################
# Plot overlap with Yeo adult #
###########################
yeo7_fp_bord_lh <- annot.outline(lh,fs6_lh, outline_color = "black", limit_to_regions = "7Networks_6")
yeo7_fp_bord_rh <- annot.outline(rh,fs6_rh, outline_color = "black", limit_to_regions = "7Networks_6")
fp_bord <- c(yeo7_fp_bord_lh,yeo7_fp_bord_rh)
#overlay with deactivation
yeo7_fp_bord_overlay <- ifelse(fp_bord=="black","black", nback_2_vs_0_top)
yeo7_fp_bord_overlay[yeo7_fp_bord_overlay=="1"] <- "#D6604D" #change to characters of colors
yeo7_fp_bord_overlay[yeo7_fp_bord_overlay=="0"] <- "white"
rglactions=list("snapshot_png"=paste0(output_image_directory,"yeo7/yeo7_fp_bord_overlay_nback_pos_betas.png"))
vis.color.on.subject(subjects_dir, 'fsaverage6',yeo7_fp_bord_overlay[0:40962],yeo7_fp_bord_overlay[40963:81924], "inflated", views="t4",
                     rgloptions = rgloptions, rglactions = rglactions)
###########################
# Plot overlap with Yeo dev #
###########################
yeodev_fp_bord_lh <- annot.outline(yeodev_lh,fs6_lh, outline_color = "black", limit_to_regions = "NONAME6")
yeodev_fp_bord_rh <- annot.outline(yeodev_rh,fs6_rh, outline_color = "black", limit_to_regions = "NONAME6")
fp_bord <- c(yeodev_fp_bord_lh,yeodev_fp_bord_rh)
vis.color.on.subject(subjects_dir, 'fsaverage6',fp_bord[0:40962],fp_bord[40963:81924], "inflated", views="t4",
                     rgloptions = rgloptions)
#overlay with deactivation
yeodev_fp_bord_overlay <- ifelse(fp_bord=="black","black", nback_2_vs_0_top)
yeodev_fp_bord_overlay[yeodev_fp_bord_overlay=="1"] <- "#D6604D" #change to characters of colors
yeodev_fp_bord_overlay[yeodev_fp_bord_overlay=="0"] <- "white"
rglactions=list("snapshot_png"=paste0(output_image_directory,"yeodev/yeodev_fp_bord_overlay_nback_pos_betas.png"))
vis.color.on.subject(subjects_dir, 'fsaverage6',yeodev_fp_bord_overlay[0:40962],yeodev_fp_bord_overlay[40963:81924], "inflated", views="t4",
                     rgloptions = rgloptions, rglactions = rglactions)

###########################
# Plot overlap with WSBM #
###########################
wsbm_fp_bord_lh <- annot.outline(wsbm_lh_annot,fs6_lh, outline_color = "black", limit_to_regions = "6")
wsbm_fp_bord_rh <- annot.outline(wsbm_rh_annot,fs6_rh, outline_color = "black", limit_to_regions = "6")
fp_bord <- c(wsbm_fp_bord_lh,wsbm_fp_bord_rh)
vis.color.on.subject(subjects_dir, 'fsaverage6',fp_bord[0:40962],fp_bord[40963:81924], "inflated", views="t4",
                     rgloptions = rgloptions)
#overlay with deactivation
wsbm_fp_bord_overlay <- ifelse(fp_bord=="black","black", nback_2_vs_0_top)
wsbm_fp_bord_overlay[wsbm_fp_bord_overlay=="1"] <- "#D6604D" #change to characters of colors
wsbm_fp_bord_overlay[wsbm_fp_bord_overlay=="0"] <- "white"
rglactions=list("snapshot_png"=paste0(output_image_directory,"wsbm/wsbm_fp_bord_overlay_nback_pos_betas.png"))
vis.color.on.subject(subjects_dir, 'fsaverage6',wsbm_fp_bord_overlay[0:40962],wsbm_fp_bord_overlay[40963:81924], "inflated", views="t4",
                     rgloptions = rgloptions, rglactions = rglactions)

##### Sum of betas within the system ####
yeo7_6_betas <- ifelse(yeo7_6==1, nback_2_vs_0_perf, 0)
yeo_dev_6_betas <- ifelse(yeo_dev_6==1, nback_2_vs_0_perf, 0)
wsbm_6_betas <- ifelse(wsbm_6==1, nback_2_vs_0_perf, 0)

#Sanity check of plotting
rgloptions=list("windowRect"=c(50,50,1000,1000));
rglactions=list("snapshot_png"=paste0(output_image_directory,"nback_pos_betas_wsbm.png"))
colFn_diverging = grDevices::colorRampPalette(rev(RColorBrewer::brewer.pal(11, name="RdBu")));
makecmap_options=list('colFn'=colFn_diverging, 'n'=100, 'symm'=TRUE)
vis.data.on.subject(subjects_dir, 'fsaverage6', wsbm_6_betas[0:40962], wsbm_6_betas[40963:81924], "inflated", views="t4", makecmap_options = makecmap_options,
                    rgloptions = rgloptions, rglactions = rglactions, draw_colorbar = TRUE)
rglactions=list("snapshot_png"=paste0(output_image_directory,"nback_pos_betas_yeo_dev.png"))
vis.data.on.subject(subjects_dir, 'fsaverage6', yeo_dev_6_betas[0:40962], yeo_dev_6_betas[40963:81924], "inflated", views="t4", makecmap_options = makecmap_options,
                    rgloptions = rgloptions, rglactions = rglactions, draw_colorbar = TRUE)
rglactions=list("snapshot_png"=paste0(output_image_directory,"nback_pos_betas_yeo7.png"))
vis.data.on.subject(subjects_dir, 'fsaverage6', yeo7_6_betas[0:40962], yeo7_6_betas[40963:81924], "inflated", views="t4", makecmap_options = makecmap_options,
                    rgloptions = rgloptions, rglactions = rglactions, draw_colorbar = TRUE)

#########################################
### Bootstrap Dice coefficient--WSBM ####
#########################################
#already saved, can load and skip
load("~/Documents/projects/in_progress/spatial_topography_CUBIC/data/bootstrapped_CIs_frontoparietal.RData")
wsbm_to_nback <- data.frame(wsbm_6,nback_2_vs_0_top)
dice_wsbm_Boot_CI<-function(x,indices){
  tempdat<-wsbm_to_nback[indices,]
  dice <- mclustcomp(tempdat$wsbm_6,tempdat$nback_2_vs_0_top, types = c("sdc"))
  return(dice$scores)
}
set.seed(598370)
results_wsbm <- boot(data=wsbm_to_nback, statistic=dice_wsbm_Boot_CI, R=1000, simple=TRUE, parallel="multicore")
CI_wsbm_6 <- boot.ci(results_wsbm, type="basic")
CI_wsbm_6
CI_wsbm_6 <- boot.ci(results_wsbm, type="perc")
boot.ci(results, type = "bca")

### Bootstrap Dice coefficient--Yeo-dev ###
yeodev_to_nback <- data.frame(yeo_dev_6,nback_2_vs_0_top)
dice_yeodev_Boot_CI<-function(x,indices){
  tempdat<-yeodev_to_nback[indices,]
  dice <- mclustcomp(tempdat$yeo_dev_6,tempdat$nback_2_vs_0_top, types = c("sdc"))
  return(dice$scores)
}
set.seed(598370)
results_yeodev <- boot(data=yeodev_to_nback, statistic=dice_yeodev_Boot_CI, R=1000, simple=TRUE, parallel="multicore")
CI_yeodev_6 <- boot.ci(results_yeodev, type="basic")
CI_yeodev_6
CI_yeodev_6 <- boot.ci(results_yeodev, type="perc") #This is what I'm using
boot.ci(results_yeodev, type = "bca")

### Bootstrap Dice coefficient--Yeo7 ###
yeo7_to_nback <- data.frame(yeo7_6,nback_2_vs_0_top)
dice_yeo7_Boot_CI<-function(x,indices){
  tempdat<-yeo7_to_nback[indices,]
  dice <- mclustcomp(tempdat$yeo7_6,tempdat$nback_2_vs_0_top, types = c("sdc"))
  return(dice$scores)
}
set.seed(598370)
results_yeo7 <- boot(data=yeo7_to_nback, statistic=dice_yeo7_Boot_CI, R=1000, simple=TRUE, parallel="multicore")
CI_yeo7_6 <- boot.ci(results_yeo7, type="basic")
CI_yeo7_6
CI_yeo7_6 <- boot.ci(results_yeo7, type="perc")
boot.ci(results_yeodev, type = "bca")

save(results_yeo7, results_yeodev, results_wsbm, file= paste0("~/Documents/projects/in_progress/spatial_topography_CUBIC/data/bootstrapped_CIs_frontoparietal.RData"))

##########################
####### PLOTTING BETAS #########
##########################
data <- data.frame(yeo7_6_betas, yeo_dev_6_betas, wsbm_6_betas)
colnames(data) <- c('yeo7', 'yeo_dev', 'wsbm')
longdata <- melt(data)
longdata <- longdata[longdata$value != 0.0000000,]#remove the medial wall
longdata <- longdata[longdata$value > 0,]#remove the medial wall
colnames(longdata) <- c('partition', 'betas')
longdata$partition <- factor(longdata$partition,levels = c("wsbm","yeo_dev","yeo7"))
longdata = longdata %>% 
  dplyr::group_by(partition) %>% 
  mutate(med = median(betas))

## Raincloud plot
source("~/Documents/tools/raincloud.R")
g <- ggplot(data = longdata, aes(y = betas, x = partition, fill = med)) +
  geom_flat_violin(position = position_nudge(x = .2, y = 0), alpha = .8) +
  geom_point(aes(y = betas, color = betas), position = position_jitter(width = .15), size = .3, alpha = 0.5) +
  geom_boxplot(width = .1, guides = FALSE, outlier.shape = NA, alpha = 0.5) +
  expand_limits(x = 5.25) +
  guides(fill = FALSE) +
  guides(color = FALSE) +
  # scale_color_manual(values=c("#4669dc","pink","purple")) +
  scale_color_distiller(palette="Reds", direction = 1) +
  scale_fill_distiller(palette="Reds", direction = 1) +
  #scale_color_gradient2(low="#FFFFFF",mid= "#FB6A4A", high="#67000D", midpoint= 0.475, aesthetics = c("color", "fill")) +
  coord_flip() +
  theme_bw() +
  raincloud_theme
g

longdata %>% group_by(partition) %>% summarise_all(sd)
#Stats
kruskal.test(betas~partition, data = longdata)
pairwise.wilcox.test(longdata$betas, longdata$partition,
                     p.adjust.method = "bonferroni")

#need to take out 0's here
wilcox.test(data$yeo7,data$yeo_dev)

# Compare partition assignments-Default ---------------------------------------------
library(igraph);library(aricode);library(mclustcomp)

fs6_lh <- read.fs.surface(paste0(subjects_dir, "fsaverage6/surf/lh.inflated"))
fs6_rh <- read.fs.surface(paste0(subjects_dir, "fsaverage6/surf/rh.inflated"))

###########################
# Plot overlap with Yeo adult #
###########################
yeo7_dm_bord_lh <- annot.outline(lh,fs6_lh, outline_color = "black", limit_to_regions = "7Networks_7")
yeo7_dm_bord_rh <- annot.outline(rh,fs6_rh, outline_color = "black", limit_to_regions = "7Networks_7")
dm_bord <- c(yeo7_dm_bord_lh,yeo7_dm_bord_rh)
#overlay with deactivation
yeo7_dm_bord_overlay <- ifelse(dm_bord=="black","black", nback_2_vs_0_bottom)
yeo7_dm_bord_overlay[yeo7_dm_bord_overlay=="1"] <- "#92C5DE" #change to characters of colors
yeo7_dm_bord_overlay[yeo7_dm_bord_overlay=="0"] <- "white"
rglactions=list("snapshot_png"=paste0(output_image_directory,"yeo7/yeo7_dm_bord_overlay_nback_neg_betas.png"))
vis.color.on.subject(subjects_dir, 'fsaverage6',yeo7_dm_bord_overlay[0:40962],yeo7_dm_bord_overlay[40963:81924], "inflated", views="t4",
                     rgloptions = rgloptions, rglactions = rglactions)
###########################
# Plot overlap with Yeo dev #
###########################
yeodev_dm_bord_lh <- annot.outline(yeodev_lh,fs6_lh, outline_color = "black", limit_to_regions = "NONAME7")
yeodev_dm_bord_rh <- annot.outline(yeodev_rh,fs6_rh, outline_color = "black", limit_to_regions = "NONAME7")
dm_bord <- c(yeodev_dm_bord_lh,yeodev_dm_bord_rh)
vis.color.on.subject(subjects_dir, 'fsaverage6',dm_bord[0:40962],dm_bord[40963:81924], "inflated", views="t4",
                     rgloptions = rgloptions)
#overlay with deactivation
yeodev_dm_bord_overlay <- ifelse(dm_bord=="black","black", nback_2_vs_0_bottom)
yeodev_dm_bord_overlay[yeodev_dm_bord_overlay=="1"] <- "#92C5DE" #change to characters of colors
yeodev_dm_bord_overlay[yeodev_dm_bord_overlay=="0"] <- "white"
rglactions=list("snapshot_png"=paste0(output_image_directory,"yeodev/yeodev_dm_bord_overlay_nback_neg_betas.png"))
vis.color.on.subject(subjects_dir, 'fsaverage6',yeodev_dm_bord_overlay[0:40962],yeodev_dm_bord_overlay[40963:81924], "inflated", views="t4",
                     rgloptions = rgloptions, rglactions = rglactions)

###########################
# Plot overlap with WSBM #
###########################
wsbm_dm_bord_lh <- annot.outline(wsbm_lh_annot,fs6_lh, outline_color = "black", limit_to_regions = "7")
wsbm_dm_bord_rh <- annot.outline(wsbm_rh_annot,fs6_rh, outline_color = "black", limit_to_regions = "7")
dm_bord <- c(wsbm_dm_bord_lh,wsbm_dm_bord_rh)
vis.color.on.subject(subjects_dir, 'fsaverage6',dm_bord[0:40962],dm_bord[40963:81924], "inflated", views="t4",
                     rgloptions = rgloptions)
#overlay with deactivation
wsbm_dm_bord_overlay <- ifelse(dm_bord=="black","black", nback_2_vs_0_bottom)
wsbm_dm_bord_overlay[wsbm_dm_bord_overlay=="1"] <- "#92C5DE" #change to characters of colors
wsbm_dm_bord_overlay[wsbm_dm_bord_overlay=="0"] <- "white"
rglactions=list("snapshot_png"=paste0(output_image_directory,"wsbm/wsbm_dm_bord_overlay_nback_neg_betas.png"))
vis.color.on.subject(subjects_dir, 'fsaverage6',wsbm_dm_bord_overlay[0:40962],wsbm_dm_bord_overlay[40963:81924], "inflated", views="t4",
                     rgloptions = rgloptions, rglactions = rglactions)

# Binary overlap-dice coefficient -----------------------------------------
wsbm_7 =ifelse(wsbm==7,1,0)
yeo_dev_7=ifelse(yeo_dev==7,1,0)
yeo7_7=ifelse(yeo7==7,1,0)#about the same as yeo_dev

wsbm_to_nback <- mclustcomp(wsbm_7,nback_2_vs_0_bottom, types = c("jaccard", "sdc")) #for binary vectors
yeo_dev_to_nback <- mclustcomp(yeo_dev_7,nback_2_vs_0_bottom,  types = c("jaccard", "sdc")) #for binary vectors
yeo_adult_to_nback <-  mclustcomp(yeo7_7,nback_2_vs_0_bottom,  types = c("jaccard", "sdc")) #for binary vectors
cbind(yeo_adult_to_nback,yeo_dev_to_nback,wsbm_to_nback)

#########################################
### Bootstrap Dice coefficient--WSBM ####
#########################################
load("~/Documents/projects/in_progress/spatial_topography_CUBIC/data/bootstrapped_CIs_default.RData")
#if it's already done, just load the above
wsbm_to_nback <- data.frame(wsbm_7,nback_2_vs_0_bottom)
dice_wsbm_Boot_CI<-function(x,indices){
  tempdat<-wsbm_to_nback[indices,]
  dice <- mclustcomp(tempdat$wsbm_7,tempdat$nback_2_vs_0_bottom, types = c("sdc"))
  return(dice$scores)
}
set.seed(598370)
results_wsbm <- boot(data=wsbm_to_nback, statistic=dice_wsbm_Boot_CI, R=1000, simple=TRUE, parallel="multicore")
CI_wsbm_7 <- boot.ci(results_wsbm, type="basic")
CI_wsbm_7 <- boot.ci(results_wsbm, type="perc")
CI_wsbm_7
boot.ci(results, type = "bca")

### Bootstrap Dice coefficient--Yeo-dev ###
yeodev_to_nback <- data.frame(yeo_dev_7,nback_2_vs_0_bottom)
dice_yeodev_Boot_CI<-function(x,indices){
  tempdat<-yeodev_to_nback[indices,]
  dice <- mclustcomp(tempdat$yeo_dev_7,tempdat$nback_2_vs_0_bottom, types = c("sdc"))
  return(dice$scores)
}
set.seed(598370)
results_yeodev <- boot(data=yeodev_to_nback, statistic=dice_yeodev_Boot_CI, R=1000, simple=TRUE, parallel="multicore")
CI_yeodev_7 <- boot.ci(results_yeodev, type="basic")
CI_yeodev_7 <- boot.ci(results_yeodev, type="perc") #This is what I'm using
boot.ci(results_yeodev, type = "bca")

### Bootstrap Dice coefficient--Yeo7 ###
yeo7_to_nback <- data.frame(yeo7_7,nback_2_vs_0_bottom)
dice_yeo7_Boot_CI<-function(x,indices){
  tempdat<-yeo7_to_nback[indices,]
  dice <- mclustcomp(tempdat$yeo7_7,tempdat$nback_2_vs_0_bottom, types = c("sdc"))
  return(dice$scores)
}
set.seed(598370)
results_yeo7 <- boot(data=yeo7_to_nback, statistic=dice_yeo7_Boot_CI, R=1000, simple=TRUE, parallel="multicore")
CI_yeo7_7 <- boot.ci(results_yeo7, type="basic")
CI_yeo7_7 <- boot.ci(results_yeo7, type="perc")
boot.ci(results_yeodev, type = "bca")

save(results_yeo7, results_yeodev, results_wsbm, file= paste0("~/Documents/projects/in_progress/spatial_topography_CUBIC/data/bootstrapped_CIs_default.RData"))

##### Sum of betas within the system ####
yeo7_7_betas <- ifelse(yeo7_7==1, nback_2_vs_0_perf, 0)
yeo_dev_7_betas <- ifelse(yeo_dev_7==1, nback_2_vs_0_perf, 0)
wsbm_7_betas <- ifelse(wsbm_7==1, nback_2_vs_0_perf, 0)

#Sanity check of plotting
rgloptions=list("windowRect"=c(50,50,1000,1000));
rglactions=list("snapshot_png"=paste0(output_image_directory,"nback_betas_wsbm.png"))
colFn_diverging = grDevices::colorRampPalette(rev(RColorBrewer::brewer.pal(11, name="RdBu")));
makecmap_options=list('colFn'=colFn_diverging, 'n'=100, 'symm'=TRUE)
vis.data.on.subject(subjects_dir, 'fsaverage6', wsbm_7_betas[0:40962], wsbm_7_betas[40963:81924], "inflated", views="t4", makecmap_options = makecmap_options,
                    rgloptions = rgloptions, rglactions = rglactions, draw_colorbar = TRUE)
rglactions=list("snapshot_png"=paste0(output_image_directory,"nback_betas_yeo_dev.png"))
vis.data.on.subject(subjects_dir, 'fsaverage6', yeo_dev_7_betas[0:40962], yeo_dev_7_betas[40963:81924], "inflated", views="t4", makecmap_options = makecmap_options,
                    rgloptions = rgloptions, rglactions = rglactions, draw_colorbar = TRUE)
rglactions=list("snapshot_png"=paste0(output_image_directory,"nback_betas_yeo7.png"))
vis.data.on.subject(subjects_dir, 'fsaverage6', yeo7_7_betas[0:40962], yeo7_7_betas[40963:81924], "inflated", views="t4", makecmap_options = makecmap_options,
                    rgloptions = rgloptions, rglactions = rglactions, draw_colorbar = TRUE)

##########################
####### PLOTTING BETAS #########
##########################
data <- data.frame(yeo7_7_betas, yeo_dev_7_betas, wsbm_7_betas)
colnames(data) <- c('yeo7', 'yeo_dev', 'wsbm')
longdata <- melt(data)
longdata <- longdata[longdata$value != 0.0000000,]#remove the medial wall
longdata <- longdata[longdata$value < 0,]#look at what is most negative and not least positive
colnames(longdata) <- c('partition', 'betas')
longdata$partition <- factor(longdata$partition,levels = c("wsbm","yeo_dev","yeo7"))
longdata = longdata %>% 
  dplyr::group_by(partition) %>% 
  mutate(med = median(betas))

## Raincloud plot
source("~/Documents/tools/raincloud.R")
g <- ggplot(data = longdata, aes(y = betas, x = partition, fill=med)) +
  geom_flat_violin(position = position_nudge(x = .2, y = 0), alpha = .8) +
  geom_point(aes(y = betas, color = betas), position = position_jitter(width = .15), size = .3, alpha = 0.5) +
  geom_boxplot(width = .1, guides = FALSE, outlier.shape = NA, alpha = 0.8) +
  expand_limits(x = 5.25) +
  guides(fill = FALSE) +
  guides(color = FALSE) +
  #scale_color_gradient2(low="#08306B", mid= "#58A1CE",high="#FFFFFF", midpoint=-0.35, aesthetics = c("color", "fill")) +
  scale_color_distiller(palette="Blues", direction = -1) +
  scale_fill_distiller(palette="Blues", direction = -1) +
  #scale_fill_gradient2() +
  coord_flip() +
  theme_bw() +
  raincloud_theme
g

longdata %>% group_by(partition) %>% summarise_all(sd)

#Stats
kruskal.test(betas~partition, data = longdata)
pairwise.wilcox.test(longdata$betas, longdata$partition,
                     p.adjust.method = "bonferroni")

# Stats for overleaf ------------------------------------------------------
#Task maps dice coefficients
task_betas_fp <- longdata
task_betas_dm <- longdata

CI_yeodev_6$percent[1,5]
save(task_betas_fp,wsbm_to_nback_6, yeo_dev_to_nback_6,yeo_adult_to_nback_6,task_betas_dm,
     wsbm_to_nback_7, yeo_dev_to_nback_7, yeo_adult_to_nback_7, CI_yeo7_7, CI_wsbm_7, CI_yeodev_7, CI_yeo7_6, 
     CI_yeodev_6, CI_wsbm_6, file= "~/Downloads/Task_map_data.RData")