# set working directory to /output
setwd("../analysis/macro_output")


filenames <- Sys.glob("*.bassoon.csv")  # get a list of bassoon results
BassoonBlobs <- lapply(filenames, function(.file){
  dat<-read.csv(.file, header=T)
  dat$filename<-as.character(.file)
  dat    # return the dataframe
})
BassoonBlobs <- do.call(rbind, BassoonBlobs) # combine into a single dataframe
# E followed by a integer number of any length, followed by a _ and then anything
BassoonBlobs$experiment <- sub("E(\\d*)_.*", "\\1", BassoonBlobs$filename)
# anything followed by _ then a string without _, followed by _ and then again anything
BassoonBlobs$treatment <- sub(".*_([^_]+)_.*", "\\1", BassoonBlobs$filename)
# last number before the dot = anything followed by a number of any length, followed by a . and anything
BassoonBlobs$dish <- sub(".*_(\\d*)\\..*", "\\1", BassoonBlobs$filename)

BassoonBlobs$Munc_count <- as.integer(BassoonBlobs$Munc_count)

BassoonBlobs<-BassoonBlobs[!(BassoonBlobs$Bassoon_id==0),]

library(lattice)

histogram(~Munc_count|experiment+treatment,auto.key=TRUE,data=BassoonBlobs)
histogram(~Munc_count|experiment+treatment,auto.key=TRUE,data=subset(BassoonBlobs,Marker_overlap==1))


histogram(~Bassoon_area|experiment+treatment,auto.key=TRUE,data=subset(BassoonBlobs, Marker_overlap==1))


mypanel <- function(x, color, ...) {
  res <- hist(x, breaks=c(0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15), plot=FALSE);
  xx <- res$breaks
  yy <- cumsum(c(0,res$density))*10
  print(xx)
  print(yy)
  panel.xyplot(xx,yy,type="l")
} 

histogram(~Munc_count|experiment,auto.key=TRUE,groups=treatment, data=BassoonBlobs,
          panel=function(...)panel.superpose(...,panel.groups=mypanel, alpha=0.2, col=c("cyan","magenta")))







# linear mixed effects model including the random effect within each dish
library(nlme)
model = lme(Munc_count ~ treatment, random=~1|dish, data=BassoonBlobs, method="REML")
anova.lme(model, type="sequential", adjustSigma = FALSE)

# simple ANOVA ignoring the random effect 
model2 = aov(Munc_count ~ treatment, data=BassoonBlobs,)
summary(model2)

