# Sampling Functions
# Extracted from CVC_preprcs_v4.R
# Original logic preserved for case-control sampling

# Load required packages
if (!require('tidyverse')) install.packages('tidyverse'); library('tidyverse')
if (!require('progress')) install.packages('progress'); library('progress')

#' Case-control sampling for VC partnerships
#' Original function from CVC_preprcs_v4.R
#' @param v_dta Investment data for a specific company
#' @param v_coVC_unique Unique list of potential co-investors
#' @param ratio Sampling ratio (e.g., 1:10)
#' @return Sampled case-control data
VC_sampling_opt1 <- function(v_dta, v_coVC_unique, ratio){
  
  # Original logic: actual investment history (LeadVC - PartnerVC - company)
  v_dta <- v_dta %>% unique() # remove any duplicated investment by the same VC in a given period
  
  # Original logic: make all potential partner list to a given event
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
  
  # Original logic: realized ties
  df_realized_ties <- df_all_ties %>%
    filter(realized==1)
  
  # Original logic: potential coVC list in a give period
  df_unrealized_ties <- df_all_ties %>%
    filter(realized==0)
  
  # Original logic: sampling
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

#' Case-control sampling output function
#' Original function from CVC_preprcs_v4.R
#' @param v_dta Investment data
#' @param v_leadVCdta Lead VC identification data
#' @param column_nm Column name for time period
#' @param ratio Sampling ratio
#' @param i Time period identifier
#' @return Sampled case-control data for the period
VC_sampling_opt1_output <- function(v_dta, v_leadVCdta, column_nm, ratio, i){
  
  start_time <- Sys.time()
  
  # Original logic: identify all realized event in a given period
  realized_event <- v_dta %>%
    filter({{column_nm}} == i) %>%
    select(firmname, comname, {{column_nm}}) 
  
  # Original logic: identify LeadVC in the given period by using LeadVC data
  realized_event <- left_join(realized_event, v_leadVCdta,
                              by=c("firmname", "comname"))
  
  realized_event <- realized_event %>%
    mutate(leadVC = replace_na(leadVC,0)) 
  
  # Original logic: split samples
  LeadVC <- realized_event %>%
    filter(leadVC==1)
  NonLeadVC <- realized_event %>%
    filter(leadVC==0)
  
  # Original logic: all realized ties
  # LeadVC column x NonLeadVC column combination
  realized_ties <- full_join(LeadVC %>% select(firmname, comname), 
                             NonLeadVC %>% select(firmname, comname), by="comname") %>%
    drop_na() %>%
    rename(leadVC = firmname.x,
           coVC = firmname.y) %>%
    select(leadVC, comname, coVC) %>%
    mutate(realized=1)
  
  # Original logic: identify coVC unique list
  coVC_unique <- NonLeadVC %>% select(firmname) %>% unique() %>% 
    rename(coVC = firmname) %>% as.list()
  
  # Original logic: loop 
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

#' Create case-control dataset for multiple time periods
#' @param round_data Investment round data
#' @param leadVC_data Lead VC identification data
#' @param time_column Column name for time period
#' @param ratio Sampling ratio
#' @param time_periods Vector of time periods to sample
#' @return Combined case-control data
create_case_control_dataset <- function(round_data, leadVC_data, time_column, ratio, time_periods) {
  
  cc_list <- list()
  
  for(i in time_periods) {
    cat("Processing time period:", i, "\n")
    cc_list[[as.character(i)]] <- VC_sampling_opt1_output(
      round_data, leadVC_data, time_column, ratio, i
    )
  }
  
  cc_data <- do.call("rbind", cc_list)
  return(cc_data)
}

#' Validate sampling parameters
#' @param data Input data
#' @param ratio Sampling ratio
#' @param time_periods Time periods
#' @return Validation result
validate_sampling_params <- function(data, ratio, time_periods) {
  
  if (is.null(data) || nrow(data) == 0) {
    stop("Data is empty or NULL")
  }
  
  if (ratio <= 0) {
    stop("Sampling ratio must be positive")
  }
  
  if (length(time_periods) == 0) {
    stop("At least one time period must be specified")
  }
  
  return(TRUE)
} 