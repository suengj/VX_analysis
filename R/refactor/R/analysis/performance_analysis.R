# Performance Analysis Functions
# Extracted from CVC_preprcs_v4.R
# Original logic preserved for performance measurement

# Load required packages
if (!require('tidyverse')) install.packages('tidyverse'); library('tidyverse')

#' Calculate VC exit numbers
#' Original function from CVC_preprcs_v4.R
#' @param r_df Round data
#' @param c_df Company data with exit information
#' @param v_yr Target year
#' @param yr_cut Time window for analysis
#' @return Exit numbers by VC
VC_exit_num <- function(r_df, c_df, v_yr, yr_cut=5){
  
  # Original logic from CVC_preprcs_v4.R
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

#' Calculate VC IPO numbers
#' Original function from CVC_preprcs_v4.R
#' @param r_df Round data
#' @param c_df Company data with IPO information
#' @param v_yr Target year
#' @param yr_cut Time window for analysis
#' @return IPO numbers by VC
VC_IPO_num <- function(r_df, c_df, v_yr, yr_cut=5){
  
  # Original logic from CVC_preprcs_v4.R
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
    mutate(ipoNum = sum(ipoExit)) %>% 
    select(firmname, newyr, ipoNum) %>% 
    unique()
  
  return(tmp)
}

#' Calculate VC M&A numbers
#' Original function from CVC_preprcs_v4.R
#' @param r_df Round data
#' @param c_df Company data with M&A information
#' @param v_yr Target year
#' @param yr_cut Time window for analysis
#' @return M&A numbers by VC
VC_MnA_num <- function(r_df, c_df, v_yr, yr_cut=5){
  
  # Original logic from CVC_preprcs_v4.R
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
    mutate(MnANum = sum(MnAExit)) %>% 
    select(firmname, newyr, MnANum) %>% 
    unique()
  
  return(tmp)
}

#' Calculate exit percentages
#' @param exit_data Exit data
#' @param investment_data Investment data
#' @return Exit percentages
calculate_exit_percentages <- function(exit_data, investment_data) {
  
  # Calculate exit percentages
  exit_percentages <- left_join(exit_data, investment_data, by = c("firmname", "year")) %>%
    mutate(
      exit_percentage = exitNum / total_investments,
      ipo_percentage = ipoNum / total_investments,
      mna_percentage = MnANum / total_investments
    ) %>%
    mutate(across(contains("percentage"), ~ifelse(is.nan(.), 0, .)))
  
  return(exit_percentages)
}

#' Create exit data from company information
#' @param company_data Company data
#' @return Exit data with exit types
create_exit_data <- function(company_data) {
  
  # Original logic from CVC_preprcs_v4.R with proper exit detection
  exit_data <- company_data %>%
    mutate(
      # Create exit dummy based on comsitu and dates
      exit = ifelse(comsitu %in% c("Went Public", "Acquisition", "Merger") & 
                   (!is.na(date_ipo) | !is.na(date_sit)), 1, 0),
      # Create IPO exit dummy
      ipoExit = ifelse(comsitu %in% c("Went Public") & 
                      (!is.na(date_ipo) | !is.na(date_sit)), 1, 0),
      # Create M&A exit dummy
      MnAExit = ifelse(comsitu %in% c("Acquisition", "Merger") & 
                      !is.na(date_sit), 1, 0)
    ) %>%
    # Extract year from date_sit or date_ipo
    mutate(situ_yr = case_when(
      !is.na(date_sit) ~ year(date_sit),
      !is.na(date_ipo) ~ year(date_ipo),
      TRUE ~ NA_integer_
    ))
  
  return(exit_data)
}

#' Calculate performance metrics for multiple years
#' @param round_data Round data
#' @param company_data Company data
#' @param years Vector of years to analyze
#' @param time_window Time window for analysis
#' @return Performance metrics for all years
calculate_performance_metrics <- function(round_data, company_data, years, time_window = 5) {
  
  # Create exit data
  exit_data <- create_exit_data(company_data)
  
  # Calculate exit numbers for each year
  exit_list <- list()
  ipo_list <- list()
  mna_list <- list()
  
  for (yr in years) {
    exit_list[[as.character(yr)]] <- VC_exit_num(round_data, exit_data, yr, time_window)
    ipo_list[[as.character(yr)]] <- VC_IPO_num(round_data, exit_data, yr, time_window)
    mna_list[[as.character(yr)]] <- VC_MnA_num(round_data, exit_data, yr, time_window)
  }
  
  # Combine results
  exit_df <- do.call("bind_rows", exit_list)
  ipo_df <- do.call("bind_rows", ipo_list)
  mna_df <- do.call("bind_rows", mna_list)
  
  # Merge all performance metrics
  performance_df <- left_join(exit_df, ipo_df, by = c("firmname", "newyr")) %>%
    left_join(mna_df, by = c("firmname", "newyr")) %>%
    rename(year = newyr)
  
  return(performance_df)
}

#' Calculate Welch's t-test for performance comparison
#' Original function from CVC_preprcs_v4.R
#' @param data Input data
#' @param col_nm1 Group column
#' @param col_nm2_txt Variable to test
#' @return T-test results
welch_t_test <- function(data, col_nm1, col_nm2_txt) {
  
  # Original logic from CVC_preprcs_v4.R
  x <- data %>% filter({{col_nm1}} == 1) %>% select(all_of(col_nm2_txt)) # case group
  y <- data %>% filter({{col_nm1}} == 0) %>% select(all_of(col_nm2_txt)) # control group
  
  ttest <- t.test(x, y)
  
  mean.dif <- ttest$estimate[1] - ttest$estimate[2]
  p.value <- ttest$p.value
  
  result <- cbind(mean.dif, p.value)
  colnames(result) <- c("mean.dif", "p.value")
  row.names(result) <- c(col_nm2_txt)
  
  return(result)
}

#' Calculate performance summary statistics
#' @param performance_data Performance data
#' @param group_var Grouping variable
#' @return Performance summary by group
calculate_performance_summary <- function(performance_data, group_var) {
  
  summary_stats <- performance_data %>%
    group_by({{group_var}}) %>%
    summarise(
      avg_exits = mean(exitNum, na.rm = TRUE),
      avg_ipos = mean(ipoNum, na.rm = TRUE),
      avg_mnas = mean(MnANum, na.rm = TRUE),
      total_exits = sum(exitNum, na.rm = TRUE),
      total_ipos = sum(ipoNum, na.rm = TRUE),
      total_mnas = sum(MnANum, na.rm = TRUE),
      .groups = "drop"
    )
  
  return(summary_stats)
} 