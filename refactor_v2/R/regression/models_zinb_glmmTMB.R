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
#' @param interaction_terms character vector of interaction terms (e.g., "var1:var2")
#' @param year_fe_type character: "none", "year", or "decade"
build_formula <- function(dv,
                          init_vars,
                          controls,
                          mundlak_terms = character(0),
                          interaction_terms = character(0),
                          year_fe_type = "none") {
  rhs <- c(init_vars, controls, mundlak_terms, interaction_terms)
  rhs <- rhs[!duplicated(rhs)]
  rhs_str <- paste(rhs, collapse = " + ")
  
  # Add year fixed effects based on type
  if (year_fe_type == "year") {
    rhs_str <- paste(rhs_str, "+ factor(year)")
  } else if (year_fe_type == "decade") {
    rhs_str <- paste(rhs_str, "+ factor(decade)")
  }
  # else: year_fe_type == "none", no year FE added
  
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
#' @param interaction_terms interaction terms (e.g., "var1:var2")
#' @param year_fe_type character: "none", "year", or "decade"
#' @return glmmTMB object
fit_zinb <- function(df, dv, init_vars, controls, mundlak_terms = character(0),
                     interaction_terms = character(0),
                     year_fe_type = "none") {
  fml <- build_formula(dv, init_vars, controls, mundlak_terms, interaction_terms, year_fe_type)
  
  # Check for perfect collinearity before fitting (simple check on numeric variables)
  all_vars <- c(init_vars, controls, mundlak_terms)
  all_vars <- all_vars[all_vars %in% names(df)]
  if (length(all_vars) > 1) {
    # Extract only numeric variables for collinearity check
    numeric_vars <- all_vars[sapply(df[, all_vars, drop = FALSE], is.numeric)]
    if (length(numeric_vars) > 1) {
      # Create simple design matrix (complete cases only)
      df_check <- df[complete.cases(df[, numeric_vars, drop = FALSE]), numeric_vars, drop = FALSE]
      if (nrow(df_check) > length(numeric_vars)) {
        X <- as.matrix(df_check)
        # Check for perfect collinearity (rank deficiency)
        X_rank <- qr(X)$rank
        if (X_rank < ncol(X)) {
          warning(sprintf("Perfect collinearity detected among numeric variables: rank = %d < ncol = %d. Some variables may be dropped.", 
                          X_rank, ncol(X)))
        }
      }
    }
  }
  
  # Fit with improved convergence options
  glmmTMB::glmmTMB(
    formula = fml,
    ziformula = ~ 1,
    family = glmmTMB::nbinom2(),
    data = df,
    REML = FALSE,
    control = glmmTMB::glmmTMBControl(
      optimizer = "nlminb",  # More stable optimizer
      optCtrl = list(iter.max = 1000, eval.max = 1000)  # More iterations
    )
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
#' @param interaction_terms character vector of interaction terms (e.g., "var1:var2")
#' @param year_fe_type character: "none", "year", or "decade"
#' @param out_dir output dir
run_main_zinb_for_dv <- function(df, dv, init_vars, controls, mundlak_terms,
                                 interaction_terms = character(0),
                                 out_dir = file.path(
                                   "/Users","suengj","Documents","Code","Python","Research","VC",
                                   "refactor_v2","notebooks","output"),
                                 year_fe_type = "none") {
  # Check which variables are actually in the data before fitting
  all_vars_requested <- c(init_vars, controls, mundlak_terms)
  vars_missing <- setdiff(all_vars_requested, names(df))
  if (length(vars_missing) > 0) {
    warning(sprintf("Variables requested but missing from data (%d): %s", 
                    length(vars_missing), paste(vars_missing, collapse=", ")))
  }
  
  model <- fit_zinb(df, dv, init_vars, controls, mundlak_terms, interaction_terms, year_fe_type = year_fe_type)
  
  # Check which variables are actually in the fitted model
  cond_tidy <- broom.mixed::tidy(model, effects = "fixed", component = "cond")
  # Exclude intercept and year/decade FE terms
  fe_terms <- c(grep("^factor\\(year\\)", cond_tidy$term, value=TRUE),
                grep("^factor\\(decade\\)", cond_tidy$term, value=TRUE))
  vars_in_model <- cond_tidy$term[!cond_tidy$term %in% c("(Intercept)", fe_terms)]
  vars_requested_but_missing <- setdiff(all_vars_requested, vars_in_model)
  if (length(vars_requested_but_missing) > 0) {
    message(sprintf("⚠️  Variables requested but NOT in fitted model (%d): %s", 
                    length(vars_requested_but_missing), paste(vars_requested_but_missing, collapse=", ")))
    message("     This may be due to: complete separation, perfect collinearity, or all-NA values")
  }
  
  # Create model tag from init_vars (extract p75/p0/p99 if present)
  init_set <- if (any(grepl("p75", init_vars))) "p75" else if (any(grepl("p0", init_vars))) "p0" else if (any(grepl("p99", init_vars))) "p99" else "unknown"
  export_glmmTMB_results(model, dv, paste0("zinb_", init_set), out_dir)
  model
}


