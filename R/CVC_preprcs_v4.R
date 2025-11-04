# Suengjae Hong
# 2023-03-25
# VentureXpert Dta with new dataset
# v2: n-1 network updates | one-year matrix in tie formation
# v3: resampling available (1:1, 1:5, 1:10, 1:15)
# v4: round data updated: collected all with the same structure (Mar-25 2023)

## SHOULD UPDATE ##
## Lead VC condition - round actor # - data driven ##

rm(list=ls())

#### PACKAGE ####

# Two packages are used: igraph & data.table for this R script
# for data preprocessing
if (!require('igraph')) install.packages('igraph'); library('igraph')
if (!require('data.table')) install.packages('data.table'); library('data.table')
if (!require('tidyverse')) install.packages('tidyverse'); library('tidyverse')
if (!require('foreign')) install.packages('foreign'); library('foreign')
if (!require('lubridate')) install.packages('lubridate'); library('lubridate')
if (!require('reshape2')) install.packages('reshape2'); library('reshape2')
if (!require('zipcodeR')) install.packages('zipcodeR'); library('zipcodeR')
if (!require('progress')) install.packages('progress'); library('progress')
if (!require('readxl')) install.packages('readxl'); library(readxl)
if (!require('stringr')) install.packages('stringr'); library(stringr)
# if (!require('ggmap')) install.packages('ggmap'); library(ggmap)

# for parallel running
if (!require('doParallel')) install.packages('doParallel'); library('doParallel')
if (!require('foreach')) install.packages('foreach'); library('foreach')
# if (!require('tcltk')) install.packages('tcltk'); library('tcltk')

# for saving compressed data
if (!require('fst')) install.packages('fst'); library('fst')

# for modeling
# if (!require('Zelig')) install.packages('Zelig'); library('Zelig') # relogit if use
# if (!require('Epi')) install.packages('Epi'); library('Epi') # relogit if use
if (!require('lme4')) install.packages('lme4'); library('lme4') # relogit if use
if (!require('far')) install.packages('far'); library('far') # orthogonalization
if (!require('survival')) install.packages('survival'); library('survival') # orthogonalization
if (!require('jtools')) install.packages('jtools'); library('jtools') # visualization $ summ only for glm class
if (!require('support.CEs')) install.packages('support.CEs'); library('support.CEs') # gofm
if (!require('olsrr')) install.packages('olsrr'); library('olsrr') # condition index / vif


# for visualization
#if (!require('sjPlot')) install.packages('sjPlot'); library('sjPlot')
#if (!require('sjmisc')) install.packages('sjmisc'); library('sjmisc')
#if (!require('sjlabelled')) install.packages('sjlabelled'); library('sjlabelled')

# setting wd
wd <- c("/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Yang, Rhee, Ma/data",
        "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Yang, Rhee, Ma/results",
        "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Yang, Rhee, Ma/report",
        "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Yang, Rhee, Ma/data/new",
        "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Yang, Rhee, Ma/data/Mar25")


setwd(wd[1]) # Change the working directory

#### ~~~~~~~~~ #####
# Setting Zone -----
# function setting
select <- dplyr::select

# core setting
capacity <- 0.8
cores <- round(parallel::detectCores()*capacity,digits=0) # 6-core in 8-cores
registerDoParallel(cores=cores)

# analysis setting
time_window <- 5
edge_cutpoint <- 5 # Just in case, but not applied in this study
round_changed <- 1 # 1: YES / 2: NO

# for file name
sample_ratio <- 10
todayDate <- format(Sys.Date(),"%y%b%d")
loadDate <- c("23Mar25")

#### ~~~~~~~~~ #####

#### Defining function ####

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# II. 1. Function 1: generate the igraph of VC to VC
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# matrix value should be t-1, (because, dv = t)
VC_matrix <- function(round, year, time_window = NULL, edge_cutpoint = NULL) {
  
  if(!is.null(time_window)) {
    edgelist <- round[round$year <= year-1 & round$year >= year-time_window, # t-5 ~ t-1
                      c("firmname", "event")]
  } else {
    edgelist <- round[round$year == year-1, c("firmname", "event")] # t-1
  }
  
  twomode <- graph_from_edgelist(as.matrix(edgelist), directed = FALSE)
  
  V(twomode)$type <- V(twomode)$name %in% edgelist[,2]
  
  onemode <- bipartite_projection(twomode)$proj1
  
  if(!is.null(edge_cutpoint)) {
  } else {}
  
  return(onemode)
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# II. 2. Function 2: generate the edgelist of realized VC-to-VC ties 
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# realized tie = dv

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# II. 5. Function 5: Centrality calculations: degree, betweeness, 
#                    & 3 power cent with different beta 
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

VC_centralities <- function(round, year, time_window, edge_cutpoint) {
  
  adjmatrix <- VC_matrix(round, year, time_window, edge_cutpoint)
  
  # beta (= 1/max_egenvalues) range determination
  upsilon <- max(
    eigen(
      as_adjacency_matrix(adjmatrix)
    )$values
  )
  
  dgr_cent     <- degree(adjmatrix)
  btw_cent <- betweenness(adjmatrix)
  pwr_p75  <- power_centrality(adjmatrix, exponent = (1/upsilon)*0.75) # Podolny 1993
  pwr_max <- power_centrality(adjmatrix, exponent = 1/upsilon*(1 - 10^-10)) # in case of upsilon = 1
  pwr_zero  <- power_centrality(adjmatrix, exponent = 0)
  
  constraint_value <- constraint(adjmatrix) # added constraint
  
  result <- data.table(cbind(dgr_cent, 
                             btw_cent,
                             pwr_p75,
                             pwr_max,
                             pwr_zero,
                             
                             constraint_value)
                       , keep.rownames = TRUE)
  
  return(result)
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# III. Sampling: two options (1: 1:n / 2: CEM)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
VC_sampling_opt1 <- function(v_dta, v_coVC_unique, ratio){
  
  # actual investment history (LeadVC - PartnerVC - company)
  v_dta <- v_dta %>% unique() # remove any duplicated investment by the same VC in a given period
  
  # make all potential partner list to a given event
  df_all_ties <- data.frame(coVC = v_coVC_unique$coVC, 
                            leadVC = v_dta$leadVC[1], # the list have only one value = leadVC
                            comname = v_dta$comname[1]) %>% # the list have only one value = comname
    as_tibble()
  
  df_all_ties <- left_join(df_all_ties, 
                           v_dta %>% select(coVC, realized),
                           by="coVC") # include realized column
  
  df_all_ties <- df_all_ties %>%
    mutate(realized = replace_na(realized,0)) %>%
    filter(coVC != leadVC) # remove coVC==leadVC case
  
  # realized ties
  df_realized_ties <- df_all_ties %>%
    filter(realized==1)
  
  # potential coVC list in a give period
  df_unrealized_ties <- df_all_ties %>%
    filter(realized==0)
  
  # sampling
  set.seed(123)
  if(ratio*NROW(df_realized_ties) >= NROW(df_unrealized_ties)){
    
    df_unrealized_ties <- df_unrealized_ties %>% 
      sample_n(ratio*NROW(df_realized_ties),
               replace = TRUE) # sampling duplicated
    
  } else {
    
    df_unrealized_ties <- df_unrealized_ties %>%
      sample_n(ratio*NROW(df_realized_ties))
  }
  
  cc_dta <- bind_rows(df_realized_ties, df_unrealized_ties)
  
  return(cc_dta)
}


VC_sampling_opt1_output <- function(v_dta, v_leadVCdta, column_nm, ratio, i){
  
  start_time <- Sys.time()
  
  # identify all realived event in a given period
  realized_event <- v_dta %>%
    filter({{column_nm}} == i) %>%
    select(firmname, comname, {{column_nm}}) 
  
  # identify LeadVC in the given period by using LeadVC data
  realized_event <- left_join(realized_event, v_leadVCdta,
                              by=c("firmname", "comname"))
  
  realized_event <- realized_event %>%
    mutate(leadVC = replace_na(leadVC,0)) 
  
  # split samples
  LeadVC <- realized_event %>%
    filter(leadVC==1)
  NonLeadVC <- realized_event %>%
    filter(leadVC==0)
  
  # all realized ties
  # LeadVC column x NonLeadVC column combination
  realized_ties <- full_join(LeadVC %>% select(firmname, comname), 
                             NonLeadVC %>% select(firmname, comname), by="comname") %>%
    drop_na() %>%
    rename(leadVC = firmname.x,
           coVC = firmname.y) %>%
    select(leadVC, comname, coVC) %>%
    mutate(realized=1)
  
  # identify coVC unique list
  coVC_unique <- NonLeadVC %>% select(firmname) %>% unique() %>% 
    rename(coVC = firmname) %>% as.list()
  
  # loop 
  # 1:10 sampling function (the below function is used due to ram issue if using VC-wise calculation
  # currently, the data is 1:1 identified with LeadVC and startup company
  
  cc_list <- list()
  pb <- progress_bar$new(total=NROW(realized_ties %>% select(leadVC, comname) %>% unique()))
  
  for(j in realized_ties %>% select(comname) %>% unique() %>% pull()){
    pb$tick()
    v_dta <- realized_ties %>% filter(comname == j)
    cc_list[[j]] <- VC_sampling_opt1(v_dta, coVC_unique, ratio)
  }
  
  cc_dta <- do.call("rbind", cc_list)
  
  end_time <- Sys.time()
  
  print(end_time - start_time)
  
  return(cc_dta)
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# IV. Data Manipulation functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
date_unique_identifier <- function(data, column_nm){
  unique_list <- data %>% select(all_of(column_nm))
  unique_list <- unique_list %>%
    unique() %>%
    arrange(.[[1]]) %>% # ascending order
    pull(1) # set as vector
  
  #  rownames(unique_list) <- NULL # reset row index
  
  return(unique_list)
}

leadVC_identifier <- function(data){
  
  set.seed(123) # for random sampling below
  
  LeadVCdta <- data %>% 
    add_count(comname) %>% # count total number of invested in company
    rename(comInvested = n) %>%
    mutate(RoundNumber = replace_na(RoundNumber, 9999)) %>%
    
    group_by(comname) %>%
    mutate(FirstRound = +(RoundNumber == min(RoundNumber))) %>% # identify the earliest round 
    ungroup() %>%
    
    # count firm-company level  
    add_count(firmname, comname) %>%
    rename(firm_comInvested = n) %>%
    mutate(firm_inv_ratio = firm_comInvested / comInvested) %>%
    
    # Round volume
    mutate(RoundAmountDisclosedThou = replace_na(RoundAmountDisclosedThou, 0),
           RoundAmountEstimatedThou = replace_na(RoundAmountEstimatedThou, 0),
           RoundAmount = ifelse(RoundAmountDisclosedThou >= RoundAmountEstimatedThou, # I picked the larger amount
                                RoundAmountDisclosedThou,
                                RoundAmountEstimatedThou)) %>%
    
    group_by(firmname, comname) %>%
    mutate(TotalAmountPerCompany = sum(RoundAmount)) %>%
    
    # summarize
    select(year, firmname, comname, comInvested, FirstRound, firm_inv_ratio, RoundAmount, TotalAmountPerCompany) %>%
    
    # select lead VC
    group_by(comname) %>%
    mutate(leadVC1 = +(FirstRound ==1), # dummy
           leadVC2 = +(firm_inv_ratio == max(firm_inv_ratio)),
           leadVC3 = +(TotalAmountPerCompany == max(TotalAmountPerCompany))) %>%
    
    mutate(leadVCsum = leadVC1 + leadVC2 + leadVC3) %>%
    
    mutate(leadVC1_multi = sum(leadVC1),
           leadVC2_multi = sum(leadVC2),
           leadVC3_multi = sum(leadVC3)) %>% 
    
    mutate(leadVC = ifelse(leadVC1 ==1 & leadVC1_multi ==1,1,
                           ifelse(leadVC1 == 1 & leadVC2==1 & leadVC2_multi ==1,1,
                                  ifelse(leadVC1==1 & leadVC2==1 & leadVC3==1, 1,
                                         +(leadVC1 == 1 & max(leadVCsum) == leadVCsum))))) %>% 
    
    ungroup() %>%
    
    # finalize
    select(firmname, comname, leadVC) %>% 
    filter(leadVC==1) %>%
    unique() %>%
    
    # randomly selecting if more than two leadVC exists
    group_by(comname) %>%
    slice_sample(n=1)
  
  return(LeadVCdta)
}

# tidyverse lang
# ref: https://www.tidyverse.org/blog/2019/06/rlang-0-4-0/

# r_df = round, c_df = company (brief) year = year, yr_cut = 5 cutting
# calculate invested industry proportion & Blau index
ind_prop_fn <- function(r_df, c_df, v_yr, yr_cut=5){
  
  tmp <- r_df %>% 
    filter(year >= v_yr-yr_cut & year < v_yr) %>%
    mutate(newyr = v_yr) %>%
    select(firmname, newyr, comname)
  
  tmp <- left_join(tmp, c_df, by="comname")
  
  tmp <- tmp %>% filter(comindmnr != ""|0) %>%
    count(firmname, comindmnr) %>%
    pivot_wider(names_from = comindmnr,
                values_from = n,
                values_fill = 0)
  
  totalInv <- tmp %>%
    rowwise() %>%
    mutate(totalInv = sum(c_across(2:ncol(tmp)))) %>%
    mutate(across(2:ncol(tmp),~.x/totalInv)) %>% 
    ungroup()
  
  blau <- totalInv %>%
    rowwise() %>%
    mutate(across(2:ncol(totalInv),~.x^2)) %>%
    select(-totalInv) %>%
    mutate(blau = 1 - sum(c_across(2:ncol(tmp)))) %>%
    select(firmname, blau)
  
  rst_df <- left_join(totalInv, blau,
                      by="firmname")
  
  rst_df <- rst_df %>%
    mutate(year = v_yr)
  
  return(rst_df)
}

ind_dist_company <- function(r_df, c_df, v_yr, yr_cut=5, v_opt=1){
  
  tmp <- r_df %>% 
    filter(year >= v_yr-yr_cut & year < v_yr) %>%
    select(firmname, comname)
  
  tmp <- left_join(tmp, c_df, by="comname")
  
  tmp <- tmp %>% 
    mutate(ind_code = ind_code_col) %>%
    count(firmname, ind_code)
  
  if(v_opt==1){
    
    tmp <- tmp %>% 
      pivot_wider(names_from = ind_code,
                  values_from = n,
                  values_fill = 0)
    
    totalInv <- tmp %>%
      rowwise() %>%
      mutate(totalInv = sum(c_across(2:ncol(tmp)))) %>%
      ungroup()
    
    totalInv <- totalInv %>%
      mutate(year = v_yr)
    
    return(totalInv)
    
  } else {
    
    tmp <- tmp %>% 
      mutate(n = ifelse(n > 0, 1,0)) %>% # dummy
      pivot_wider(names_from = ind_code,
                  values_from = n,
                  values_fill = 0)
    
    tmp <- tmp %>%
      mutate(year = v_yr)
    
    return(tmp)
  }
}

VC_fund_count <- function(fd_df, v_yr, yr_cut=5){
  
  tmp <- fd_df %>% 
    filter(fundyear >= v_yr-yr_cut & fundyear < v_yr) %>%
    mutate(newyr = v_yr) %>%
    select(firmname, newyr, fundname) %>%
    
    group_by(firmname) %>%
    mutate(fund_count = n()) %>%
    select(firmname, newyr, fund_count) %>%
    
    unique()
  
}

netDist_count <- function(v_df, yr, time_window, edge_cutpoint){
  
  adjmatrix <- VC_matrix(v_df, yr, time_window, edge_cutpoint)
  geoDF <- distances(adjmatrix) # return as matrix
  
  # as data frame and replace Inf to 0 (isoloated)
  geoDF <- as.data.frame.table(geoDF) %>% as_tibble() %>%
    mutate(year = yr) %>%
    rename(VC1=Var1,
           VC2=Var2,
           geoDist = Freq) %>%
    filter(VC1 != VC2) %>%
    mutate_at(vars(geoDist), function(x) ifelse(is.infinite(x),9999,x)) %>% # but Inf = 0 is non-sense
    mutate(geoDist1 = ifelse(geoDist==1,1,0),
           geoDist2 = ifelse(geoDist==2,1,0),
           geoDist3 = ifelse(geoDist>2,1,0))
  
  return(geoDF)
}

avg_inv_amt <- function(r_df, v_yr, yr_cut){
  
  tmp <- r_df %>% 
    filter(year >= v_yr-yr_cut & year < v_yr) %>%
    mutate(newyr = v_yr) %>%
    select(firmname, newyr, comname, 
           RoundAmountDisclosedThou,
           RoundAmountEstimatedThou) %>% 
    
    # Round Amount select
    mutate(RoundAmountDisclosedThou = replace_na(RoundAmountDisclosedThou, 0),
           RoundAmountEstimatedThou = replace_na(RoundAmountEstimatedThou, 0),
           RoundAmount = ifelse(RoundAmountDisclosedThou >= RoundAmountEstimatedThou, # I picked the larger amount
                                RoundAmountDisclosedThou,
                                RoundAmountEstimatedThou)) %>%
    
    group_by(firmname) %>%
    mutate(AmtInvested = sum(RoundAmount)) %>%
    
    # finalize
    select(firmname, newyr, AmtInvested)
  
  return(tmp)
}

VC_exit_num <- function(r_df, c_df, v_yr, yr_cut=5){
  
  tmp <- r_df %>% 
    filter(year >= v_yr-yr_cut & year < v_yr) %>%
    mutate(newyr = v_yr) %>%
    select(firmname, year, newyr, comname)
  
  tmp <- left_join(tmp, c_df,
                   by=c("comname"="comname",
                        "year"="situ_yr"))
  
  tmp <- tmp %>% 
    mutate(across(starts_with("exit"), ~replace_na(.x,0))) %>%
    group_by(firmname) %>%
    mutate(exitNum = sum(exit)) %>% 
    select(firmname, newyr, exitNum) %>% 
    unique()
  
  return(tmp)
}

VC_IPO_num <- function(r_df, c_df, v_yr, yr_cut=5){
  
  tmp <- r_df %>% 
    filter(year >= v_yr-yr_cut & year < v_yr) %>%
    mutate(newyr = v_yr) %>%
    select(firmname, year, newyr, comname)
  
  tmp <- left_join(tmp, c_df,
                   by=c("comname"="comname",
                        "year"="situ_yr"))
  
  tmp <- tmp %>% 
    mutate(across(starts_with("exit"), ~replace_na(.x,0))) %>%
    group_by(firmname) %>%
    mutate(ipoNum = sum(exit)) %>% 
    select(firmname, newyr, ipoNum) %>% 
    unique()
  
  return(tmp)
}


VC_MnA_num <- function(r_df, c_df, v_yr, yr_cut=5){
  
  tmp <- r_df %>% 
    filter(year >= v_yr-yr_cut & year < v_yr) %>%
    mutate(newyr = v_yr) %>%
    select(firmname, year, newyr, comname)
  
  tmp <- left_join(tmp, c_df,
                   by=c("comname"="comname",
                        "year"="situ_yr"))
  
  tmp <- tmp %>% 
    mutate(across(starts_with("exit"), ~replace_na(.x,0))) %>%
    group_by(firmname) %>%
    mutate(MnANum = sum(exit)) %>% 
    select(firmname, newyr, MnANum) %>% 
    unique()
  
  return(tmp)
}

# statistical test
welch_t_test <- function(dta, col_nm1, col_nm2_txt){
  x <- dta %>% filter({{col_nm1}}==1) %>% dplyr::select(all_of(col_nm2_txt)) # case group
  y <- dta %>% filter({{col_nm1}}==0) %>% dplyr::select(all_of(col_nm2_txt)) # control group
  
  ttest <- t.test(x,y)
  
  mean.dif <- ttest$estimate[1] - ttest$estimate[2]
  p.value <- ttest$p.value
  
  rst <- cbind(mean.dif, p.value)
  colnames(rst) <- c("mean.dif", "p.value"); row.names(rst) <- c(col_nm2_txt)
  
  return(rst)
}

#### RAW DATA LOAD ----

# 0-1. load company/firm data ====
setwd(wd[4])
comdta <- read.csv('comdta_new.csv') %>% as_tibble() %>%
  mutate(exit = ifelse(comsitu %in% c("Went Public","Merger","Acquisition") & (date_sit != "" | date_ipo != ""),1,0)) %>% # exit data
  mutate(ipoExit = ifelse(comsitu %in% c("Went Public") & (date_sit != "" | date_ipo !=""),1,0)) %>% # IPO only 
  mutate(MnAExit = ifelse(comsitu %in% c("Merger","Acquisition") & date_sit !="",1,0)) # M&A only

comdta <- comdta %>%
  mutate(comzip2 = ifelse(comzip < 1000, 
                          paste0("00",as.character(comzip)),
                          ifelse(comzip >=1000 & comzip < 10000,
                                 paste0("0",as.character(comzip)),
                                 as.character(comzip)))) %>%
  select(-comzip) %>%
  rename(comzip = comzip2) %>%
  unique()

# remove any duplicates
comdta <- comdta %>%
  group_by(comname) %>%
  add_count(comname) %>%
  ungroup()

comdta <- comdta %>%
  filter(n<2) %>% # remove any duplicated company that has same name but different one another
  select(-n)

# industry code
comdta <- comdta %>% 
  mutate(ind_code_col = case_when(
    
    comindmnr %in% "Internet Specific" ~ "ind1",
    comindmnr %in% "Medical/Health" ~ "ind2",
    comindmnr %in% "Consumer Related" ~ "ind3",
    comindmnr %in% "Semiconductors/Other Elect." ~ "ind4",
    comindmnr %in% "Communications and Media" ~ "ind5",
    comindmnr %in% "Industrial/Energy" ~ "ind6",
    comindmnr %in% "Computer Software and Services" ~ "ind7",
    comindmnr %in% "Computer Hardware" ~ "ind8",
    comindmnr %in% "Biotechnology" ~ "ind9",
    comindmnr %in% "Other Products" ~ "ind10"
    
  ))

# fund dta
funddta <- read_excel('fund_all.xlsx') %>% as_tibble() %>% unique()

# including age & recode firmtype2 & 3
firmdta <- read_excel('firmdta_all.xlsx') %>% as_tibble() %>%
  mutate(fnd_year = year(firmfounding)) %>%
  mutate(firmtype2 = case_when(firmtype %in% c("Angel Group","Individuals") ~ "Angel",
                               firmtype %in% c("Corporate PE/Venture")~ "CVC",
                               firmtype %in% c("Investment Management Firm", "Bank Affiliated",
                                               "Private Equity Advisor or Fund of Funds",
                                               "SBIC","Endowment, Foundation or Pension Fund",
                                               "Insurance Firm Affiliate") ~ "Financial",
                               firmtype %in% c("Private Equity Firm")~"IVC",
                               firmtype %in% c("Incubator/Development Program",
                                               "Government Affiliated Program",
                                               "University Program")~"Non-Financial",
                               firmtype %in% c("Service Provider","Other","Non-Private Equity")~"Other")) %>%
  mutate(firmtype3 = ifelse(firmtype2 %in% c("IVC"),"IVC","non-IVC")) %>%
  mutate(firmfounding2 = paste0(year(firmfounding),".",
                                month(firmfounding),".",
                                day(firmfounding)))

# remove duplicated VC
setwd(wd[1])
firmcheck <- read.csv('firm_check.csv') %>%
  select(firmname, firmfounding, remove) %>% 
  unique()

firmdta <- left_join(firmdta, firmcheck, 
                     by=c("firmname"="firmname",
                          "firmfounding2"="firmfounding"))

# remove duplicated VC firm / undisclosed VC firm
firmdta <- firmdta %>%
  filter(remove != "x")

# 0-2. load round dataframe generated by read.csv() function {base} ====
setwd(wd[5]) # read Mar 25 version data

round <- read.csv("round_Mar25.csv", header = TRUE)         
round <- round[round$firmname != "Undisclosed Firm", ]   
round <- round[round$comname != "Undisclosed Company", ] 

# set year / quarter
round <- round %>%
  mutate(rnddate = as.Date(rnddate, origin="1899-12-30")) %>%
  
  mutate(year = year(rnddate),
         month = month(rnddate),
         day = day(rnddate)) %>%
  
  mutate_at(c('month','day','year'), as.numeric) %>%
  mutate(quarter = ifelse(month<4, paste0(as.character(year),"1Q"),
                          ifelse(month<8 & month>=4, paste0(as.character(year),"2Q"),
                                 ifelse(month<10 & month>=8, paste0(as.character(year),"3Q"), 
                                        paste0(as.character(year),"4Q")))))
setwd(wd[1])

# set year (filtering round)
round <- round %>% filter(year > 1979) %>% unique()

## 0-2-1. firm filtering (type, age) ====
# exclude all non-US case (VC, company)
ini_round <- NROW(round)

round <- left_join(round,
                   firmdta %>% select(firmname, firmnation) %>% unique(),
                   by="firmname")

round <- left_join(round,
                   comdta %>% select(comname, comnation) %>% unique(),
                   by="comname")

round <- round %>%
  filter_at(vars(firmnation, comnation), all_vars(!is.na(.)))

fin_round <- NROW(round)

print(1 - fin_round / ini_round) # 20.4% cases are deleted as not US case

# exclude Angel and Individual group
round <- left_join(round,
                   firmdta %>% select(firmname, firmtype2) %>% unique(),
                   by="firmname")

round <- round %>%
  filter(!firmtype2 %in% c("Angel"))

# exclude firm if age is lower than 0
round <- left_join(round, 
                   firmdta %>% select(firmname, firmfounding) %>% unique(),
                   by="firmname")

round <- round %>%
  mutate(firmage = year - year(firmfounding)) %>%
  filter(firmage >=0)

print(NROW(round))

# exclude firm & company w/o zip code
# VC firm
round <- left_join(round,
                   firmdta %>% select(firmname, firmzip) %>% unique(),
                   by="firmname")

round <- left_join(round,
                   zipcodeR::zip_code_db %>% select(zipcode, lat, lng),
                   by=c("firmzip"="zipcode"))

round <- round %>% filter(!is.na(lat)&!is.na(lng)) %>% # filter out if any errors in zip code in VC
  select(-lat, -lng, -firmzip)

print(NROW(round))

# company
round <- left_join(round,
                   comdta %>% select(comname, comzip) %>% unique(),
                   by="comname")

round <- left_join(round,
                   zipcodeR::zip_code_db %>% select(zipcode, lat, lng),
                   by=c("comzip"="zipcode"))

round <- round %>% filter(!is.na(lat)&!is.na(lng)) %>% # filter out if any errors in zip code in company
  select(-lat, -lng, -comzip)

print(NROW(round))

# 0-3. make edgeRound data ====
#round       <- filtered_round
edgeRound       <- round[ ,c("year","rnddate","firmname","comname")]
edgeRound$event <- factor(paste(edgeRound$comname, edgeRound$rnddate, sep ="-"))
edgeRound       <- edgeRound[ ,c("year", "firmname", "event")]

#### DATA ARRANGEMENT ----

### 1. identify lead VC ====
LeadVCdta <- leadVC_identifier(round)

### 2. Case-control setting ----
### 2-1. Option 1: randomly selects 1:n ====
# sampling with identified lead VC
# this data indicates that how lead VC selects potential partners from the actual partners list
YQ <- round %>% 
  select(quarter) %>% 
  unique() %>%
  arrange() %>% pull()

starting_time <- Sys.time()
cc_list <- list(); v_loop <- 1

for(i in YQ){
  cc_list[[i]] <- VC_sampling_opt1_output(round, LeadVCdta, quarter, ratio=sample_ratio, i)
  cc_list[[i]]$quarter <- i
  
  ending_time <- Sys.time()
  
  print(paste0(round(v_loop/NROW(YQ)*100,1),
               "% - accumulated time: ", round(ending_time - starting_time,2)," mins"))
  
  v_loop <- v_loop+1
}

samp_dta <- do.call("rbind", cc_list)
ending_time <- Sys.time()
print(paste0(ending_time - starting_time))

# save as fst file
start_time <- Sys.time()
write_fst(samp_dta,
          path=paste0('cc_list_',todayDate,'_',sample_ratio,'.fst'),
          compress=100)

end_time <- Sys.time(); print(end_time - start_time)

### 2-2. [TBU] Option 2: CEM methods ====
# all unrealized ties included



## 3. Variable creation ----

# DO NOT NEED TO RUN THE BELOW CODE UNLESS ROUND DATA CHANGED

if(round_changed == 1){
  ## 3-1-1. Centrality for t-1 centrality (1980 ~ 2022) ====
  start_time <- Sys.time()
  
  cent <- foreach(y=1984:2022,
                  .combine=rbind) %dopar% {
                    cbind(year=y,VC_centralities(edgeRound,y,5,5))
                  }
  
  cent <- cent %>% as_tibble()
  colnames(cent)[2] <- "firmname"
  
  end_time <- Sys.time(); print(end_time - start_time)
  
  write_fst(cent,
            path=paste0('centrality_',todayDate,'_',sample_ratio,'.fst'),
            compress=100)
} else {
  
  print("ROUND HAS NOT CHANGED - USE SAVED CENT DTA")
  
}


####### [ Preprocessing DONE ] #######

## 00-00. final load data ----
samp_dta <- read_fst(paste0('cc_list_',loadDate,'_',sample_ratio,'.fst'))
cent <- read_fst(paste0('centrality_',loadDate,'_',sample_ratio,'.fst'))

# 00-00. data manipulation ----
raw <- samp_dta %>% 
  mutate(year = substr(quarter,1,4)) %>%
  mutate(year = as.numeric(year)) %>%
  filter(year > 1984)

# 00-01. merge leadVC centrality ====
raw <- left_join(raw, cent,
                 by=c('year'='year',
                      'leadVC'='firmname'))

# 00-01. merge coVC centrality ====
raw <- left_join(raw, cent,
                 by=c('year'='year',
                      'coVC'='firmname'))

# 00-02. merge leadVC VC type ====
raw <- left_join(raw, firmdta %>% select(firmname, firmtype2) %>% unique(),
                 by=c('leadVC'='firmname'))

# 00-02. merge coVC VC type ====
raw <- left_join(raw, firmdta %>% select(firmname, firmtype2) %>% unique(),
                 by=c('coVC' = 'firmname'))

# 00-03. merge leadVC VC type ====
raw <- left_join(raw, firmdta %>% select(firmname, firmtype) %>% unique(),
                 by=c('leadVC'='firmname'))

# 00-03. merge coVC VC type ====
raw <- left_join(raw, firmdta %>% select(firmname, firmtype) %>% unique(),
                 by=c('coVC' = 'firmname'))

# 00-04. merge company data ====
raw <- left_join(raw,
                 comdta %>% select(comname,comindmnr,comzip, commsa, comstacode) %>% unique(),
                 by=c("comname"))

# 00-04. merge leadVC firm data  ====
raw <- left_join(raw,
                 firmdta %>% select(firmname, firmmsa, firmstate,
                                    firmzip, fnd_year) %>% unique(),
                 by=c('leadVC'='firmname'))

# 00-05. merge coVC firm data ====
raw <- left_join(raw,
                 firmdta %>% select(firmname, firmmsa, firmstate,
                                    firmzip, fnd_year) %>% unique(),
                 by=c('coVC'='firmname'))

# 00-06. rename raw ----
raw <- raw %>%
  rename(leadVC_dgr = dgr_cent.x,
         leadVC_btw = btw_cent.x,
         leadVC_p75 = pwr_p75.x,
         leadVC_max = pwr_max.x,
         leadVC_zero = pwr_zero.x,
         leadVC_cons = constraint_value.x,
         leadVC_type = firmtype2.x,
         leadVC_type0 = firmtype.x,
         
         coVC_dgr = dgr_cent.y,
         coVC_btw = btw_cent.y,
         coVC_p75 = pwr_p75.y,
         coVC_max = pwr_max.y,
         coVC_zero = pwr_zero.y,
         coVC_cons = constraint_value.y,
         coVC_type = firmtype2.y,
         coVC_type0 = firmtype.y,
         
         leadVC_msa = firmmsa.x,
         leadVC_state = firmstate.x,
         leadVC_zip = firmzip.x,
         leadVC_fndyr = fnd_year.x,
         
         coVC_msa = firmmsa.y,
         coVC_state = firmstate.y,
         coVC_zip = firmzip.y,
         coVC_fndyr = fnd_year.y)

# 00-00. replace corporate dummy ----
#raw <- raw %>%
#  mutate_at(vars('leadVC_cvc','coVC_cvc'),~replace(., is.na(.), 0))

# 00-00. create syndicate-quarter (event) level ----
raw <- raw %>%
  group_by(quarter, comname) %>%
  mutate(synd_lv = cur_group_id()) %>%
  mutate(synd_size = n()) %>%
  ungroup()

# 3-1-2. Network distance between VCs (5yr preceding) (Sorenson & Stuart, 2008) ----
net_dist_list <- list()

yr_list <- round %>% select(year) %>% filter(year > 1984) %>% unique() %>% arrange(year) %>% pull()
pb <- progress_bar$new(total = NROW(yr_list))

for(yr in seq_along(yr_list)){
  pb$tick()
  tmp_ <- raw %>% filter(year==yr_list[yr])
  
  tmp_ <- left_join(tmp_, netDist_count(edgeRound, yr_list[yr],5,5),
                    by=c("leadVC"="VC1",
                         "coVC"="VC2",
                         "year"="year"))
  
  net_dist_list[[yr]] <- tmp_
}

raw <- do.call("bind_rows", net_dist_list)

# merge

rm(net_dist_list) # remove due to size

# 3-1-3. [TBU] Direct ties between VCs (Zhelyazkov & Tatarynowic, 2020) ----

# 3-1-4. [TBU] Indirect ties between VCs (Zhelyazkov & Tatarynowic, 2020) ----

# 3-2-1. industry distance between VCs (5yr preceding) (Sorenson & Stuart, 2008) ----
comind_df <- comdta %>% select(comname, comindmnr)

ind_dist_list <- list()
yr_list <- round %>% select(year) %>% filter(year > 1984) %>% unique() %>% arrange(year) %>% pull()
pb <- progress_bar$new(total = NROW(yr_list))

for(yr in seq_along(yr_list)){
  pb$tick()
  ind_dist_list[[yr]] <- ind_prop_fn(round, comind_df, yr_list[yr],5)
}

# invest proportion, # of invest, blau index
ind_dist_df <- do.call("bind_rows", ind_dist_list)

# calculation (should be updated with function)
comind_list <- comind_df %>% select(comindmnr) %>% unique() %>% 
  filter(comindmnr != "") %>% pull()
comind_list <- gsub(" ","",comind_list) # remove spacing

tmp <- raw %>%
  select(leadVC, coVC, year, comname) %>% unique()

tmp <- left_join(tmp, ind_dist_df,
                 by=c("leadVC"="firmname",
                      "year"="year"))

tmp <- left_join(tmp, ind_dist_df,
                 by=c("coVC"="firmname",
                      "year"="year"))

# remove spacing
names(tmp) <- gsub(" ","",names(tmp))

# replace NA to 0 
tmp <- tmp %>% replace(is.na(.),0)

# calculation (rowwise is not necessary)
tmp <- tmp %>%
  
  mutate(mnrind1 = InternetSpecific.x^2 - InternetSpecific.y^2,
         mnrind2 = ComputerHardware.x^2 - ComputerHardware.y^2,
         mnrind3 = get("Semiconductors/OtherElect..x")^2 - get("Semiconductors/OtherElect..y")^2,
         mnrind4 = ComputerSoftwareandServices.x^2 - ComputerSoftwareandServices.y^2,
         mnrind5 = OtherProducts.x^2 - OtherProducts.y^2,
         mnrind6 = ConsumerRelated.x^2 - ConsumerRelated.y^2,
         mnrind7 = get("Industrial/Energy.x")^2 - get("Industrial/Energy.y")^2,
         mnrind8 = CommunicationsandMedia.x^2 - CommunicationsandMedia.y^2,
         mnrind9 = get("Medical/Health.x")^2 - get("Medical/Health.y")^2,
         mnrind10 = Biotechnology.x^2 - Biotechnology.y^2)

tmp <- tmp %>%
  mutate(indDist = rowSums(across(starts_with('mnrind'))))

tmp <- tmp %>%
  select(coVC, leadVC, comname, year, indDist, 
         totalInv.x, totalInv.y,
         blau.x, blau.y) %>% unique()

# merge
raw <- left_join(raw, tmp, 
                 by=c("coVC", "leadVC", "comname", "year"))

raw <- raw %>%
  rename(leadVC_totalInv = totalInv.x,
         leadVC_blau = blau.x,
         coVC_totalInv = totalInv.y,
         coVC_blau = blau.y)

rm(tmp) # remove due to size of the variable

# 3-2-2. Industry distance btw VC and company ----
comind_df <- comdta %>% select(comname, ind_code_col)

com_dist_list1 <- list()
com_dist_list2 <- list()

yr_list <- round %>% select(year) %>% filter(year > 1984) %>% unique() %>% arrange(year) %>% pull()
pb <- progress_bar$new(total = NROW(yr_list))

for(yr in seq_along(yr_list)){
  pb$tick()
  com_dist_list1[[yr]] <- ind_dist_company(round, comind_df, yr_list[yr],5, 1)
  #  com_dist_list2[[yr]] <- ind_dist_company(round, comind_df, yr_list[yr],5, 2)
  
}

# Option1 : (A&B)|(A|B) as count

# VC-company invested
com_dist_df <- do.call("bind_rows", com_dist_list1)

# lead VC merge
tmp <- raw %>% select(leadVC, coVC, comname, year)
tmp <- left_join(tmp, 
                 comdta %>% select(comname, ind_code_col) %>% unique(),
                 by="comname")

tmp <- left_join(tmp,
                 com_dist_df, 
                 by=c("leadVC"="firmname",
                      "year"="year"))

tmp <- as.data.table(tmp)
# using data.table
tmp <- tmp[,selectedInd := get(ind_code_col),
           by=ind_code_col]

tmp <- tmp %>% as_tibble() %>%
  mutate(leadVC_comDist1 = 1-selectedInd/totalInv) %>%
  select(leadVC, year, comname, leadVC_comDist1) %>%
  unique()

# merge raw
raw <- left_join(raw,
                 tmp,
                 by=c("leadVC","comname","year"))


# co VC merge
tmp <- raw %>% select(leadVC, coVC, comname, year)
tmp <- left_join(tmp, 
                 comdta %>% select(comname, ind_code_col) %>% unique(),
                 by="comname")

tmp <- left_join(tmp,
                 com_dist_df, 
                 by=c("coVC"="firmname",
                      "year"="year"))

tmp <- as.data.table(tmp)
# using data.table
tmp <- tmp[,selectedInd := get(ind_code_col),
           by=ind_code_col]

tmp <- tmp %>% as_tibble() %>%
  mutate(coVC_comDist1 = 1-selectedInd/totalInv) %>%
  select(coVC, year, comname, coVC_comDist1) %>%
  unique()

# merge raw
raw <- left_join(raw,
                 tmp,
                 by=c("coVC","comname","year"))


# Option 2: dummy and count ratio


# 3-3-1. geo distance (Zip) between VCs (Sorenson & Stuart, 2008) ----
# if some zip code missed, then replaced according to other same city level zip lan, lat
zip_code_db <- zipcodeR::zip_code_db

zip_db <- zip_code_db %>% select(major_city,
                                 county, state, lat, lng) %>%
  drop_na(lat) %>%
  group_by(major_city, county, state) %>%
  summarise(lat = mean(lat),
            lng = mean(lng)) %>%
  ungroup() %>%
  rename(lat2 = lat,
         lng2 = lng)

zip_code_db <- left_join(zip_code_db, zip_db,
                         by=c("major_city","county","state"))

# replace zip code if NA
zip_code_db <- zip_code_db %>%
  mutate(lat = ifelse(is.na(lat),lat2,lat),
         lng = ifelse(is.na(lng),lng2,lng))

raw <- raw %>%
  mutate(VC_zipdist = zip_distance(leadVC_zip, coVC_zip)$distance)

# 3-3-2. geo distance (Zip) between VC and company (Sorenson & Stuart, 2008) ----
raw <- raw %>%
  mutate(leadVC_com_zipdist = zip_distance(leadVC_zip, comzip)$distance) %>%
  mutate(coVC_com_zipdist = zip_distance(coVC_zip, comzip)$distance)


# 3-4. Follower Exit percentage (5yrs) (Zhelyazkov & Tatarynowic, 2020) ----
# 3-4-1. company Exit data ====
comExit <- comdta %>% filter(exit==1) %>%
  mutate(com_sit = ifelse(date_sit == '',date_ipo,date_sit)) %>%
  mutate(situ_yr = year(.$com_sit)) %>%
  select(comname, exit, com_sit, situ_yr)

# calculate
vc_exit_list <- list()
yr_list <- round %>% select(year) %>% filter(year > 1979) %>% unique() %>% arrange(year) %>% pull()
pb <- progress_bar$new(total = NROW(yr_list))

for(yr in seq_along(yr_list)){
  pb$tick()
  vc_exit_list[[yr]] <- VC_exit_num(round, comExit, yr_list[yr],5)
}

vc_exit_df <- do.call("bind_rows", vc_exit_list)

# merge
raw <- left_join(raw, vc_exit_df, 
                 by=c("leadVC"="firmname",
                      "year"="newyr"))

raw <- left_join(raw, vc_exit_df, 
                 by=c("coVC"="firmname",
                      "year"="newyr"))

raw <- raw %>%
  rename(leadVC_exitNum = exitNum.x,
         coVC_exitNum = exitNum.y)

# 3-4-2. company IPO data ====
comIPO <- comdta %>% filter(ipoExit==1) %>%
  mutate(com_sit = ifelse(date_sit == '',date_ipo,date_sit)) %>%
  mutate(situ_yr = year(.$com_sit)) %>%
  select(comname, exit, com_sit, situ_yr)

# calculate
vc_ipo_list <- list()
yr_list <- round %>% select(year) %>% filter(year > 1979) %>% unique() %>% arrange(year) %>% pull()
pb <- progress_bar$new(total = NROW(yr_list))

for(yr in seq_along(yr_list)){
  pb$tick()
  vc_ipo_list[[yr]] <- VC_IPO_num(round, comIPO, yr_list[yr],5)
}

vc_ipo_df <- do.call("bind_rows", vc_ipo_list)

# merge
raw <- left_join(raw, vc_ipo_df, 
                 by=c("leadVC"="firmname",
                      "year"="newyr"))

raw <- left_join(raw, vc_ipo_df, 
                 by=c("coVC"="firmname",
                      "year"="newyr"))

raw <- raw %>%
  rename(leadVC_ipoNum = ipoNum.x,
         coVC_ipoNum = ipoNum.y)

# 3-4-3. company M&A data ====
comMnA <- comdta %>% filter(MnAExit==1) %>%
  mutate(com_sit = ifelse(date_sit == '',date_ipo,date_sit)) %>%
  mutate(situ_yr = year(.$com_sit)) %>%
  select(comname, exit, com_sit, situ_yr)

# calculate
vc_MnA_list <- list()
yr_list <- round %>% select(year) %>% filter(year > 1979) %>% unique() %>% arrange(year) %>% pull()
pb <- progress_bar$new(total = NROW(yr_list))

for(yr in seq_along(yr_list)){
  pb$tick()
  vc_MnA_list[[yr]] <- VC_MnA_num(round, comMnA, yr_list[yr],5)
}

vc_MnA_df <- do.call("bind_rows", vc_MnA_list)

# merge
raw <- left_join(raw, vc_MnA_df, 
                 by=c("leadVC"="firmname",
                      "year"="newyr"))

raw <- left_join(raw, vc_MnA_df, 
                 by=c("coVC"="firmname",
                      "year"="newyr"))

raw <- raw %>%
  rename(leadVC_MnANum = MnANum.x,
         coVC_MnANum = MnANum.y)

# 3-5. Follower Investment count(Zhelyazkov & Tatarynowic, 2020) ----
# DONE

# 3-6. Follower's structural hole position (Shipilov, Li, & Greve, 2012) ----
# DONE

# 3-7. average deal size a VC entity in the past (5yr?) ----
# calculate the average amount of investment in the previous 5yr

inv_amt_list <- list()
yr_list <- round %>% select(year) %>% filter(year > 1979) %>% unique() %>% arrange(year) %>% pull()
pb <- progress_bar$new(total = NROW(yr_list))

for(yr in seq_along(yr_list)){
  pb$tick()
  inv_amt_list[[yr]] <- avg_inv_amt(round, yr_list[yr],5)
}

# invest proportion, # of invest, blau index
inv_amt_df <- do.call("bind_rows", inv_amt_list)

inv_amt_df <- inv_amt_df %>% unique()

# merge leadVC
raw <- left_join(raw, inv_amt_df, 
                 by=c("leadVC"="firmname",
                      "year"="newyr"))

# merge coVC
raw <- left_join(raw, inv_amt_df,
                 by=c("coVC"="firmname",
                      "year"="newyr"))

raw <- raw %>%
  rename(leadVC_AmtInv = AmtInvested.x,
         coVC_AmtInv = AmtInvested.y)

# 3-8. firm age ----
raw <- left_join(raw,
                 firmdta %>% select(firmname, firmfounding),
                 by=c("leadVC"="firmname"))

raw <- left_join(raw,
                 firmdta %>% select(firmname, firmfounding),
                 by=c("coVC"="firmname"))

raw <- raw %>%
  mutate(leadVC_age = year - year(firmfounding.x),
         coVC_age = year - year(firmfounding.y)) %>%
  select(-firmfounding.x, -firmfounding.y)

# 3-9. [TBU] Market trends ----


# 3-10. the Number of Funds that follower VC firm raised in 5yrs ----
fund_cnt_list <- list()
yr_list <- round %>% select(year) %>% filter(year > 1984) %>% unique() %>% arrange(year) %>% pull()
pb <- progress_bar$new(total = NROW(yr_list))

for(yr in seq_along(yr_list)){
  pb$tick()
  fund_cnt_list[[yr]] <- VC_fund_count(funddta, yr_list[yr],5)
}

# number of fund raised in a given year
fund_cnt_df <- do.call("bind_rows", fund_cnt_list)

# merge
raw <- left_join(raw,
                 fund_cnt_df,
                 by=c("leadVC"="firmname",
                      "year"="newyr"))

raw <- left_join(raw,
                 fund_cnt_df,
                 by=c("coVC"="firmname",
                      "year"="newyr"))

raw <- raw %>% 
  rename(leadVC_fundcnt = fund_count.x,
         coVC_fundcnt = fund_count.y)

# 3-11. NASDAQ volatility
nasdaq_dta <- read_excel('nasdaq.xlsx',
                         col_names=TRUE)

AnnVol <- nasdaq_dta %>%
  group_by(year) %>%
  summarise(AnnVol = sd(dailyReturn, na.rm=TRUE)*(252^(1/2))) %>%
  select(year, AnnVol)

raw <- left_join(raw,
                 AnnVol,
                 by="year")

# 3-12. CFA

# 4. save raw file ----
write_fst(raw,
          path=paste0('raw_',todayDate,'_',sample_ratio,'.fst'),
          compress=100)


# 5. variable creation ----
# read raw file from data
raw <- read_fst(
  paste0('raw_',loadDate,'_',sample_ratio,'.fst')
)

# 5-1. data for analysis ----
dta <- raw %>%
  mutate(across(starts_with("geoDist"), ~replace_na(.x,0))) %>%
  
  mutate(across(contains("exitNum"), ~replace_na(.x,0))) %>%
  mutate(across(contains("ipoNum"), ~replace_na(.x,0))) %>%
  mutate(across(contains("MnANum"), ~replace_na(.x,0))) %>%
  
  mutate(across(contains("_AmtInv"), ~replace_na(.x,0))) %>%
  mutate(across(contains("_cons"), ~replace_na(.x,0))) %>%
  mutate(across(contains("_dgr"), ~replace_na(.x,0))) %>%
  mutate(across(contains("_max"), ~replace_na(.x,0))) %>%
  mutate(across(contains("_zero"),~replace_na(.x,0))) %>%
  mutate(across(contains("_btw"), ~replace_na(.x,0))) %>%
  mutate(across(contains("_comDist1"), ~replace_na(.x,1))) %>%
  mutate(across(contains("_fundcnt"), ~replace_na(.x,0)))

dta <- dta %>%
  rowwise() %>%
  mutate(bp_abs_max = abs(leadVC_max - coVC_max),
         bp_asy_max = leadVC_max - coVC_max,
         bp_abs_dis_max = bp_abs_max / sum(c(leadVC_max, coVC_max)),
         bp_dis_max = bp_asy_max / sum(c(leadVC_max, coVC_max)),
         
         both_prv = ifelse(leadVC_type=="IVC" & coVC_type=="IVC",1,0),
         both_cvc = ifelse(leadVC_type=="CVC" & coVC_type=="CVC",1,0),
         prvcvc = ifelse((leadVC_type=="IVC" & coVC_type=="CVC")|
                           (leadVC_type=="CVC" & coVC_type=="IVC"),1,0),
         
         hsacvc = ifelse((bp_asy_max > 0 & leadVC_type=="CVC" & coVC_type=="IVC")
                         |(bp_asy_max <=0 & leadVC_type=="IVC" & coVC_type=="CVC"),1,0),
         hsapvc = ifelse((bp_asy_max <= 0 & leadVC_type=="CVC" & coVC_type=="IVC")
                         |(bp_asy_max >0 & leadVC_type=="IVC" & coVC_type=="CVC"),1,0),
         
         prvfin = ifelse((leadVC_type=="IVC" & coVC_type=="Financial")|
                           (leadVC_type=="Financial" & coVC_type=="IVC"),1,0),
         
         prvnonf = ifelse((leadVC_type=="IVC" & coVC_type=="Non-Financial")|
                            (leadVC_type=="Non-Financial" & coVC_type=="IVC"),1,0),
         
         nt_size_sum = sum(c(leadVC_dgr, coVC_dgr)),
         
         leadVC_exitPerc = leadVC_exitNum / leadVC_totalInv,
         coVC_exitPerc = coVC_exitNum / coVC_totalInv,
         coVC_ipoPerc = coVC_ipoNum / coVC_totalInv,
         coVC_MnAPerc = coVC_MnANum / coVC_totalInv) %>%
  
  ungroup()

dta <- dta %>%
  mutate(across(contains("exitPerc"), ~ifelse(is.nan(.), 0,.))) %>%
  mutate(across(contains("ipoPerc"), ~ifelse(is.nan(.), 0,.))) %>%
  mutate(across(contains("MnAPerc"), ~ifelse(is.nan(.), 0,.))) %>%
  mutate(across(contains("zipdist"), ~ifelse(is.na(.),0,.))) %>% # replace na to 0 (1.9%)
  mutate(logzip = log(VC_zipdist+1)) %>%
  mutate(coVC_age = ifelse(coVC_age <0, 0, coVC_age)) %>%
  
  mutate(upwardTie = ifelse(bp_asy_max < 0,1,0), # lead VC status < coVC status
         downwardTie = ifelse(bp_asy_max >0,1,0)) %>% # lead VC status > coVC status
  
  mutate(across(contains("_dis_"),~replace_na(.x,0)))

dta <- dta %>%
  mutate(dyad_cat = case_when(
    both_cvc==1 ~ "1",
    hsacvc==1 ~ "2",
    hsapvc==1 ~ "3",
    both_prv==1 ~ "4"),
    
    dyad_cat = factor(dyad_cat, levels=c("1","2","3","4"))
  )

dta <- dta %>%
  mutate(dyad_cat2 = case_when(
    both_cvc==1 ~ "1",
    prvcvc==1 ~"2",
    both_prv==1 ~"3"),
    
    dyad_cat2 = factor(dyad_cat2, levels=c("1","2","3"))
  )

dta <- dta %>%
  mutate(dyad_cat3 = case_when(
    both_cvc==1 ~ "2",
    prvcvc == 1 ~ "3",
    TRUE ~ "1"),
    
    dyad_cat3 = factor(dyad_cat3, levels=c("1","2","3"))
  )

# 5-2. rescale variables ----
dta <- dta %>%
  group_by(year) %>% 
  mutate(mc_bp_abs_dis_max = scale(bp_abs_dis_max, scale=FALSE),
         mc_bp_dis_max = scale(bp_dis_max, scale=FALSE),
         mc_bp_dis_max_sq = mc_bp_dis_max^2,
         
         z_bp_abs_dis_max = scale(bp_abs_dis_max, scale=TRUE),
         z_bp_dis_max = scale(bp_dis_max, scale=TRUE)) %>%
  ungroup()

# structural holes
dta <- dta %>%
  group_by(year) %>%
  mutate(coVC_sh = 1 - ((coVC_cons - min(coVC_cons))/((max(coVC_cons) - min(coVC_cons))))) %>%
  ungroup()

# 1-2. orthogonalized variables
# coVC_totalInv & coVC_AMTInv
#orthmat <- dta %>%
#  select(leadVC, coVC, comname, year, coVC_totalInv, coVC_AmtInv)

#tmp <- orthmat %>%
#  filter(year == 1990) %>%
#  select(coVC_totalInv, coVC_AmtInv)

# orth1 <- orthonormalization(tmp)


# 5-3. write data file (STATA/R)----
# STATA file
haven::write_dta(
  dta,
  paste0('dta_',todayDate,'_',sample_ratio,'.dta')
)

# fst data
write_fst(dta,
          path=paste0('dta_',todayDate,'_',sample_ratio,'.fst'),
          compress=100)


# 6. random cluster sampling
sample_rate <- 1
sample_size <- NROW(dta %>% select(synd_lv) %>% unique())

clust_id <- sample(unique(dta$synd_lv), 
                   size=round(sample_rate*sample_size), replace=F)

clust_dta <- dta[dta$synd_lv %in% clust_id,]

haven::write_dta(
  clust_dta,
  paste0('clust_',todayDate,'_',sample_ratio,'.dta')
)

# [[[[[[[ end of code ]]]]]]]####
