## models_robustness.R
## Robustness models: Poisson FE (firm FE + year FE) and NB without zero-inflation

# Auto-install missing packages
required_packages <- c("dplyr", "tidyr", "glmmTMB", "broom", "broom.mixed", "readr")
missing_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]
if(length(missing_packages) > 0) {
  message("Installing missing packages: ", paste(missing_packages, collapse = ", "))
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(glmmTMB)
  library(broom)
  library(broom.mixed)
  library(readr)
})

#' Fit Negative Binomial (no zero-inflation), random intercept for firm, year FE
#' Includes initial-condition variables (not absorbed)
#' @param df data frame
#' @param dv dependent variable
#' @param controls character vector of main control variables
#' @param init_vars optional character vector of initial-condition variables
#' @param include_year_fe logical
fit_nb_no_zi_re <- function(df, dv, controls, init_vars = NULL, include_year_fe = TRUE) {
  rhs <- c(controls, if (!is.null(init_vars)) init_vars else character(0))
  rhs <- rhs[!duplicated(rhs)]
  rhs_str <- paste(rhs, collapse = " + ")
  if (include_year_fe) rhs_str <- paste(rhs_str, "+ factor(year)")
  rhs_str <- paste(rhs_str, "+ (1|firmname)")
  fml <- stats::as.formula(paste0(dv, " ~ ", rhs_str))
  glmmTMB::glmmTMB(
    formula = fml,
    family = glmmTMB::nbinom2(),
    data = df,
    REML = FALSE
  )
}

#' Fit Poisson with firm FE + year FE via glm
#' Note: initial-condition variables (firm-level constants) are excluded to avoid FE absorption
#' @param df data frame
#' @param dv dependent variable
#' @param controls character vector of main control variables
#' @param include_year_fe logical
fit_poisson_fe <- function(df, dv, controls, include_year_fe = TRUE) {
  rhs <- controls
  rhs_str <- paste(rhs, collapse = " + ")
  if (include_year_fe) rhs_str <- paste(rhs_str, "+ factor(year)")
  # Firm FE
  rhs_str <- paste(rhs_str, "+ factor(firmname)")
  fml <- stats::as.formula(paste0(dv, " ~ ", rhs_str))
  stats::glm(fml, data = df, family = stats::poisson(link = "log"))
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

#' Export helper for glmmTMB NB model (no zi)
export_nb_results <- function(model, dv, tag, out_dir) {
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  
  # Generate timestamp for file naming
  timestamp <- format(Sys.time(), "%y%m%d_%H%M")
  
  cond <- broom.mixed::tidy(model, effects = "fixed", component = "cond", conf.int = TRUE, exponentiate = TRUE)
  cond <- add_significance_stars(cond)
  glance_df <- broom.mixed::glance(model)
  readr::write_csv(cond, file.path(out_dir, paste0("robust_", dv, "_", tag, "_cond_", timestamp, ".csv")))
  readr::write_csv(glance_df, file.path(out_dir, paste0("robust_", dv, "_", tag, "_glance_", timestamp, ".csv")))
}

#' Export helper for glm Poisson FE model
export_poisson_results <- function(model, dv, tag, out_dir) {
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  
  # Generate timestamp for file naming
  timestamp <- format(Sys.time(), "%y%m%d_%H%M")
  
  td <- broom::tidy(model, conf.int = TRUE, exponentiate = TRUE)
  td <- add_significance_stars(td)
  gl <- broom::glance(model)
  readr::write_csv(td, file.path(out_dir, paste0("robust_", dv, "_", tag, "_coef_", timestamp, ".csv")))
  readr::write_csv(gl, file.path(out_dir, paste0("robust_", dv, "_", tag, "_glance_", timestamp, ".csv")))
}

#' Runner to execute robustness models for one DV
#' @param df modeling frame
#' @param dv dependent variable
#' @param controls character vector of main control variables
#' @param init_vars optional initial-condition variable vector for NB-RE
#' @param out_dir output directory
run_robustness_for_dv <- function(df, dv, controls, init_vars = NULL,
                                  out_dir = file.path(
                                    "/Users","suengj","Documents","Code","Python","Research","VC",
                                    "refactor_v2","notebooks","output")) {
  # NB without zero-inflation (RE + year FE)
  nbm <- fit_nb_no_zi_re(df, dv, controls, init_vars = init_vars, include_year_fe = TRUE)
  export_nb_results(nbm, dv, "nb_nozi_re", out_dir)
  
  # Poisson FE (firm FE + year FE)
  pm <- fit_poisson_fe(df, dv, controls, include_year_fe = TRUE)
  export_poisson_results(pm, dv, "poisson_fe", out_dir)
  
  list(nb_nozi_re = nbm, poisson_fe = pm)
}


