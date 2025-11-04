# Diversity Analysis Functions
# Extracted from imprinting_Dec18.R
# Original logic preserved for diversity calculations

# Load required packages
if (!require('tidyverse')) install.packages('tidyverse'); library('tidyverse')

#' Calculate Blau index for diversity measurement
#' Original function from imprinting_Dec18.R
#' @param b_df Data frame with firmname, year, and industry columns
#' @return Data frame with Blau index and total investment
blau_index <- function(b_df){
  
  start_time <- Sys.time()

  # Original logic from imprinting_Dec18.R
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

#' Calculate industry proportion for firms
#' @param round_data Investment round data
#' @param company_data Company data with industry information
#' @param target_year Target year for analysis
#' @param year_cut Time window for analysis
#' @return Industry proportion data
calculate_industry_proportion <- function(round_data, company_data, target_year, year_cut = 5) {
  
  # Filter data for the time window
  filtered_data <- round_data %>%
    filter(year >= target_year - year_cut & year < target_year) %>%
    left_join(company_data, by = "comname")
  
  # Calculate industry proportions
  industry_prop <- filtered_data %>%
    group_by(firmname, comindmnr) %>%
    summarise(
      industry_count = n(),
      total_investments = n(),
      .groups = "drop"
    ) %>%
    group_by(firmname) %>%
    mutate(
      total_firm_investments = sum(industry_count),
      industry_proportion = industry_count / total_firm_investments
    ) %>%
    ungroup()
  
  return(industry_prop)
}

#' Calculate portfolio diversity measures
#' @param industry_data Industry proportion data
#' @return Portfolio diversity measures
calculate_portfolio_diversity <- function(industry_data) {
  
  # Calculate portfolio diversity using Blau index
  portfolio_diversity <- industry_data %>%
    group_by(firmname) %>%
    summarise(
      portfolio_diversity = 1 - sum(industry_proportion^2, na.rm = TRUE),
      industry_count = n_distinct(comindmnr, na.rm = TRUE),
      .groups = "drop"
    )
  
  return(portfolio_diversity)
}

#' Calculate geographic diversity measures
#' @param round_data Investment round data
#' @return Geographic diversity measures
calculate_geographic_diversity <- function(round_data) {
  
  # Calculate geographic diversity
  geographic_diversity <- round_data %>%
    group_by(firmname, year) %>%
    summarise(
      geographic_diversity = n_distinct(comnation, na.rm = TRUE),
      total_investments = n(),
      .groups = "drop"
    )
  
  return(geographic_diversity)
}

#' Calculate stage diversity measures
#' @param round_data Investment round data
#' @return Stage diversity measures
calculate_stage_diversity <- function(round_data) {
  
  # Calculate stage diversity
  stage_diversity <- round_data %>%
    group_by(firmname, year) %>%
    summarise(
      stage_diversity = n_distinct(rndstage, na.rm = TRUE),
      total_investments = n(),
      .groups = "drop"
    )
  
  return(stage_diversity)
}

#' Calculate industry proportion for firms
#' @param round_data Investment round data
#' @param company_data Company data with industry information
#' @param target_year Target year for analysis
#' @param year_cut Time window for analysis
#' @return Industry proportion data
calculate_industry_proportion <- function(round_data, company_data, target_year, year_cut = 5) {
  
  # Original logic from CVC_preprcs_v4.R
  tmp <- round_data %>% 
    filter(year >= target_year - year_cut & year < target_year) %>%
    mutate(newyr = target_year) %>%
    select(firmname, newyr, comname)
  
  tmp <- left_join(tmp, company_data, by="comname")
  
  tmp <- tmp %>% filter(comindmnr != "" | comindmnr != 0) %>%
    count(firmname, comindmnr) %>%
    pivot_wider(names_from = comindmnr, values_from = n, values_fill = 0)
  
  return(tmp)
}

#' Calculate portfolio diversity measures
#' @param investment_data Investment data
#' @param company_data Company data with industry information
#' @param time_window Time window for analysis
#' @return Portfolio diversity measures
calculate_portfolio_diversity <- function(investment_data, company_data, time_window = 5) {
  
  # Get unique years
  years <- unique(investment_data$year)
  
  diversity_list <- list()
  
  for(year in years) {
    # Calculate industry proportion
    industry_prop <- calculate_industry_proportion(investment_data, company_data, year, time_window)
    
    # Calculate Blau index
    if(nrow(industry_prop) > 0) {
      diversity_list[[as.character(year)]] <- blau_index(industry_prop)
    }
  }
  
  # Combine results
  diversity_data <- do.call("rbind", diversity_list)
  return(diversity_data)
}

#' Calculate geographic diversity
#' @param investment_data Investment data with geographic information
#' @param time_window Time window for analysis
#' @return Geographic diversity measures
calculate_geographic_diversity <- function(investment_data, time_window = 5) {
  
  # Calculate geographic distribution
  geo_diversity <- investment_data %>%
    group_by(firmname, year, state) %>%
    summarise(investments = n(), .groups = "drop") %>%
    group_by(firmname, year) %>%
    summarise(
      total_investments = sum(investments),
      unique_states = n_distinct(state),
      geo_blau = 1 - sum((investments / total_investments)^2),
      .groups = "drop"
    )
  
  return(geo_diversity)
}

#' Calculate stage diversity
#' @param investment_data Investment data with stage information
#' @param time_window Time window for analysis
#' @return Stage diversity measures
calculate_stage_diversity <- function(investment_data, time_window = 5) {
  
  # Calculate stage distribution
  stage_diversity <- investment_data %>%
    group_by(firmname, year, CompanyStageLevel1) %>%
    summarise(investments = n(), .groups = "drop") %>%
    group_by(firmname, year) %>%
    summarise(
      total_investments = sum(investments),
      unique_stages = n_distinct(CompanyStageLevel1),
      stage_blau = 1 - sum((investments / total_investments)^2),
      .groups = "drop"
    )
  
  return(stage_diversity)
} 