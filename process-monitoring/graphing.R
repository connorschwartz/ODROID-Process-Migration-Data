# These filenames can be changed to any csv of thread data and txt list of timestamps
threaddata <- read.csv("data/11-2019/amazon-threaddata.csv")
timestamps <- read.table("data/11-2019/amazon-times.txt", quote="\"", comment.char="")
# pid = list of all pids that were used, m = total number of timestamps, iterations = number of times a website was loaded
pid <- unique(threaddata[1])
m = nrow(threaddata)
iterations = nrow(timestamps) / 18

#######################################################################
# This first graph will show the cumulative total of clock ticks over time
options(scipen=999)
plot(1,type='n',xlim=c(threaddata[1,3],threaddata[m,3]),ylim=c(0,max(threaddata$usertime)),main="Cumulative Clock Ticks by Timestamp",xlab='Time', ylab='Clock Ticks (100 Hz)')

# Right now, processes 1, 4, 5, and 6 are graphed since these are most significant - this can be changed to look at any set of processes
legend("topleft", c("Process 1", "Process 4", "Process 5", "Process 6"), lty=c(1,1,1,1), lwd=c(2,2,2,2), col=c(5,2,3,4))
lines(threaddata$timestamp[threaddata$pid==pid[1,1]], threaddata$usertime[threaddata$pid==pid[1,1]], type='o', col=5, lwd=1)
lines(threaddata$timestamp[threaddata$pid==pid[4,1]], threaddata$usertime[threaddata$pid==pid[4,1]], type='o', col=2, lwd=1)
lines(threaddata$timestamp[threaddata$pid==pid[5,1]], threaddata$usertime[threaddata$pid==pid[5,1]], type='o', col=3, lwd=1)
lines(threaddata$timestamp[threaddata$pid==pid[6,1]], threaddata$usertime[threaddata$pid==pid[6,1]], type='o', col=4, lwd=1)

# Plot the timestamps for startTimestamp, domLoading, and domInteractive as black, gray, and brown vertical lines
for (val in 1:iterations) {
  abline(v=timestamps[val*18-17,1],col="black")
  abline(v=timestamps[val*18-6,1],col="gray")
  abline(v=timestamps[val*18-5,1],col="brown")
}

#######################################################################
# This second graph shows moving averages of clock ticks used per second by each process (clock ticks are 10 ms)
plot(1,type='n',xlim=c(threaddata[1,3],threaddata[m,3]),ylim=c(0,200),main="Rolling Average of Clock Ticks Per Second",xlab='Time', ylab='Clock Ticks Per Second')

# Right now, processes 1, 4, 5, and 6 are graphed since these are most significant - this can be changed to look at any set of processes
legend("topleft", c("Process 1", "Process 4", "Process 5", "Process 6"), lty=c(1,1,1,1), lwd=c(2,2,2,2), col=c(5,2,3,4))
c1=as.matrix(filter(threaddata$utimediff[threaddata$pid==pid[1,1]], sides=2, filter=rep(1/100,100)))
t1=as.matrix(filter(threaddata$timechange[threaddata$pid==pid[1,1]], sides=2, filter=rep(1/100,100)))
d1=as.matrix(filter(threaddata$timestamp[threaddata$pid==pid[1,1]], sides=2, filter=rep(1/100,100)))
lines(d1, 1000 * c1/t1, type='o', col=5, lwd=2)
c4=as.matrix(filter(threaddata$utimediff[threaddata$pid==pid[4,1]], sides=2, filter=rep(1/100,100)))
t4=as.matrix(filter(threaddata$timechange[threaddata$pid==pid[4,1]], sides=2, filter=rep(1/100,100)))
d4=as.matrix(filter(threaddata$timestamp[threaddata$pid==pid[4,1]], sides=2, filter=rep(1/100,100)))
lines(d4, 1000 * c4/t4, type='o', col=2, lwd=2)
c5=as.matrix(filter(threaddata$utimediff[threaddata$pid==pid[5,1]], sides=2, filter=rep(1/100,100)))
t5=as.matrix(filter(threaddata$timechange[threaddata$pid==pid[5,1]], sides=2, filter=rep(1/100,100)))
d5=as.matrix(filter(threaddata$timestamp[threaddata$pid==pid[5,1]], sides=2, filter=rep(1/100,100)))
lines(d5, 1000 * c5/t5, type='o', col=3, lwd=2)
c6=as.matrix(filter(threaddata$utimediff[threaddata$pid==pid[6,1]], sides=2, filter=rep(1/100,100)))
t6=as.matrix(filter(threaddata$timechange[threaddata$pid==pid[6,1]], sides=2, filter=rep(1/100,100)))
d6=as.matrix(filter(threaddata$timestamp[threaddata$pid==pid[6,1]], sides=2, filter=rep(1/100,100)))
lines(d6, 1000 * c6/t6, type='o', col=4, lwd=2)

# Plot the timestamps for startTimestamp, domLoading, and domInteractive as black, gray, and brown vertical lines
for (val in 1:11) {
  abline(v=timestamps[val*18-17,1],col="black")
  abline(v=timestamps[val*18-6,1],col="gray")
  abline(v=timestamps[val*18-5,1],col="brown")
}

