## models_zinb_glmmTMB.R
## Main ZINB with firm RE, year FE, Mundlak means; exports tidy summaries

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(glmmTMB)
  library(broom.mixed)
  library(performance)
  library(readr)
  library(stringr)
})

#' Safe accessor for initial variable set
get_initial_vars <- function(mode = c("p75","p0","p99")) {
  mode <- match.arg(mode)
  if (exists("initial_vars", mode = "function")) {
    return(initial_vars(mode))
  }
  # Fallback default: p75
  if (mode == "p0")  return(c("initial_pwr_p0_mean","initial_pwr_p0_max","initial_pwr_p0_min"))
  if (mode == "p99") return(c("initial_pwr_p99_mean","initial_pwr_p99_max","initial_pwr_p99_min"))
  c("initial_pwr_p75_mean","initial_pwr_p75_max","initial_pwr_p75_min")
}

#' Build glmmTMB ZINB formula
#' @param dv dependent variable
#' @param init_vars character vector of initial-condition variables
#' @param include_year_fe logical
#' @param include_mundlak logical
build_formula <- function(dv,
                          init_vars,
                          include_year_fe = TRUE,
                          include_mundlak = TRUE) {
  controls <- c("years_since_init","after7","firmage_log",
                "early_stage_ratio","industry_blau","inv_amt_log","dgr_cent")
  mundlak <- if (include_mundlak)
    c("early_stage_ratio_firm_mean","industry_blau_firm_mean","inv_amt_log_firm_mean","dgr_cent_firm_mean")
  else character(0)
  rhs <- c(init_vars, controls, mundlak)
  rhs <- rhs[!duplicated(rhs)]
  rhs_str <- paste(rhs, collapse = " + ")
  if (include_year_fe) {
    rhs_str <- paste(rhs_str, "+ factor(year)")
  }
  # Random intercept for firm
  rhs_str <- paste(rhs_str, "+ (1|firmname)")
  stats::as.formula(paste0(dv, " ~ ", rhs_str))
}

#' Fit ZINB model with ziformula ~ 1
#' @param df data frame
#' @param dv dependent variable
#' @param init_vars initial-condition variables
#' @param include_year_fe include year FE
#' @param include_mundlak include Mundlak means
#' @return glmmTMB object
fit_zinb <- function(df, dv, init_vars,
                     include_year_fe = TRUE,
                     include_mundlak = TRUE) {
  fml <- build_formula(dv, init_vars, include_year_fe, include_mundlak)
  glmmTMB::glmmTMB(
    formula = fml,
    ziformula = ~ 1,
    family = glmmTMB::nbinom2(),
    data = df,
    REML = FALSE
  )
}

#' Tidy and export model outputs (conditional and zero-inflation parts)
#' @param model glmmTMB fit
#' @param dv dependent variable name
#' @param model_tag short tag for filename
#' @param out_dir output directory
export_glmmTMB_results <- function(model, dv, model_tag, out_dir) {
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  # Conditional (exponentiate = IRR)
  cond <- broom.mixed::tidy(model, effects = "fixed", component = "cond", conf.int = TRUE, exponentiate = TRUE)
  zi   <- broom.mixed::tidy(model, effects = "fixed", component = "zi",   conf.int = TRUE, exponentiate = TRUE)
  glance_df <- broom.mixed::glance(model)
  
  readr::write_csv(cond, file.path(out_dir, paste0("model_", dv, "_", model_tag, "_cond.csv")))
  readr::write_csv(zi,   file.path(out_dir, paste0("model_", dv, "_", model_tag, "_zi.csv")))
  readr::write_csv(glance_df, file.path(out_dir, paste0("model_", dv, "_", model_tag, "_glance.csv")))
}

#' Convenience runner for a DV
#' @param df modeling frame (include Mundlak means already)
#' @param dv dependent variable name
#' @param init_set one of 'p75','p0','p99'
#' @param out_dir output dir
run_main_zinb_for_dv <- function(df, dv, init_set = c("p75","p0","p99"),
                                 out_dir = file.path(
                                   "/Users","suengj","Documents","Code","Python","Research","VC",
                                   "refactor_v2","notebooks","analysis_outputs")) {
  init_set <- match.arg(init_set)
  form_builder <- get_initial_vars(init_set)
  model <- fit_zinb(df, dv, form_builder, include_year_fe = TRUE, include_mundlak = TRUE)
  export_glmmTMB_results(model, dv, paste0("zinb_", init_set), out_dir)
  model
}


