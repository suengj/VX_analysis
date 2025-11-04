# Regression Analysis Functions
# Common regression functions for VC network analysis
# Based on patterns from imprinting_Dec18.R and CVC_analysis.R

# Load required packages
if (!require('tidyverse')) install.packages('tidyverse'); library('tidyverse')
if (!require('plm')) install.packages('plm'); library('plm')
if (!require('pglm')) install.packages('pglm'); library('pglm')
if (!require('lme4')) install.packages('lme4'); library('lme4')
if (!require('car')) install.packages('car'); library('car')

#' Create panel data frame for analysis
#' @param data Input data
#' @param index_vars Index variables for panel
#' @return Panel data frame
create_panel_data <- function(data, index_vars = c("firmname", "year")) {
  
  # Ensure data is properly sorted and has sufficient time series
  panel_data <- data %>%
    arrange(firmname, year) %>%
    group_by(firmname) %>%
    filter(n() >= 2) %>%  # At least 2 observations per firm for lag
    ungroup() %>%
    drop_na(initial_year)
  
  # Convert to panel data frame
  panel_data <- pdata.frame(panel_data, index = index_vars)
  
  return(panel_data)
}

#' Run imprinting effect regression models
#' Based on imprinting_Dec18.R models
#' @param panel_data Panel data
#' @param model_type "H0", "H1", or "H2"
#' @return Regression model
run_imprinting_regression <- function(panel_data, model_type = "H0") {
  
  if (model_type == "H0") {
    # Base model (simplified to avoid lag issues)
    model <- glm(exitNum ~ 
                   timesince + 
                   blau + log(InvestAMT + 1) + earlyStage + # other (t)
                   CAMA + # factor (removed initial_year to avoid factor level issues)
                   log(p_dgr_cent + 1) + p_pwr_max + p_constraint_value + # partner network (t)
                   
                   log(initial_partner_num + 1) + f_ego_density, # focal level
                 
                 data = panel_data,
                 family = poisson)
  }
  
  if (model_type == "H1") {
    # Hypothesis 1: Partner power centrality effect (simplified)
    model <- glm(exitNum ~ 
                   timesince + 
                   blau + log(InvestAMT + 1) + earlyStage + # other (t)
                   CAMA + # factor (removed initial_year to avoid factor level issues)
                   log(p_dgr_cent + 1) + p_pwr_max + p_constraint_value + # partner network (t)
                   
                   log(initial_partner_num + 1) + f_ego_density + # focal level
                   p_pwr_max, # hypothesis (partner power centrality)
                 
                 data = panel_data,
                 family = poisson)
  }
  
  if (model_type == "H2") {
    # Hypothesis 2: Interaction effect (simplified)
    model <- glm(exitNum ~ 
                   timesince + 
                   blau + log(InvestAMT + 1) + earlyStage + # other (t)
                   CAMA + # factor (removed initial_year to avoid factor level issues)
                   log(p_dgr_cent + 1) + p_pwr_max + p_constraint_value + # partner network (t)
                   
                   log(initial_partner_num + 1) + f_ego_density + # focal level
                   p_pwr_max * p_constraint_value, # hypothesis (partner power * constraint interaction)
                 
                 data = panel_data,
                 family = poisson)
  }
  
  return(model)
}

#' Run CVC partnership regression models
#' Based on CVC_analysis.R patterns
#' @param data Input data
#' @param dependent_var Dependent variable
#' @param model_type Model specification
#' @return Regression model
run_cvc_regression <- function(data, dependent_var = "realized", model_type = "base") {
  
  if (model_type == "base") {
    # Base model for CVC partnerships
    model <- glm(as.formula(paste(dependent_var, "~ factor(year) + log(nt_size_sum+1)")),
                 data = data,
                 family = binomial)
  }
  
  if (model_type == "network") {
    # Network effects model
    model <- glm(as.formula(paste(dependent_var, "~ factor(year) + log(nt_size_sum+1) + 
                                  both_prv*bp_d2_0")),
                 data = data,
                 family = binomial)
  }
  
  if (model_type == "cvc") {
    # CVC specific model
    model <- glm(as.formula(paste(dependent_var, "~ factor(year) + log(nt_size_sum+1) + 
                                  both_cvc*bp_d2_0")),
                 data = data,
                 family = binomial)
  }
  
  return(model)
}

#' Calculate VIF for model diagnostics
#' @param model Regression model
#' @return VIF values
calculate_vif <- function(model) {
  
  vif_values <- car::vif(model)
  return(vif_values)
}

#' Run multiple regression models and compare
#' @param data Input data
#' @param model_specs List of model specifications
#' @return List of models and summaries
run_model_comparison <- function(data, model_specs) {
  
  models <- list()
  summaries <- list()
  
  for (i in seq_along(model_specs)) {
    spec <- model_specs[[i]]
    
    if (spec$type == "imprinting") {
      models[[i]] <- run_imprinting_regression(data, spec$hypothesis)
    } else if (spec$type == "cvc") {
      models[[i]] <- run_cvc_regression(data, spec$dependent_var, spec$model_type)
    }
    
    summaries[[i]] <- summary(models[[i]])
  }
  
  return(list(models = models, summaries = summaries))
}

#' Extract model results for reporting
#' @param model Regression model
#' @return Formatted results
extract_model_results <- function(model) {
  
  # Extract coefficients and standard errors
  coef_summary <- summary(model)$coefficients
  
  # Create results data frame
  results <- data.frame(
    variable = rownames(coef_summary),
    coefficient = coef_summary[, 1],
    std_error = coef_summary[, 2],
    z_value = coef_summary[, 3],
    p_value = coef_summary[, 4],
    significance = ifelse(coef_summary[, 4] < 0.001, "***",
                         ifelse(coef_summary[, 4] < 0.01, "**",
                                ifelse(coef_summary[, 4] < 0.05, "*", "")))
  )
  
  return(results)
}

#' Create regression formula from variable list
#' @param dependent_var Dependent variable
#' @param independent_vars Vector of independent variables
#' @param interaction_vars List of interaction terms
#' @return Formula object
create_regression_formula <- function(dependent_var, independent_vars, interaction_vars = NULL) {
  
  # Create base formula
  formula_str <- paste(dependent_var, "~", paste(independent_vars, collapse = " + "))
  
  # Add interaction terms if specified
  if (!is.null(interaction_vars)) {
    for (interaction in interaction_vars) {
      formula_str <- paste(formula_str, "+", interaction)
    }
  }
  
  return(as.formula(formula_str))
}

#' Run robustness checks
#' @param data Input data
#' @param base_model Base model specification
#' @param robustness_specs List of robustness specifications
#' @return Robustness check results
run_robustness_checks <- function(data, base_model, robustness_specs) {
  
  robustness_results <- list()
  
  for (i in seq_along(robustness_specs)) {
    spec <- robustness_specs[[i]]
    
    if (spec$type == "subsample") {
      # Subsample analysis
      subsample_data <- data %>% filter(!!spec$condition)
      robustness_results[[paste0("subsample_", i)]] <- 
        run_imprinting_regression(subsample_data, spec$model_type)
    }
    
    if (spec$type == "alternative_spec") {
      # Alternative specification
      robustness_results[[paste0("alternative_", i)]] <- 
        run_imprinting_regression(data, spec$model_type)
    }
  }
  
  return(robustness_results)
}
 