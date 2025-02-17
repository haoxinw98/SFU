# Random Forest classification on Wheat Data
##########
# Enter data and do some processing
wheat <-  read.csv("C:\\Users\\Tom loughin\\sfuvault\\452 Statistical Learning\\R\\wheat.csv")
head(wheat)
#summary(wheat)

# Variable "type" is the response variable.  "class" is another explanatory.
class(wheat$type)
wheat$type = as.factor(wheat$type)
wheat$class = as.factor(wheat$class)
#summary(wheat)

# Create a numerical version of "class" for methods that need numbers
wheat$classnum <- as.numeric((wheat$class))
# Remove "id"
wheat = wheat[,-1]
#summary(wheat)

############
# Creating TWO sets: 200 train, 75 test
set.seed(67982193)
perm <- sample(x=nrow(wheat))
set1 <- wheat[which(perm <= 200),-1]
set2 <- wheat[which(perm>200),-1]


library(nnet)

############
## Computing will work better if explanatories are rescaled to lie in [0,1]
############
# Function that rescales x1 to x2's min and max
# If applied to itself, produces data scaled to lie within [0,1].

x.1.unscaled <- as.matrix(set1[,-6])
x.2.unscaled <- as.matrix(set2[,-6])

rescale <- function(x1,x2){
  for(col in 1:ncol(x1)){
    a <- min(x2[,col])
    b <- max(x2[,col])
    x1[,col] <- (x1[,col]-a)/(b-a)
  }
  x1
}

x.1 <- rescale(x.1.unscaled, x.1.unscaled)
#Prove that it worked
apply(X=x.1, MARGIN=2, FUN=min)
apply(X=x.1, MARGIN=2, FUN=max)

# Could have been done using apply() and scale()
#rescale2 <- function(x1,x2){
#  minx <- apply(X=x2, MARGIN=2, FUN=min)
#  maxx <- apply(X=x2, MARGIN=2, FUN=max)
#  scale(x=x1, center=minx, scale=max)
#}
#x.12 <- rescale2(x.1.unscaled, x.1.unscaled)
#summary(x.1-x.12) # ALL ZEROES!

x.2 <- rescale(x.2.unscaled, x.1.unscaled)
#Prove that it worked, but does not perfectly scale test set
apply(X=x.2, MARGIN=2, FUN=min)
apply(X=x.2, MARGIN=2, FUN=max)


########################################################################
## Responses for SOFTMAX classification must be matrix of indicators 
## for each category.  These are created by class.ind().
########################################################################

y.1 <- class.ind(set1[,6])
y.2 <- class.ind(set2[,6])
head(cbind(set1[,6],y.1))

###########################################################################
# nnet{nnet} can do regression or classification.
#  For classification, MUST SPECIFY "softmax=TRUE"), 
#  Only allows one hidden layer, generates initial weights randomly
#  NO DEFAULT SHRINKAGE ("weight decay"), must specify number of hidden nodes. 
# Recommend shrinkage between .01 and .0001 (Venables and Ripley 2002, Sec 8.10)
#  I find that larger shrinkage (up to 1, even) can also work sometimes
###########################################################################

### Fit to set 1, Test on Set 2
nn.1.0 <- nnet(x=x.1, y=y.1, size=1, maxit=1000, softmax=TRUE)
# Train error
p1.nn.1.0m <-predict(nn.1.0, newdata=x.1, type="raw")
round(head(p1.nn.1.0m), 3)
p1.nn.1.0 <-predict(nn.1.0, newdata=x.1, type="class")
table(p1.nn.1.0, as.factor(set1$type),  dnn=c("Predicted","Observed"))
(misclass1.1.0 <- mean(ifelse(p1.nn.1.0 == set1$type, yes=0, no=1)))

# Test set error
p2.nn.1.0 <-predict(nn.1.0, newdata=x.2, type="class")
table(p2.nn.1.0, as.factor(set2$type),  dnn=c("Predicted","Observed"))
(misclass2.1.0 <- mean(ifelse(p2.nn.1.0 == set2$type, yes=0, no=1)))

#############################################
# Try tuning with caret::train
# "caret" stands for "classification and regression training"
# See http://topepo.github.io/caret/training.html for full details
# 
# Uses resampling (default is 25 bootstrap runs) to tune to a 
#   specified grid.  Seems excessive if time is an issue
# HOWEVER, Does only one run per combination.
#
# "Accuracy" = 1-<misclassification rate>
# "Kappa" is Cohen's Kappa, a version of misclassificaiton rate adjusted for chance.
#   Proportional improvement in misclassification relative to random assignment.
#
# Note: I am just showing this caret::train function here.  Can tune any way you like.
#############################################
library(caret)

#Using 10-fold CV so that training sets are not too small
#  ( Starting with 200 in training set)
trcon = trainControl(method="repeatedcv", number=10, repeats=2,
                     returnResamp="all")
parmgrid = expand.grid(size=c(1,3,6,10),decay= c(0,0.001,0.01,0.1))

tuned.nnet <- train(x=x.1, y=set1$type, method="nnet", preProcess="range", trace=FALSE, 
                    tuneGrid=parmgrid, trControl = trcon)

names(tuned.nnet)
tuned.nnet$results[order(-tuned.nnet$results[,3]),]
tuned.nnet$bestTune
head(tuned.nnet$resample)
tail(tuned.nnet$resample)

# Let's rearrange the data so that we can plot the bootstrap resamples in 
#   our usual way, including relative to best
resamples = reshape(data=tuned.nnet$resample[,-2], idvar=c("size", "decay"), 
                    timevar="Resample", direction="wide")
head(resamples)
(best = apply(X=resamples[,-c(1,2)], MARGIN=2, FUN=max))
siz.dec <- paste(resamples[,1],"-",resamples[,2])

x11()
boxplot.matrix(x=t(t(1-resamples[,-c(1:2)])), use.cols=FALSE, names=siz.dec,
               main="Misclassification rates for different Size-Decay", las=2)

x11()
boxplot.matrix(x=t(t(1-resamples[,-c(1:2)])/(1-best)), use.cols=FALSE, names=siz.dec,
               main="Relative Misclass rates for different Size-Decay", las=2)

x11(h=7, w=10)
par(mfrow=c(1,2))
boxplot(t(t(1-resamples[,-c(1:2)])/(1-best)) ~ resamples[,1], xlab="Size", ylab="Relative Error")
boxplot(t(t(1-resamples[,-c(1:2)])/(1-best)) ~ resamples[,2], xlab="Decay", ylab="Relative Error")
#################################################################
# Write a CV tuner that uses multiple restarts
##################################################################
# WARNING: Can run LONG!  PARALLELIZE!

#For simplicity, rename data as "train.x" and "train.y"
train.x = set1[,-6]
train.y.class = set1[,6] 
train.y = class.ind(train.y.class)

#  Let's do R=2 reps of V=10-fold CV.
set.seed(74375641)
V=10
R=2 
n2 = nrow(train.x)
# Create the folds and save in a matrix
folds = matrix(NA, nrow=n2, ncol=R)
for(r in 1:R){
  folds[,r]=floor((sample.int(n2)-1)*V/n2) + 1
}

# Grid for tuning parameters and number of restarts of nnet
siz <- c(1,3,6,10)
dec <- c(0.0001,0.001,0.01,0.1)
nrounds=10

# Prepare matrix for storing results: 
#   row = 1 combination of tuning parameters
#   column = 1 split
#   Add grid values to first two columns

Mis.cv = matrix(NA, nrow=length(siz)*length(dec), ncol=V*R+2)
Mis.cv[,1:2] = as.matrix(expand.grid(siz,dec))

# Start loop over all reps and folds.  
for (r in 1:R){ 
  for(v in 1:V){
    
    y.1 <- as.matrix(train.y[folds[,r]!=v,])
    x.1.unscaled <- as.matrix(train.x[folds[,r]!=v,]) 
    x.1 <- rescale(x.1.unscaled, x.1.unscaled) 
    
    #Test
    y.2 <- as.matrix(train.y[folds[,r]==v],)
    x.2.unscaled <- as.matrix(train.x[folds[,r]==v,]) # Original data set 2
    x.2 = rescale(x.2.unscaled, x.1.unscaled)
    
    # Start counter to add each model's misclassification to row of matrix
    qq=1
    # Start Analysis Loop for all combos of size and decay on chosen data set
    for(d in dec){
      for(s in siz){
        
        ## Restart nnet nrounds times to get best fit for each set of parameters 
        Mi.final <- 1
        #  check <- MSE.final
        for(i in 1:nrounds){
          nn <- nnet(y=y.1, x=x.1, size=s, decay=d, maxit=2000, softmax=TRUE, trace=FALSE)
          Pi <- predict(nn, newdata=x.1, type="class")
          Mi <- mean(Pi != as.factor(set1[folds[,r]!=v,6]))
          
          if(Mi < Mi.final){ 
            Mi.final <- Mi
            nn.final <- nn
          }
        }
        pred.nn = predict(nn.final, newdata=x.2, type="class")
        Mis.cv[qq,(r-1)*V+v+2] = mean(pred.nn != as.factor(train.y.class[folds[,r]==v]))
        qq = qq+1
      }
    }
  }
}
Mis.cv

(Micv = apply(X=Mis.cv[,-c(1,2)], MARGIN=1, FUN=mean))
(Micv.sd = apply(X=Mis.cv[,-c(1,2)], MARGIN=1, FUN=sd))
Micv.CIl = Micv - qt(p=.975, df=R*V-1)*Micv.sd/sqrt(R*V)
Micv.CIu = Micv + qt(p=.975, df=R*V-1)*Micv.sd/sqrt(R*V)
(all.cv = cbind(Mis.cv[,1:2],round(cbind(Micv,Micv.CIl, Micv.CIu),2)))
all.cv[order(Micv),]


# Plot results. 
siz.dec <- paste("NN",Mis.cv[,1],"-",Mis.cv[,2])
x11(pointsize=10)
boxplot(x=Mis.cv[,-c(1,2)], use.cols=FALSE, names=siz.dec,
        las=2, main="MisC Rate boxplot for various NNs")

# Plot RELATIVE results. 
lowt = apply(Mis.cv[,-c(1,2)], 2, min)

x11(pointsize=10)
# margin defaults are 5,4,4,2, bottom, left, top right
#  Need more space on bottom, so increase to 7.
par(mar=c(7,4,4,2))
boxplot(x=t(Mis.cv[,-c(1,2)])/lowt, las=2 ,names=siz.dec,
        main="Relative MisC Rate boxplot for various NNs")

relMi = t(Mis.cv[,-c(1,2)])/lowt
(RRMi = apply(X=relMi, MARGIN=2, FUN=mean))
(RRMi.sd = apply(X=relMi, MARGIN=2, FUN=sd))
RRMi.CIl = RRMi - qt(p=.975, df=R*V-1)*RRMi.sd/sqrt(R*V)
RRMi.CIu = RRMi + qt(p=.975, df=R*V-1)*RRMi.sd/sqrt(R*V)
(all.rrcv = cbind(Mis.cv[,1:2],round(cbind(RRMi,RRMi.CIl, RRMi.CIu),2)))
all.rrcv[order(RRMi),]


###########################################################
#  Fit the suggested model to full training data, 
#    with 3 nodes and .01 shrinkage
###########################################################

x.1.unscaled <- as.matrix(set1[,-6])
x.2.unscaled <- as.matrix(set2[,-6])
x.1 <- rescale(x.1.unscaled, x.1.unscaled)
x.2 <- rescale(x.2.unscaled, x.1.unscaled)

y.1 <- class.ind(set1[,6])
y.2 <- class.ind(set2[,6])

Mi.final = 1
for(i in 1:10){
  nn <- nnet(y=y.1, x=x.1, size=3, decay=0.01, maxit=2000, softmax=TRUE, trace=FALSE)
  Pi <- predict(nn, newdata=x.1, type="class")
  Mi <- mean(Pi != as.factor(set1[,6]))
  
  if(Mi < Mi.final){ 
    Mi.final <- Mi
    nn.final <- nn
  }
}

# Train error
p1.nn.3.01 <-predict(nn.final, newdata=x.1, type="class")
(misclass1.3.01 <- mean(ifelse(p1.nn.3.01 == set1$type, yes=0, no=1)))

# Test set error
p2.nn.3.01 <-predict(nn.final, newdata=x.2, type="class")
(misclass2.3.01 <- mean(ifelse(p2.nn.3.01 == set2$type, yes=0, no=1)))
table(p2.nn.3.01, as.factor(set2$type),  dnn=c("Predicted","Observed"))
