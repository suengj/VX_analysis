## panel_setup_and_vars.R
## Panel keys, derived variables, Mundlak means, and initial-variable selectors

# Auto-install missing packages
required_packages <- c("dplyr", "tidyr", "stringr", "purrr", "plm")
missing_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]
if(length(missing_packages) > 0) {
  message("Installing missing packages: ", paste(missing_packages, collapse = ", "))
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(purrr)
  library(plm)
})

#' Ensure panel keys (firmname, year) and derive variables
#' - firmage_log = log1p(firmage)
#' - inv_amt_log = log1p(inv_amt)
#' - after7 = already created by loader (keep consistent)
#' - years_since_init kept as integer
#' @param df tibble
#' @return tibble
derive_panel_vars <- function(df) {
  stopifnot("firmname" %in% names(df), "year" %in% names(df))
  df %>%
    mutate(
      firmname = as.character(firmname),
      year = as.integer(year),
      firmage_log = log1p(as.numeric(firmage)),
      inv_amt_log = log1p(as.numeric(inv_amt)),
      # ensure ints
      years_since_init = as.integer(years_since_init),
      after7 = as.integer(after7)
    )
}

#' Add Mundlak means for selected time-varying controls at firm level
#' @param df tibble with firmname key
#' @param controls character vector of control names
#' @return tibble with *_firm_mean columns
add_mundlak_means <- function(df, controls = c("early_stage_ratio","industry_blau","inv_amt_log","dgr_cent")) {
  missing <- setdiff(controls, names(df))
  if (length(missing) > 0) {
    # Create missing controls as NA to keep interface stable
    for (m in missing) df[[m]] <- NA_real_
  }
  means <- df %>%
    group_by(firmname) %>%
    summarise(across(all_of(controls), ~ mean(.x, na.rm = TRUE), .names = "{.col}_firm_mean"), .groups = "drop")
  df %>% left_join(means, by = "firmname")
}

#' Create lagged variables for time-varying covariates
#' Uses plm::lag() to create lag(1) for panel data
#' @param df tibble with firmname and year columns
#' @param vars_to_lag character vector of variable names to lag
#' @return tibble with lagged variables (named as {var}_lag1)
create_lagged_vars <- function(df, vars_to_lag) {
  # Ensure data is sorted by firmname and year
  df <- df %>%
    arrange(firmname, year)
  
  # Convert to pdata.frame for lag operation
  pdata <- plm::pdata.frame(df, index = c("firmname", "year"))
  
  # Create lagged variables
  for (var in vars_to_lag) {
    if (var %in% names(df)) {
      lag_var_name <- paste0(var, "_lag1")
      pdata[[lag_var_name]] <- plm::lag(pdata[[var]], k = 1)
    }
  }
  
  # Convert back to tibble (pdata.frame attributes are preserved but can be converted)
  result <- as.data.frame(pdata)
  # Remove plm-specific attributes that might cause issues
  attr(result, "index") <- NULL
  class(result) <- setdiff(class(result), c("pdata.frame", "data.frame"))
  class(result) <- c("tbl_df", "tbl", "data.frame")
  as_tibble(result)
}

#' Build initial-condition variable names based on power set and aggregation types
#' @param init_set one of "p75", "p0", "p99"
#' @param agg_types character vector: "mean", "max", "min", or combinations
#' @return character vector of variable names
#' @examples
#' build_initial_vars("p75", c("mean"))  # Returns: c("initial_pwr_p75_mean")
#' build_initial_vars("p75", c("mean", "max"))  # Returns: c("initial_pwr_p75_mean", "initial_pwr_p75_max")
build_initial_vars <- function(init_set = c("p75","p0","p99"), 
                                agg_types = c("mean")) {
  init_set <- match.arg(init_set)
  
  # Validate aggregation types
  valid_agg <- c("mean", "max", "min")
  invalid <- setdiff(agg_types, valid_agg)
  if (length(invalid) > 0) {
    stop("Invalid aggregation types: ", paste(invalid, collapse=", "), 
         ". Valid types are: ", paste(valid_agg, collapse=", "))
  }
  
  # Build variable names
  base_name <- paste0("initial_pwr_", init_set, "_")
  vars <- paste0(base_name, agg_types)
  vars
}

#' Return initial-condition variable set (legacy function, use build_initial_vars instead)
#' @param mode one of c("p75","p0","p99","all")
#' @return character vector
initial_vars <- function(mode = c("p75","p0","p99","all")) {
  mode <- match.arg(mode)
  p0  <- c("initial_pwr_p0_mean","initial_pwr_p0_max","initial_pwr_p0_min")
  p75 <- c("initial_pwr_p75_mean","initial_pwr_p75_max","initial_pwr_p75_min")
  p99 <- c("initial_pwr_p99_mean","initial_pwr_p99_max","initial_pwr_p99_min")
  if (mode == "p0") return(p0)
  if (mode == "p75") return(p75)
  if (mode == "p99") return(p99)
  c(p0, p75, p99)
}

#' Compose a modeling dataset with chosen DV and predictors
#' @param df tibble (already derived)
#' @param dv one of 'perf_IPO','perf_all','perf_MnA'
#' @param init_set which initial set ('p75' default)
#' @param include_mundlak add *_firm_mean controls
#' @return tibble
make_model_frame <- function(
  df,
  dv = c("perf_IPO","perf_all","perf_MnA"),
  init_set = c("p75","p0","p99"),
  include_mundlak = TRUE
) {
  dv <- match.arg(dv)
  init_set <- match.arg(init_set)
  
  base <- df %>%
    select(
      firmname, year, {{dv}} := all_of(dv),
      years_since_init, after7,
      firmage_log, early_stage_ratio, industry_blau, inv_amt_log, dgr_cent, constraint,
      all_of(initial_vars(init_set))
    )
  
  if (include_mundlak) {
    base <- add_mundlak_means(base, controls = c("early_stage_ratio","industry_blau","inv_amt_log","dgr_cent"))
  }
  base
}


