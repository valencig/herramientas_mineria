credit.frame <- maml.mapInputPort(1) 
drop.cols <- c('OtherInstallments',
               'ExistingCreditsAtBank')
out.frame <- credit.frame[, !(names(credit.frame) %in% drop.cols)]
maml.mapOutputPort("out.frame")