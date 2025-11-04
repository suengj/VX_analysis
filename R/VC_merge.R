# Suengjae HOng
# VC round data merge
rm(list=ls())

#### PACKAGE ####
if (!require('tidyverse')) install.packages('tidyverse'); library('tidyverse')
if (!require('readxl')) install.packages('readxl'); library(readxl)

# setting wd
wd <- c("/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Dataset/VentureXpert_Mar25",
        "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Dataset/VentureXpert_Mar25")


# Mar-25 new round data (downloaded all)
setwd(wd[1])

flist <- list.files(pattern='.xlsx')
dta_list <- list()

for(f_nm in flist){
  
  dta_list[[f_nm]] <- read_excel(f_nm, 
                                 sheet=1,
                                 skip=1,
                                 col_names=TRUE)
  
}


rounddta_raw <- do.call("bind_rows", dta_list)

write.csv(rounddta_raw, "round_new.csv",
          row.names=FALSE)



## previous Mar 25 ----

# read com dta & merge
setwd(wd[1])

flist <- list.files(pattern='.xlsx')
dta_list <- list()

for(f_nm in flist){
  dta_list[[f_nm]] <- read_excel(f_nm,
                                 col_names=TRUE)
  
}

comdta_raw <- do.call("bind_rows", dta_list)

colnames(comdta_raw) <- c("date_ipo","date_fnd","date_sit","comcusip",
                      "compubstat","comsitu","comipo","commsa","comname",
                      "comnation","comstacode","comstock","comticker",
                      "comind","comindmjr","comindmnr","comindsub1","comindsub2","comindsub3","comzip")

write.csv(comdta_raw,"comdta_new.csv",
          row.names=FALSE)

# read round dta & merge
setwd(wd[2])

flist <- list.files(pattern='.xlsx')
dta_list <- list()

for(f_nm in flist)(
  dta_list[[f_nm]] <- read_excel(f_nm,
                                 col_names=TRUE)
)

rounddta_raw <- do.call("bind_rows", dta_list)

colnames(rounddta_raw) <- c("rnddate","comname","dealno","firmname",
                            "fundname","RoundAmountEstimatedThou","RoundAmountDisclsedThou",
                            "RoundNumber","RoundNumInvestors","standardUSventureDisburse")

write.csv(rounddta_raw, "round_new.csv",
          row.names=FALSE)


# end of code