# Suengjae Hong
# 2022-11-18
# VentureXpert Dta

rm(list=ls()); gc()
# start_time <- Sys.time()

# Load package -------------
# Two packages are used: igraph & data.table for this R script
# for data preprocessing
if (!require('igraph')) install.packages('igraph'); library('igraph')
if (!require('data.table')) install.packages('data.table'); library('data.table')
if (!require('tidyverse')) install.packages('tidyverse'); library('tidyverse')
if (!require('foreign')) install.packages('foreign'); library(foreign)
if (!require('readxl')) install.packages('readxl'); library(readxl)

# for parallel running
if (!require('doParallel')) install.packages('doParallel'); library('doParallel')
if (!require('foreach')) install.packages('foreach'); library('foreach')
# if (!require('tcltk')) install.packages('tcltk'); library('tcltk')

# for saving compressed data
if (!require('fst')) install.packages('fst'); library('fst')

# for modeling
# if (!require('Zelig')) install.packages('Zelig'); library('Zelig') # relogit if use

# for visualization
#if (!require('sjPlot')) install.packages('sjPlot'); library('sjPlot')
#if (!require('sjmisc')) install.packages('sjmisc'); library('sjmisc')
#if (!require('sjlabelled')) install.packages('sjlabelled'); library('sjlabelled')

# for analysis
if (!require('plm')) install.packages('plm'); library('plm')
if (!require('pglm')) install.packages('pglm'); library('pglm')
if (!require('car')) install.packages('car'); library('car')
if (!require('Hmisc')) install.packages('Hmisc'); library('Hmisc')

# Setting -----
select <- dplyr::select

### working dir ####
wd <- c("/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Yang, Rhee, Ma/data",
        "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Yang, Rhee, Ma/results",
        "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Network Imprinting/dta",
        "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Network Imprinting/rst")

setwd(wd[1]) # Change the working directory

### multi core ####
capacity <- 0.8
cores <- round(parallel::detectCores()*capacity,digits=0)
registerDoParallel(cores=cores)

# [FUNCTIONS] --------
## FUN-1. initial network =====
VC_initial_ties <- function(edge_raw, y, time_window=NULL){
  
  if(!is.null(time_window)) {
    edge_df <- edge_raw %>% as_tibble() %>%
      filter(year >= y & year < y+time_window) %>% as.data.frame() # y ~ y+ (time window)
    
  } else {
    edge_df <- edge_raw %>% as_tibble() %>% 
      filter(year == y) %>% as.data.frame() # 1-year only
  }
  
  y_loop <- edge_df %>% as_tibble() %>% 
    select(year) %>%
    distinct()
  
  df_list <- list()
  for(i in 1:NROW(y_loop)){
    tmp <- edge_df %>% filter(year==as.numeric(y_loop[i,1]))
    
    twomode <- graph_from_data_frame(tmp)
    V(twomode)$type <- V(twomode)$name %in% tmp[,1]
    
    edge_list <- bipartite_projection(twomode)$proj2
    
    df1 <- as.data.frame(get.edgelist(edge_list))
    df1$tied_year <- as.numeric(y_loop[i,1])
    
    df2 <- df1
    colnames(df2) <- c("V2","V1","tied_year")
    
    df_list[[i]] <- rbind(df1, df2)
  }
  
  df <- do.call("rbind",df_list)

  return(df)
}

VC_initial_period <- function(df, period){
  
  df <- df %>%
    mutate(check = tied_year - initial_year) %>%
    filter(check < period) %>%
    select(-check)
  
  return(df)
}

VC_initial_focal_centrality <- function(initial_partner_list, cent){
  
  df <- left_join(initial_partner_list, cent,
                  by=c("firmname" = "firmname",
                       "tied_year" = "year"))
  
  # summarize by mean
  df_mean <- df %>%
    dplyr::select(-initial_partner) %>%
    group_by(firmname, tied_year) %>%
    summarise_at(vars(matches("dgr|btw|pwr|cons|density")),
                 funs(mean))
  
  # merge
  df_merged <- rename_with(df_mean,
                           .fn = ~paste0("f_", .),
                           .cols = matches("dgr|btw|pwr|cons|density"))
  
  return(df_merged)
  
}


VC_initial_partner_centrality <- function(initial_partner_list, cent){
  
  df <- left_join(initial_partner_list, cent,
                  by=c("initial_partner" = "firmname",
                       "tied_year" = "year"))
  
  # summarize by sum
  df_sum <- df %>%
    dplyr::select(-initial_partner) %>%
    group_by(firmname, tied_year) %>%
    summarise_at(vars(matches("dgr")),
                 funs(sum))
  
  # summarize by mean
  df_mean <- df %>%
    dplyr::select(-initial_partner) %>%
    group_by(firmname, tied_year) %>%
    summarise_at(vars(matches("btw|pwr|cons|density")),
                 funs(mean))
  
  # merge
  df_merged <- left_join(df_sum, df_mean,
                         by=c("firmname","tied_year"))
  
  df_merged <- rename_with(df_merged,
                           .fn = ~paste0("p_", .),
                           .cols = matches("dgr|btw|pwr|cons|density"))

  return(df_merged)
  
}


## FUN-2. general network =====
# VC matrix calculation
VC_matrix <- function(edge_raw, year, time_window = NULL, edge_cutpoint = NULL) {
  
  if(!is.null(time_window)) {
    edgelist <- edge_raw[edge_raw$year <= year & edge_raw$year >= year-time_window+1, 
                         c("firmname", "event")]
  } else {
    edgelist <- edge_raw[edge_raw$year == year, c("firmname", "event")]
  }
  
  twomode <- graph_from_edgelist(as.matrix(edgelist), directed = FALSE)
  
  V(twomode)$type <- V(twomode)$name %in% edgelist[,2]
  
  onemode <- bipartite_projection(twomode)$proj1 # proj1 = vc-vc relationship; proj2 == event by event relationship
  
  if(!is.null(edge_cutpoint)) {
    onemode <- delete_edges(onemode, which(E(onemode)$weight < edge_cutpoint))
  } else {}
  
  return(onemode)
}

### centrality calculation
VC_centralities <- function(edge_raw, year, time_window, edge_cutpoint) {
  
  adjmatrix <- VC_matrix(edge_raw, year, time_window, edge_cutpoint)
  
  # beta (= 1/max_egenvalues) range determination
  upsilon <- max(
    eigen(
      as_adjacency_matrix(adjmatrix)
    )$values
  )
  
  dgr     <- degree(adjmatrix)
  btw <- betweenness(adjmatrix)
  pwr_p75  <- power_centrality(adjmatrix, exponent = (1/upsilon)*0.75) # Podolny 1993
  pwr_max <- power_centrality(adjmatrix, exponent = 1/upsilon*(1 - 10^-10)) # in case of upsilon = 1
  #  power_centrality_nmax  <- power_centrality(adjmatrix, exponent = -1/upsilon)
  pwr_zero  <- power_centrality(adjmatrix, exponent = 0)
  
  cons_value <- constraint(adjmatrix) # added constraint (max = 1.125)
  
  #  year <- year-1
  
  # ego network
  egonet_list <- make_ego_graph(adjmatrix)
  
  ego_dta <- data.frame(
    firmname = names(V(adjmatrix)),
    ego_density = lapply(egonet_list, graph.density) %>% unlist()
  )
  
  # centrality merge
  cent_dta <- data.table(cbind(year,
                               dgr, 
                               btw,
                               pwr_p75,
                               pwr_max,
                               #                             power_centrality_nmax,
                               pwr_zero,
                               
                               cons_value)
                         , keep.rownames = TRUE); setnames(cent_dta, "rn","firmname")
  
  result <- merge(cent_dta, ego_dta,
                  by="firmname")
  
  return(result)
}

## FUN-3. other calculation =====
blau_index <- function(b_df){
  
  start_time <- Sys.time()

  blau <- b_df %>%
    rowwise() %>%
    mutate(sum = sum(c_across(3:ncol(b_df)))) %>% # except firmname and year
    mutate(across(3:ncol(b_df), ~.x/sum)) %>% # column wise summation
    mutate(across(3:ncol(b_df), ~.x^2)) %>% # squared
    select(-sum) %>%
    mutate(blau = 1 - sum(c_across(3:ncol(b_df)))) %>% # squared sum
    select(firmname, year, blau) %>%
    ungroup()
  
  total_inv <- b_df %>%
    rowwise() %>%
    mutate(TotalInvest = sum(c_across(3:ncol(b_df)))) %>%
    select(firmname, year, TotalInvest) %>%
    ungroup()
  
  blau <- left_join(blau, total_inv,
                    by=c("firmname","year"))
  
  end_time <- Sys.time()
  print(end_time - start_time)
  
  return(blau)
  
}


# I. DATA MANIPULATION (Lv1) ----
## 1. com data ====
### exit data (t+1 변경 필요) ####
comdta <- read.dta('companydata.dta') %>% as_tibble() %>%
  mutate(exit = ifelse(comsitu %in% c("Went Public","Merger","Acquisition") & (date_sit != "" | date_ipo != ""),1,0)) # exit data

## 2. firm level data ====
firmdta <- read.dta('firmdata.dta') %>% as_tibble() %>%
  dplyr::select(-starts_with('fund')) %>%
  mutate(fnd_year = as.integer(str_sub(date_fnd,
                                       nchar(date_fnd)-3,nchar(date_fnd))))
### corporate data ####
corporatevc <- data.table(read.csv("corporateVC.csv", header = TRUE)) %>% as_tibble()

## 3. round data (edge) ====
round <- read.csv("roundall.csv", header = TRUE)         
round <- round[round$firmname != "Undisclosed Firm", ]   
round <- round[round$comname != "Undisclosed Company", ]

# round data
#round_dta <- round
#round_dta$event1 <- factor(paste(round$comname, round$rnddate, sep="-"))
#round_dta <- round_dta %>% as_tibble() %>%
#  select(event1,RoundAmountDisclosedThou,RoundAmountEstimatedThou,
#         RoundNumber, CompanyStageLevel1, CompanyStageLevel2, CompanyStageLevel3)

# edge data
event       <- round[ ,c("year","rnddate","firmname","comname")]
event$event1 <- factor(paste(event$comname, event$rnddate, sep ="-")) # more plausible because multiple Series investments can occurs at the same year
event$event2 <- factor(paste(event$comname, event$year, sep="-"))
event       <- event[ ,c("year", "firmname","comname","event1","event2")]

### edgelist ####
edge_raw <- event[,c("firmname","event1","year")]
edge_raw <- edge_raw %>% as_tibble() %>%
  rename(event = event1) %>% 
  distinct() # unique VC-event list 
edge_raw <- as.data.frame(edge_raw)

### initial edge ####
event_count <- edge_raw %>% as_tibble() %>%
  group_by(event) %>%
  summarise(VC_num = n())

initial_edge <- left_join(edge_raw, event_count, by="event")
initial_edge <- initial_edge %>% 
  filter(VC_num >=2) %>% # select event only more than 2 VC joined
  dplyr::select(-event, -VC_num) %>%
  arrange(firmname, year) %>% 
  distinct() %>%
  group_by(firmname) %>%
  mutate(row_ = row_number()) %>%
  filter(row_ ==1) %>%
  dplyr::select(-row_) %>%
  rename(initial_year = year)

### raw level data ####
raw <- round; rm(event)

### merge raw data ####
### fund amt ####
funddta <- read.dta('firmdata.dta') %>% as_tibble() %>% 
  dplyr::select(starts_with('fund'),'firmname') %>%
  drop_na(fundsize) %>%
  filter(fundsize != 0.0) %>%
  group_by(firmname, fundyear) %>%
  summarise(amt_sum = sum(fundsize)) %>%
  rename(year=fundyear)

raw <- dplyr::left_join(raw, funddta, by=c("firmname","year")); rm(funddta)

## 4. Data Merge ====
### cvc data ####
raw <- dplyr::left_join(raw, corporatevc, by="firmname") %>%
  mutate(corpvc = replace_na(corpvc, 0)); rm(corporatevc)

### initial year ####
raw <- dplyr::left_join(raw, initial_edge, by="firmname"); # rm(initial_edge)


# II. DATA MANIPULATION (Lv2) ----
## 1. general network centrality====

## 1-year network data
ma_year <- 1
cutting <- NULL

start_time <- Sys.time()
cent_1y <- foreach(y=1970:2011,
                .combine=rbind) %dopar% VC_centralities(edge_raw,
                                                        y,
                                                        ma_year,
                                                        cutting)
cent_1y <- cent_1y %>% as_tibble()
colnames(cent_1y) <- c("firmname","year","dgr_1y","btw_1y","pwr_p75_1y","pwr_max_1y",
                      "pwr_zero_1y","cons_value_1y","ego_density_1y")
  
end_time <- Sys.time()

print(end_time - start_time)

## 3-year network data
ma_year <- 3
cutting <- NULL

start_time <- Sys.time()
cent_3y <- foreach(y=1970:2011,
                  .combine=rbind) %dopar% VC_centralities(edge_raw,
                                                          y,
                                                          ma_year,
                                                          cutting)
cent_3y <- cent_3y %>% as_tibble()
colnames(cent_3y) <- c("firmname","year","dgr_3y","btw_3y","pwr_p75_3y","pwr_max_3y",
                      "pwr_zero_3y","cons_value_3y","ego_density_3y")

end_time <- Sys.time()

print(end_time - start_time)

# the network : y ~ y-4 (5 year)
ma_year <- 5
cutting <- NULL

start_time <- Sys.time()
cent_5y <- foreach(y=1970:2011,
                .combine=rbind) %dopar% VC_centralities(edge_raw,
                                                        y,
                                                        ma_year,
                                                        cutting)
cent_5y <- cent_5y %>% as_tibble()
colnames(cent_5y) <- c("firmname","year","dgr_5y","btw_5y","pwr_p75_5y","pwr_max_5y",
                       "pwr_zero_5y","cons_value_5y","ego_density_5y")

end_time <- Sys.time()

print(end_time - start_time)

## 2. initial-level data ====
imprinting_period <- 1

### initial partner identification ####
start_time <- Sys.time()

initial_raw <- foreach(y=1970:2011,
                       .combine=rbind) %dopar% VC_initial_ties(edge_raw,y,imprinting_period)

end_time <- Sys.time()
print(end_time - start_time)

### initial partner list ####
initial_tie_list <- initial_raw %>% as_tibble() # as_tibble
colnames(initial_tie_list) <- c("firmname","initial_partner","tied_year")

### merge initial year ####
initial_tie_list <- left_join(initial_tie_list, initial_edge,
                                by = "firmname")

### initial partners list ####
initial_partner_list <- VC_initial_period(initial_tie_list, imprinting_period)

initial_partner_number <- initial_partner_list %>%
  select(firmname, initial_partner) %>%
  distinct() %>%
  group_by(firmname) %>%
  summarise(initial_partner_num = n())

### finalize initial partner's network centrality #### (1,3,5yr data를 각각 결합 필요)
initial_partner_df_1y <- VC_initial_partner_centrality(initial_partner_list, cent_1y)
initial_partner_df_3y <- VC_initial_partner_centrality(initial_partner_list, cent_3y)
initial_partner_df_5y <- VC_initial_partner_centrality(initial_partner_list, cent_5y)

initial_partner_df <- initial_partner_df_1y %>%
  left_join(initial_partner_df_3y, by=c("firmname","tied_year")) %>%
  left_join(initial_partner_df_5y, by=c("firmname","tied_year"))


rm(initial_partner_df_1y,
   initial_partner_df_3y,
   initial_partner_df_5y)

# only remaining the latest tied year
initial_partner_final <- initial_partner_df %>%
  group_by(firmname) %>%
  mutate(yes = ifelse(max(tied_year)==tied_year,1,0)) %>%
  filter(yes==1) %>% 
  dplyr::select(-yes) # initial partner firm's network attribute DONE

rm(initial_partner_df)

### finalize initial focal's network centrality #### (1,3,5yr data를 각각 결합 필요)
initial_focal_df_1y <- VC_initial_focal_centrality(initial_partner_list, cent_1y)
initial_focal_df_3y <- VC_initial_focal_centrality(initial_partner_list, cent_3y)
initial_focal_df_5y <- VC_initial_focal_centrality(initial_partner_list, cent_5y)

initial_focal_df <- initial_focal_df_1y %>%
  left_join(initial_focal_df_3y, by=c("firmname","tied_year")) %>%
  left_join(initial_focal_df_5y, by=c("firmname","tied_year"))

rm(initial_focal_df_1y,
   initial_focal_df_3y,
   initial_focal_df_5y)

# only remaining the latest tied year
initial_focal_final <- initial_focal_df %>%
  group_by(firmname) %>%
  mutate(yes = ifelse(max(tied_year)==tied_year,1,0)) %>%
  filter(yes==1) %>% 
  dplyr::select(-yes) # initial focal firm's network attribute DONE

rm(initial_focal_df)


# III. DATA MERGE ----
# creating df data (lowest level data)
df <- raw

## 1. Event Level (Firm-year-company) ====

## 2. Company-year Level ====

### a. exit data ####
com_yr_level <- comdta %>% filter(exit==1) %>%
  mutate(com_sit = ifelse(date_sit == '',date_ipo,date_sit)) %>%
  mutate(situ_yr = as.integer(str_sub(com_sit,
                                      nchar(com_sit)-3,nchar(com_sit)))) %>%
  mutate(com_analysis_yr = situ_yr +1) %>% # for dependent variable (나중에 삭제 필요)
  dplyr::select(comname, exit, com_sit, situ_yr, com_analysis_yr)

df <- left_join(df, com_yr_level,
                by=c("comname"="comname","year"="situ_yr"))

df <- df %>%
  dplyr::select(-com_sit, -com_analysis_yr) %>%
  mutate(exit = replace_na(exit,0)); rm(com_yr_level)

## 3. Company Level ====
com_level <- comdta %>% select(
  comname, date_ipo, date_fnd, date_sit, areacode, comcity, comsitu,
  comcounty, comregion, commsa, commsacode, comstate, comestacode, comzip,
  comind, comindmjr, comindmnr, comindsub1, comindsub2, comindsub3
)

df <- left_join(df, com_level,
                 by="comname"); rm(com_level) # com level merge

## 4. Firm-Year-Level ====
### a. merge f-y level dta ####
dta <- df %>%
  group_by(firmname, year) %>%
  mutate(InvestAMT = sum(RoundAmountEstimatedThou),
         NumExit = sum(exit)) %>%
  dplyr::select(firmname, year, InvestAMT, NumExit, corpvc,
                initial_year) %>%
  distinct()

### b. firm-year network ####
dta <- left_join(dta, cent_1y,
                 by=c("firmname","year")) # 1-year ma network

dta <- left_join(dta, cent_3y,
                 by=c("firmname","year")) # 3-year ma network

dta <- left_join(dta, cent_5y,
                 by=c("firmname","year")) # 5-year ma network

### b. Blau index ####
# investment behaviors data 
inv_df <- df %>%
  select(year, firmname, RoundNumber, 
         CompanyStageLevel1, CompanyStageLevel2, CompanyStageLevel3,
         comind, comindmjr, comindmnr,
         comindsub1, comindsub2, comindsub3)

# blau data
b_df <- inv_df %>%
  select(firmname, year, comindmnr) %>%
  filter(comindmnr != "" | 0) %>%
  count(firmname, year, comindmnr) %>%
  pivot_wider(names_from = comindmnr,
              values_from = n,
              values_fill = 0)

b_df <- blau_index(b_df)

dta <- left_join(dta, b_df,
                by=c("firmname","year")); rm(inv_df, b_df)

### c. early stage participation (yearly -> early %) ####
earlyStage <- raw %>%
  dplyr::select(firmname, year, CompanyStageLevel1) %>%
  mutate(earlyStageCnt = ifelse(CompanyStageLevel1 %in% c('Startup/Seed','Early Stage'),1,0)) %>%
  group_by(firmname, year) %>%
  mutate(earlyStage = mean(earlyStageCnt)) %>%
  dplyr::select(firmname, year, earlyStage) %>%
  distinct()

dta <- left_join(dta, earlyStage,
                 by=c("firmname","year")); rm(earlyStage)

## 5. Firm-Level merge ====
### A. initial network data ####
#### a. initial partner data ####
initial_partner_tmp <- initial_partner_final %>%
  dplyr::select(-tied_year)

dta <- left_join(dta, initial_partner_tmp,
                 by="firmname"); rm(initial_partner_tmp)

#### a-2. number of initial partner ####
dta <- left_join(dta, initial_partner_number,
                 by="firmname")

#### b. initial focal firm data ####
initial_focal_tmp <- initial_focal_final

dta <- left_join(dta, initial_focal_tmp,
                 by="firmname"); rm(initial_focal_tmp)

# rename tied year due to confusion
dta <- dta %>%
  rename(last_initial_tied = tied_year)

# [[[ TBU ]]] knowledge deviance from initial partners
# [[[ TBU ]]] focal-firm data distance

#### c. firm demographic ####
firmDemo <- firmdta %>% 
  select(firmname, firmstatecode, fnd_year) %>%
  distinct()

dta <- left_join(dta, firmDemo,
                 by="firmname"); rm(firmDemo)

dta <- dta %>%
  group_by(firmname, year) %>%
  mutate(firmAge = year - fnd_year)

dta <- dta %>%
  mutate(CAMA = ifelse(firmstatecode %in% c("MA","CA"),1,0))

## 6. year-level merge ====
# NASDAQ stock vol
setwd(wd[3])
nasdaq_dta <- read_excel('nasdaq.xlsx',
                     col_names=TRUE)

AnnVol <- nasdaq_dta %>%
  group_by(year) %>%
  summarise(AnnVol = sd(dailyReturn, na.rm=TRUE)*(252^(1/2))) %>%
  select(year, AnnVol)

dta <- left_join(dta, AnnVol,
                 by="year"); rm(AnnVol)
  

## 7. save dta ====
setwd(wd[3])
write_fst(dta,
          path=paste0('dta_',imprinting_period,'yrPeriod.fst'),
          compress=100)

#all_equal(dta,tmp) # comparing two data

# saving R type file 
save(dta,
     file='imprinting.RData',
     compress='bzip2')


### END OF CODE #####































# x x x x x x x x x x x x ####
# < GARBAGE > ####
# DEFINED FUNCTIONS --------

### [[[[ IMPORTANT ]]]] - updating ####
VC_initial_centrality <- function(edge_raw, initial_partner_df, time_window=NULL, edge_cutpoint=NULL){
  initial_year_df <- initial_partner_df %>% as_tibble() %>%
    dplyr::select(firmname, initial_year) %>%
    distinct()
  
  edge_raw_initial <- left_join(edge_raw, initial_year_df, by="firmname")
  
  
}

#### updatae 필요
# initial network for the focal firm only (3-year)
start_time <- Sys.time()
init_cent <- foreach(y=1970:2011,
                     .combine=rbind) %dopar% VC_centralities(edge_raw,y,3,5)
init_cent <- init_cent %>% as_tibble()

end_time <- Sys.time()

print(end_time - start_time)

# end of code

## FUN-1. initial network =====

time_window <- 5
edge_cutpoint <- 5

tmp <- VC_centralities(edge_raw, 1990, time_window, edge_cutpoint)




for(y in 1960:2010){
  VC_initial_ties(edge_raw,y,3)
  
  ttime <- Sys.time()
  print(paste("Finish Time for ", y, ": ", ttime))
  
}

VC_initial_ties <- function(edge_raw, y, time_window=NULL){
  
  if(!is.null(time_window)) {
    edge_df <- edge_raw %>% as_tibble() %>%
      filter(year >= y & year < y+time_window) %>% as.data.frame() # y ~ y+ (time window)
    
  } else {
    edge_df <- edge_raw %>% as_tibble() %>% 
      filter(year == y) %>% as.data.frame() # 1-year only
  }
  
  y_loop <- edge_df %>% as_tibble() %>% 
    select(year) %>%
    distinct()
  
  df_list <- list()
  for(i in 1:NROW(y_loop)){
    tmp <- edge_df %>% filter(year==as.numeric(y_loop[i,1]))
    
    twomode <- graph_from_data_frame(tmp)
    V(twomode)$type <- V(twomode)$name %in% tmp[,1]
    
    edge_list <- bipartite_projection(twomode)$proj2
    
    df1 <- as.data.frame(get.edgelist(edge_list))
    df1$start_imprint_yr <- as.numeric(y_loop[i,1])
    
    if(!is.null(time_window)){
      df1$end_imprint_yr <- as.numeric(y_loop[i,1] + time_window-1)
    } else {
      df1$end_iimprint_yr <- as.numeric(y_loop[i,1])
    }
    
    df2 <- df1
    colnames(df2) <- c("V2","V1","start_imprint_yr","end_imprint_yr")
    
    df_list[[i]] <- rbind(df1, df2)
  }
  
  df <- do.call("rbind",df_list)
  
  return(df)
}



# replace
df <- raw %>% 
  select(-com_sit, -situ_yr) %>%
  replace(is.na(.),0)

## SHNN INDEX (FUNCTION)


# p-dataframe
pdta <- pdata.frame(pdta, index=c("firmname","timesince"))
pdta <- pdta %>% 
  drop_na(initial_year)




# com level 
com_yr_level <- comdta %>% filter(exit==1) %>%
  mutate(com_sit = ifelse(date_sit == '',date_ipo,date_sit)) %>%
  mutate(situ_yr = as.integer(str_sub(com_sit,
                                      nchar(com_sit)-3,nchar(com_sit)))) %>%
  mutate(com_analysis_yr = situ_yr +1) %>% # for dependent variable (나중에 삭제 필요)
  dplyr::select(comname, exit, com_sit, situ_yr, com_analysis_yr)



initial_partner_df <- left_join(initial_partner_list, cent,
                                by=c("initial_partner"="firmname","tied_year"="year"))

colnames(initial_partner_df) <- c("firmname","initial_partner","tied_year","initial_year",
                                  "p_dgr_1y","p_btw_1y","p_pwr_p75_1y","p_pwr_max_1y","p_pwr_zero_1y",
                                  "p_cons_value_1y","p_ego_density_1y")

initial_partner_df <- initial_partner_df %>%
  group_by(firmname, tied_year) %>%
  summarise(initial_year = mean(initial_year),
            p_dgr_1y = sum(p_dgr_1y),
            p_btw_1y = mean(p_btw_1y),
            p_pwr_p75_1y = mean(p_pwr_p75_1y),
            p_pwr_max_1y = mean(p_pwr_max_1y),
            p_pwr_zero_1y = mean(p_pwr_zero_1y),
            p_cons_value_1y = mean(p_cons_value_1y),
            p_ego_density_1y = mean(p_ego_density_1y))




cent <- cent_3y # initial periods

initial_focal_df <- left_join(initial_partner_list, cent,
                              by=c("firmname"="firmname","tied_year"="year"))

initial_focal_df <- initial_focal_df %>%
  select(-initial_partner) %>%
  group_by(firmname, tied_year) %>%
  distinct()

colnames(initial_focal_df) <- c("firmname","tied_year","initial_year","f_dgr","f_btw",
                                "f_pwr_p75","f_pwr_max","f_pwr_zero",
                                "f_cons_value","f_ego_density")








# H0
model0 <- pglm(NumExit ~ 
                 timesince + 
                 lag(NumExit) + lag(blau) + lag(log(InvestAMT)) + lag(earlyStage) + # other (t)
                 CAMA + factor(initial_year) + # factor
                 lag(log(dgr_1y+1)) + lag(pwr_max_5y) + lag(cons_value_1y) + # network (t)
                 
                 log(initial_partner_num+1) + f_pwr_max_5y + f_btw_1y +# initial focal level
                 log(p_dgr_1y +1) + log(p_btw_1y+1), # initial partner level
               
               data=pdta,
               index=c("firmname","year"),
               family=negbin,
               model='random')

summary(model0)
# car::vif(model)

# H1
model1 <- pglm(NumExit ~ 
                 timesince + 
                 lag(NumExit) + lag(blau) + lag(log(InvestAMT)) + lag(earlyStage) + # other (t)
                 CAMA + factor(initial_year) + # factor
                 lag(log(dgr_1y+1)) + lag(pwr_max_5y) + lag(cons_value_1y) + # network (t)
                 
                 log(initial_partner_num+1) + f_pwr_max_5y + f_btw_1y +# initial focal level
                 log(p_dgr_1y+1) + log(p_btw_1y+1) + # initial partner level
                 p_pwr_max_5y, # hypothesis
               
               data=pdta,
               index=c("firmname","year"),
               family=negbin,
               model='random')

summary(model1)


# H2
model2 <- pglm(NumExit ~ 
                 timesince + 
                 lag(NumExit) + lag(blau) + lag(log(InvestAMT)) + lag(earlyStage) + # other (t)
                 CAMA + factor(initial_year) + # factor
                 lag(log(dgr_1y+1)) + lag(pwr_max_5y) + lag(cons_value_1y) + # network (t)
                 
                 log(initial_partner_num+1) + f_pwr_max_5y + f_btw_1y + # initial focal level
                 log(p_dgr_1y +1) + log(p_btw_1y+1) + # initial partner level
                 p_pwr_max_5y*f_cons_value_1y, # hypothesis
               
               data=pdta,
               index=c("firmname","year"),
               family=negbin,
               model='random')

summary(model2)
# car::vif(model)

