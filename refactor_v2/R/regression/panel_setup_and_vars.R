## panel_setup_and_vars.R
## Panel keys, derived variables, Mundlak means, and initial-variable selectors

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

#' Create pdata.frame (optional downstream use)
#' @param df tibble
#' @return pdata.frame
to_panel <- function(df) {
  plm::pdata.frame(df, index = c("firmname","year"))
}

#' Return initial-condition variable set
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


