# Data Loader for R Regression Analysis
# 
# This script loads preprocessed Parquet files created by the Python pipeline
# and prepares them for regression analysis in R.

library(arrow)
library(dplyr)
library(tidyr)

#' Load Parquet Data
#'
#' @param file_path Path to Parquet file
#' @return tibble
load_parquet_data <- function(file_path) {
  if (!file.exists(file_path)) {
    stop(paste("File not found:", file_path))
  }
  
  cat("Loading data from:", file_path, "\n")
  
  df <- read_parquet(file_path) %>%
    as_tibble()
  
  cat("Loaded:", nrow(df), "rows,", ncol(df), "columns\n")
  
  return(df)
}


#' Load CVC Analysis Data
#'
#' @param data_dir Directory containing processed data
#' @return tibble
load_cvc_data <- function(data_dir = "processed_data/cvc_analysis") {
  file_path <- file.path(data_dir, "final_data.parquet")
  
  df <- load_parquet_data(file_path)
  
  # Convert categorical variables to factors
  factor_cols <- c("leadVC", "coVC", "comname", "quarter")
  for (col in factor_cols) {
    if (col %in% colnames(df)) {
      df[[col]] <- as.factor(df[[col]])
    }
  }
  
  # Ensure numeric variables are numeric
  numeric_cols <- c("dgr_cent", "btw_cent", "pwr_p75", "pwr_p99", 
                    "constraint", "realized", "year")
  for (col in numeric_cols) {
    if (col %in% colnames(df)) {
      df[[col]] <- as.numeric(df[[col]])
    }
  }
  
  return(df)
}


#' Load Imprinting Analysis Data
#'
#' @param data_dir Directory containing processed data
#' @return tibble
load_imprinting_data <- function(data_dir = "processed_data/imprinting_analysis") {
  file_path <- file.path(data_dir, "panel_data.parquet")
  
  df <- load_parquet_data(file_path)
  
  # Convert categorical variables to factors
  df$firmname <- as.factor(df$firmname)
  
  # Ensure numeric variables are numeric
  numeric_cols <- c("year", "timesince", "dgr_cent", "btw_cent", 
                    "exitNum", "blau_index")
  for (col in numeric_cols) {
    if (col %in% colnames(df)) {
      df[[col]] <- as.numeric(df[[col]])
    }
  }
  
  return(df)
}


#' Summary Statistics
#'
#' @param df Data frame
#' @param variables Variables to summarize
print_summary_stats <- function(df, variables = NULL) {
  if (is.null(variables)) {
    variables <- colnames(df)[sapply(df, is.numeric)]
  }
  
  cat("\n========== Summary Statistics ==========\n\n")
  
  for (var in variables) {
    if (var %in% colnames(df)) {
      cat(var, ":\n")
      print(summary(df[[var]]))
      cat("\n")
    }
  }
}


# Example usage:
# cvc_data <- load_cvc_data()
# print_summary_stats(cvc_data, c("dgr_cent", "btw_cent", "realized"))

