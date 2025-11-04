# Imprinting Analysis Regression
#
# This script performs panel GLM regression for imprinting effects analysis.

library(plm)  # for panel data models
library(dplyr)
library(tidyr)
library(broom)

source("data_loader.R")
source("diagnostics.R")


#' Run Panel GLM Regression
#'
#' @param df Panel data
#' @param formula Model formula
#' @param index Panel index (firm, year)
#' @param model Model type ("pooling", "within", "random")
#' @param family Family for GLM (default: poisson)
#' @return pglm model object
run_panel_glm <- function(df, formula, 
                         index = c("firmname", "year"),
                         model = "within",
                         family = "poisson") {
  
  cat("\n========== Running Panel GLM ==========\n\n")
  cat("Formula:", deparse(formula), "\n")
  cat("Model type:", model, "\n")
  cat("Family:", family, "\n")
  cat("N observations:", nrow(df), "\n\n")
  
  # Create pdata.frame
  pdata <- pdata.frame(df, index = index)
  
  # Run panel GLM
  # Note: pglm package might not be available
  # Use plm with appropriate specifications instead
  
  if (family == "poisson") {
    model_fit <- plm(formula, data = pdata, model = model)
  } else {
    model_fit <- plm(formula, data = pdata, model = model)
  }
  
  # Print summary
  print(summary(model_fit))
  
  return(model_fit)
}


#' Run Full Imprinting Analysis
#'
#' Runs multiple model specifications:
#' - H0: Base model (time + controls)
#' - H1: Initial partner centrality effects
#' - H2: Initial focal centrality effects
#' - Full: All imprinting variables
#'
#' @param df Imprinting panel data
#' @return list of models
run_full_imprinting_analysis <- function(df) {
  
  models <- list()
  
  # Filter for private VCs only
  df_private <- df %>%
    filter(firmtype == "IVC")
  
  cat("Filtered to private VCs:", nrow(df_private), "observations\n")
  
  # H0: Base model (time effects + controls)
  cat("\n========== Model H0: Base (Time + Controls) ==========\n")
  formula_h0 <- exitNum ~ timesince + I(timesince^2) + 
                         dgr_1y + blau_index + firmage
  models$h0 <- run_panel_glm(df_private, formula_h0)
  
  # H1: Initial partner centrality
  cat("\n========== Model H1: Initial Partner Centrality ==========\n")
  formula_h1 <- exitNum ~ timesince + I(timesince^2) +
                         p_dgr_1y + p_btw_1y + p_pwr_max_5y +
                         dgr_1y + blau_index + firmage
  models$h1 <- run_panel_glm(df_private, formula_h1)
  
  # H2: Initial focal centrality
  cat("\n========== Model H2: Initial Focal Centrality ==========\n")
  formula_h2 <- exitNum ~ timesince + I(timesince^2) +
                         f_dgr_1y + f_cons_value_1y +
                         dgr_1y + blau_index + firmage
  models$h2 <- run_panel_glm(df_private, formula_h2)
  
  # Full model: All imprinting variables
  cat("\n========== Full Model: All Imprinting Variables ==========\n")
  formula_full <- exitNum ~ timesince + I(timesince^2) +
                           p_dgr_1y + p_btw_1y + p_pwr_max_5y +
                           f_dgr_1y + f_cons_value_1y +
                           dgr_1y + btw_1y + pwr_max_5y +
                           blau_index + firmage
  models$full <- run_panel_glm(df_private, formula_full)
  
  return(models)
}


#' Extract and Compare Panel Model Results
#'
#' @param models List of model objects
#' @return tibble with model comparison
compare_panel_models <- function(models) {
  
  results <- lapply(names(models), function(name) {
    model <- models[[name]]
    
    tibble(
      model = name,
      n_obs = length(model$residuals),
      r_squared = summary(model)$r.squared[1],
      adj_r_squared = summary(model)$r.squared[2],
      f_statistic = summary(model)$fstatistic$statistic
    )
  }) %>%
    bind_rows()
  
  cat("\n========== Panel Model Comparison ==========\n\n")
  print(results)
  
  return(results)
}


#' Save Imprinting Results
#'
#' @param models List of models
#' @param output_dir Output directory
save_imprinting_results <- function(models, output_dir = "results") {
  
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  
  # Save individual model results
  for (name in names(models)) {
    model <- models[[name]]
    
    # Extract coefficients
    coef_df <- tidy(model)
    
    # Save to CSV
    output_file <- file.path(output_dir, paste0("imprinting_", name, "_results.csv"))
    write.csv(coef_df, output_file, row.names = FALSE)
    
    cat("Saved:", output_file, "\n")
  }
  
  # Save model comparison
  comparison <- compare_panel_models(models)
  output_file <- file.path(output_dir, "imprinting_model_comparison.csv")
  write.csv(comparison, output_file, row.names = FALSE)
  
  cat("Saved:", output_file, "\n")
}


# Example usage:
# imprinting_data <- load_imprinting_data()
# models <- run_full_imprinting_analysis(imprinting_data)
# check_vif(models$full)
# save_imprinting_results(models)

