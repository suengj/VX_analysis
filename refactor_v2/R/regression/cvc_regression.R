# CVC Partnership Regression Analysis
#
# This script performs conditional logistic regression (clogit) analysis
# for CVC partnership decisions.

library(survival)  # for clogit
library(dplyr)
library(tidyr)
library(broom)

source("data_loader.R")
source("diagnostics.R")


#' Run CVC Conditional Logistic Regression
#'
#' @param df Data frame with CVC analysis data
#' @param formula Model formula
#' @param strata_var Strata variable (default: quarter)
#' @return clogit model object
run_cvc_clogit <- function(df, formula, strata_var = "quarter") {
  
  cat("\n========== Running Conditional Logistic Regression ==========\n\n")
  cat("Formula:", deparse(formula), "\n")
  cat("Strata:", strata_var, "\n")
  cat("N observations:", nrow(df), "\n\n")
  
  # Create strata
  df$strata_id <- interaction(df[[strata_var]], df$leadVC, df$comname)
  
  # Run clogit
  model <- clogit(formula, data = df, method = "exact")
  
  # Print summary
  print(summary(model))
  
  return(model)
}


#' Run Full CVC Analysis
#'
#' Runs multiple model specifications:
#' - H0: Base model (controls only)
#' - H1: Network centrality effects
#' - H2: Distance effects
#' - H3: Performance effects
#' - Full: All variables
#'
#' @param df CVC data
#' @return list of models
run_full_cvc_analysis <- function(df) {
  
  models <- list()
  
  # H0: Base model (controls only)
  cat("\n========== Model H0: Base (Controls Only) ==========\n")
  formula_h0 <- realized ~ coVC_age + coVC_totalInv + 
                           leadVC_dgr + strata(strata_id)
  models$h0 <- run_cvc_clogit(df, formula_h0)
  
  # H1: Network centrality
  cat("\n========== Model H1: Network Centrality ==========\n")
  formula_h1 <- realized ~ coVC_dgr + coVC_btw + coVC_pwr_p75 +
                           coVC_age + coVC_totalInv + 
                           leadVC_dgr + strata(strata_id)
  models$h1 <- run_cvc_clogit(df, formula_h1)
  
  # H2: Distance effects
  cat("\n========== Model H2: Distance Effects ==========\n")
  formula_h2 <- realized ~ geoDist1 + geoDist2 + geoDist3 +
                           indDist + geo_distance +
                           coVC_age + coVC_totalInv + 
                           leadVC_dgr + strata(strata_id)
  models$h2 <- run_cvc_clogit(df, formula_h2)
  
  # H3: Performance effects
  cat("\n========== Model H3: Performance Effects ==========\n")
  formula_h3 <- realized ~ coVC_exitNum + coVC_AmtInv +
                           coVC_age + coVC_totalInv + 
                           leadVC_dgr + strata(strata_id)
  models$h3 <- run_cvc_clogit(df, formula_h3)
  
  # Full model
  cat("\n========== Full Model: All Variables ==========\n")
  formula_full <- realized ~ coVC_dgr + coVC_btw + coVC_pwr_p75 +
                             geoDist1 + geoDist2 + geoDist3 +
                             indDist + geo_distance +
                             coVC_exitNum + coVC_AmtInv +
                             coVC_age + coVC_totalInv + 
                             leadVC_dgr + strata(strata_id)
  models$full <- run_cvc_clogit(df, formula_full)
  
  return(models)
}


#' Extract and Compare Model Results
#'
#' @param models List of model objects
#' @return tibble with model comparison
compare_models <- function(models) {
  
  results <- lapply(names(models), function(name) {
    model <- models[[name]]
    
    tibble(
      model = name,
      n_obs = model$n,
      n_events = model$nevent,
      log_likelihood = model$loglik[2],
      AIC = AIC(model),
      BIC = BIC(model),
      concordance = model$concordance[1]
    )
  }) %>%
    bind_rows()
  
  cat("\n========== Model Comparison ==========\n\n")
  print(results)
  
  return(results)
}


#' Save Model Results
#'
#' @param models List of models
#' @param output_dir Output directory
save_cvc_results <- function(models, output_dir = "results") {
  
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  
  # Save individual model results
  for (name in names(models)) {
    model <- models[[name]]
    
    # Extract coefficients
    coef_df <- tidy(model)
    
    # Save to CSV
    output_file <- file.path(output_dir, paste0("cvc_", name, "_results.csv"))
    write.csv(coef_df, output_file, row.names = FALSE)
    
    cat("Saved:", output_file, "\n")
  }
  
  # Save model comparison
  comparison <- compare_models(models)
  output_file <- file.path(output_dir, "cvc_model_comparison.csv")
  write.csv(comparison, output_file, row.names = FALSE)
  
  cat("Saved:", output_file, "\n")
}


# Example usage:
# cvc_data <- load_cvc_data()
# models <- run_full_cvc_analysis(cvc_data)
# check_vif(models$full)
# save_cvc_results(models)

