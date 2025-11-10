## models_zinb_glmmTMB.R
## Main ZINB with firm RE, year FE, Mundlak means; exports tidy summaries

# Auto-install missing packages
required_packages <- c("dplyr", "tidyr", "glmmTMB", "broom.mixed", "performance", "readr", "stringr")
missing_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]
if(length(missing_packages) > 0) {
  message("Installing missing packages: ", paste(missing_packages, collapse = ", "))
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(glmmTMB)
  library(broom.mixed)
  library(performance)
  library(readr)
  library(stringr)
})

#' Build glmmTMB ZINB formula
#' @param dv dependent variable
#' @param init_vars character vector of initial-condition variables
#' @param controls character vector of main control variables
#' @param mundlak_terms character vector of Mundlak term names (e.g., "early_stage_ratio_firm_mean")
#' @param include_year_fe logical
build_formula <- function(dv,
                          init_vars,
                          controls,
                          mundlak_terms = character(0),
                          include_year_fe = TRUE) {
  rhs <- c(init_vars, controls, mundlak_terms)
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
#' @param controls main control variables
#' @param mundlak_terms Mundlak term names
#' @param include_year_fe include year FE
#' @return glmmTMB object
fit_zinb <- function(df, dv, init_vars, controls, mundlak_terms = character(0),
                     include_year_fe = TRUE) {
  fml <- build_formula(dv, init_vars, controls, mundlak_terms, include_year_fe)
  glmmTMB::glmmTMB(
    formula = fml,
    ziformula = ~ 1,
    family = glmmTMB::nbinom2(),
    data = df,
    REML = FALSE
  )
}

#' Add significance stars to tidy output
#' @param df tidy output from broom/broom.mixed
#' @return df with 'stars' column
add_significance_stars <- function(df) {
  if (!"p.value" %in% names(df)) {
    df$stars <- ""
    return(df)
  }
  df$stars <- dplyr::case_when(
    df$p.value < 0.001 ~ "***",
    df$p.value < 0.01  ~ "**",
    df$p.value < 0.05  ~ "*",
    TRUE                ~ ""
  )
  df
}

#' Tidy and export model outputs (conditional and zero-inflation parts)
#' @param model glmmTMB fit
#' @param dv dependent variable name
#' @param model_tag short tag for filename
#' @param out_dir output directory
export_glmmTMB_results <- function(model, dv, model_tag, out_dir) {
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  
  # Generate timestamp for file naming
  timestamp <- format(Sys.time(), "%y%m%d_%H%M")
  
  # Conditional (exponentiate = IRR)
  cond <- broom.mixed::tidy(model, effects = "fixed", component = "cond", conf.int = TRUE, exponentiate = TRUE)
  cond <- add_significance_stars(cond)
  zi   <- broom.mixed::tidy(model, effects = "fixed", component = "zi",   conf.int = TRUE, exponentiate = TRUE)
  zi   <- add_significance_stars(zi)
  glance_df <- broom.mixed::glance(model)
  
  readr::write_csv(cond, file.path(out_dir, paste0("model_", dv, "_", model_tag, "_cond_", timestamp, ".csv")))
  readr::write_csv(zi,   file.path(out_dir, paste0("model_", dv, "_", model_tag, "_zi_", timestamp, ".csv")))
  readr::write_csv(glance_df, file.path(out_dir, paste0("model_", dv, "_", model_tag, "_glance_", timestamp, ".csv")))
}

#' Convenience runner for a DV
#' @param df modeling frame (include Mundlak means already)
#' @param dv dependent variable name
#' @param init_vars character vector of initial-condition variables
#' @param controls character vector of main control variables
#' @param mundlak_terms character vector of Mundlak term names
#' @param out_dir output dir
run_main_zinb_for_dv <- function(df, dv, init_vars, controls, mundlak_terms,
                                 out_dir = file.path(
                                   "/Users","suengj","Documents","Code","Python","Research","VC",
                                   "refactor_v2","notebooks","output")) {
  model <- fit_zinb(df, dv, init_vars, controls, mundlak_terms, include_year_fe = TRUE)
  # Create model tag from init_vars (extract p75/p0/p99 if present)
  init_set <- if (any(grepl("p75", init_vars))) "p75" else if (any(grepl("p0", init_vars))) "p0" else if (any(grepl("p99", init_vars))) "p99" else "unknown"
  export_glmmTMB_results(model, dv, paste0("zinb_", init_set), out_dir)
  model
}


