## models_robustness.R
## Robustness models: Poisson FE (firm FE + year FE) and NB without zero-inflation

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(glmmTMB)
  library(broom)
  library(broom.mixed)
  library(readr)
})

# Shared: controls and time-varying set
.controls_vec <- c("years_since_init","after7","firmage_log",
                   "early_stage_ratio","industry_blau","inv_amt_log","dgr_cent")

#' Fit Negative Binomial (no zero-inflation), random intercept for firm, year FE
#' Includes initial-condition variables (not absorbed)
fit_nb_no_zi_re <- function(df, dv, include_year_fe = TRUE, init_vars = NULL) {
  rhs <- c(.controls_vec, if (!is.null(init_vars)) init_vars else character(0))
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
fit_poisson_fe <- function(df, dv, include_year_fe = TRUE) {
  rhs <- .controls_vec
  rhs_str <- paste(rhs, collapse = " + ")
  if (include_year_fe) rhs_str <- paste(rhs_str, "+ factor(year)")
  # Firm FE
  rhs_str <- paste(rhs_str, "+ factor(firmname)")
  fml <- stats::as.formula(paste0(dv, " ~ ", rhs_str))
  stats::glm(fml, data = df, family = stats::poisson(link = "log"))
}

#' Export helper for glmmTMB NB model (no zi)
export_nb_results <- function(model, dv, tag, out_dir) {
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  cond <- broom.mixed::tidy(model, effects = "fixed", component = "cond", conf.int = TRUE, exponentiate = TRUE)
  glance_df <- broom.mixed::glance(model)
  readr::write_csv(cond, file.path(out_dir, paste0("robust_", dv, "_", tag, "_cond.csv")))
  readr::write_csv(glance_df, file.path(out_dir, paste0("robust_", dv, "_", tag, "_glance.csv")))
}

#' Export helper for glm Poisson FE model
export_poisson_results <- function(model, dv, tag, out_dir) {
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  td <- broom::tidy(model, conf.int = TRUE, exponentiate = TRUE)
  gl <- broom::glance(model)
  readr::write_csv(td, file.path(out_dir, paste0("robust_", dv, "_", tag, "_coef.csv")))
  readr::write_csv(gl, file.path(out_dir, paste0("robust_", dv, "_", tag, "_glance.csv")))
}

#' Runner to execute robustness models for one DV
#' @param df modeling frame
#' @param dv dependent variable
#' @param init_vars optional initial-condition variable vector for NB-RE
#' @param out_dir output directory
run_robustness_for_dv <- function(df, dv,
                                  init_vars = NULL,
                                  out_dir = file.path(
                                    "/Users","suengj","Documents","Code","Python","Research","VC",
                                    "refactor_v2","notebooks","analysis_outputs")) {
  # NB without zero-inflation (RE + year FE)
  nbm <- fit_nb_no_zi_re(df, dv, include_year_fe = TRUE, init_vars = init_vars)
  export_nb_results(nbm, dv, "nb_nozi_re", out_dir)
  
  # Poisson FE (firm FE + year FE)
  pm <- fit_poisson_fe(df, dv, include_year_fe = TRUE)
  export_poisson_results(pm, dv, "poisson_fe", out_dir)
  
  list(nb_nozi_re = nbm, poisson_fe = pm)
}


