# Data Processing Functions
# Extracted from CVC_preprcs_v4.R
# Original logic preserved for data manipulation

# Load required packages
if (!require('tidyverse')) install.packages('tidyverse'); library('tidyverse')

#' Extract unique date identifiers
#' Original function from CVC_preprcs_v4.R
#' @param data Input data
#' @param column_nm Column name for date/time identifier
#' @return Vector of unique date identifiers
date_unique_identifier <- function(data, column_nm){
  
  # Original logic
  unique_list <- data %>% select(all_of(column_nm))
  unique_list <- unique_list %>%
    unique() %>%
    arrange(.[[1]]) %>% # ascending order
    pull(1) # set as vector
  
  #  rownames(unique_list) <- NULL # reset row index
  
  return(unique_list)
}

#' Identify Lead VCs based on investment criteria
#' Original function from CVC_preprcs_v4.R
#' @param data Investment data
#' @return Lead VC identification data
leadVC_identifier <- function(data){
  
  set.seed(123) # for random sampling below
  
  # Original logic from CVC_preprcs_v4.R
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

#' Create event identifiers for investment rounds
#' @param data Investment data
#' @param company_col Company column name
#' @param date_col Date column name
#' @param year_col Year column name
#' @return Data with event identifiers
create_event_identifiers <- function(data, company_col = "comname", date_col = "rnddate", year_col = "year") {
  
  # Original logic from imprinting_Dec18.R
  event_data <- data %>%
    select(all_of(c(year_col, date_col, "firmname", company_col))) %>%
    mutate(
      event1 = factor(paste(!!sym(company_col), !!sym(date_col), sep = "-")),
      event2 = factor(paste(!!sym(company_col), !!sym(year_col), sep = "-"))
    )
  
  return(event_data)
}

#' Filter investment data by criteria
#' @param data Investment data
#' @param min_year Minimum year
#' @param max_year Maximum year
#' @param exclude_undisclosed Whether to exclude undisclosed firms/companies
#' @return Filtered investment data
filter_investment_data <- function(data, min_year = 1980, max_year = 2022, exclude_undisclosed = TRUE) {
  
  filtered_data <- data %>%
    filter(year >= min_year, year <= max_year)
  
  if (exclude_undisclosed) {
    filtered_data <- filtered_data %>%
      filter(firmname != "Undisclosed Firm", comname != "Undisclosed Company")
  }
  
  return(filtered_data)
}

#' Calculate investment statistics by firm
#' @param data Investment data
#' @param group_vars Grouping variables
#' @return Investment statistics
calculate_investment_stats <- function(data, group_vars = c("firmname", "year")) {
  
  stats <- data %>%
    group_by(across(all_of(group_vars))) %>%
    summarise(
      total_investments = n(),
      total_amount = sum(RoundAmount, na.rm = TRUE),
      avg_amount = mean(RoundAmount, na.rm = TRUE),
      .groups = "drop"
    )
  
  return(stats)
} 