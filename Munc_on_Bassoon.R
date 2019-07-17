# set working directory to /output
setwd("output/")

# read data from csv
bassoon <- read.csv("example_data_3channel.tif.bassoon.csv")
munc <- read.csv("example_data_3channel.tif.munc.csv")

# specify threshold for synapse type marker
marker_threshold = 100

# which basson blobs express the synapse type marker
ids <- bassoon[bassoon$Mean>marker_threshold, 1]

# which vesicles belong to these bassoon blobs
kept_vesicles <- munc[munc$Bassoon_id %in% ids,]

# vesicle mean area (and SD) and vesicle number per basson blob
vesicles_per_synapse <- aggregate(Area~Bassoon_id, data=kept_vesicles, FUN=function(x) c(Mean=mean(x),SD=sd(x),count=length(x)))


## Misc
# Some plot
library(lattice)
densityplot(~Mean,data=bassoon)

# Some statistics about area depending on marker expression
munc$marker <- munc$Bassoon_id %in% ids
aggregate(marker~Bassoon_id, data=munc, FUN=function(x) c(marker = mean(x),count=length(x)))

munc$Bassoon_id = as.factor(munc$Bassoon_id)

# linear mixed effects model including the random effect 
# within each bassoon spot  => p=0.5353
library(nlme)
model = lme(Area ~ marker, random=~1|Bassoon_id, data=munc, method="REML")
anova.lme(model, type="sequential", adjustSigma = FALSE)

# simple ANOVA ignoring the random effect => p=0.741
model2 = aov(Area ~ marker, data=munc)
summary(model2)

