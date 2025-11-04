# VC Network Analysis - Complete Module Loader
# Loads all refactored modules in the correct order

#' Load all VC network analysis modules
#' @param config_path Path to config directory
#' @param core_path Path to core modules directory
#' @param analysis_path Path to analysis modules directory
#' @param utils_path Path to utils directory
#' @return List of loaded modules
load_vc_modules <- function(config_path = NULL,
                           core_path = NULL, 
                           analysis_path = NULL,
                           utils_path = NULL) {
  
  # Set default paths to absolute paths
  if (is.null(config_path)) {
    config_path <- "/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/config"
  }
  if (is.null(core_path)) {
    core_path <- "/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/core"
  }
  if (is.null(analysis_path)) {
    analysis_path <- "/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/analysis"
  }
  if (is.null(utils_path)) {
    utils_path <- "/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/utils"
  }
  
  cat("Loading VC Network Analysis Modules...\n")
  
  # Load configuration files first
  cat("Loading configuration files...\n")
  source(file.path(config_path, "parameters.R"))
  source(file.path(config_path, "constants.R"))
  source(file.path(config_path, "paths.R"))
  
  # Load utility functions
  cat("Loading utility functions...\n")
  source(file.path(utils_path, "validation.R"))
  
  # Load core modules
  cat("Loading core modules...\n")
  source(file.path(core_path, "network_construction.R"))
  source(file.path(core_path, "centrality_calculation.R"))
  source(file.path(core_path, "sampling.R"))
  source(file.path(core_path, "data_processing.R"))
  
  # Load analysis modules
  cat("Loading analysis modules...\n")
  source(file.path(analysis_path, "diversity_analysis.R"))
  source(file.path(analysis_path, "imprinting_analysis.R"))
  source(file.path(analysis_path, "performance_analysis.R"))
  source(file.path(analysis_path, "regression_analysis.R"))
  
  cat("All modules loaded successfully!\n")
  
  # Return list of available functions
  return(list(
    config = c("NETWORK_PARAMS", "SAMPLING_PARAMS", "ANALYSIS_PARAMS", 
               "DATA_FILTERS", "PARALLEL_PARAMS", "OUTPUT_PARAMS",
               "REQUIRED_COLUMNS", "INDUSTRY_CODES", "VC_TYPES", 
               "EXIT_TYPES", "GEOGRAPHIC_CONSTANTS", "NETWORK_CONSTANTS",
               "BASE_PATHS", "IMPRINTING_PATHS", "SUB_DIRS", "FILE_PATTERNS"),

    core_functions = c("VC_matrix", "create_bipartite_network", "project_network",
                      "VC_centralities", "calculate_power_centrality", 
                      "calculate_ego_density", "calculate_constraint",
                      "VC_sampling_opt1", "VC_sampling_opt1_output", 
                      "create_case_control_dataset",
                      "date_unique_identifier", "leadVC_identifier",
                      "create_event_identifiers", "filter_investment_data",
                      "calculate_investment_stats"),

    analysis_functions = c("blau_index", "calculate_industry_proportion",
                          "calculate_portfolio_diversity", "calculate_geographic_diversity",
                          "calculate_stage_diversity",
                          "VC_initial_ties", "VC_initial_period", "VC_initial_focal_centrality",
                          "VC_initial_partner_centrality", "VC_initial_centrality",
                          "create_imprinting_dataset", "calculate_imprinting_effects",
                          "VC_exit_num", "VC_IPO_num", "VC_MnA_num",
                          "calculate_exit_percentages", "create_exit_data",
                          "calculate_performance_metrics", "welch_t_test",
                          "calculate_performance_summary",
                          "create_panel_data", "run_imprinting_regression",
                          "run_cvc_regression", "calculate_vif", "run_model_comparison",
                          "extract_model_results", "create_regression_formula",
                          "run_robustness_checks"),
                          
    utility_functions = c("validate_network_params", "validate_centrality_params",
                         "check_data_completeness", "validate_sampling_params")
  ))
}

#' Quick setup for common analysis
#' @param data_path Path to data directory
#' @return Setup confirmation
quick_setup <- function(data_path = NULL) {
  
  # Load all modules
  modules <- load_vc_modules()
  
  # Set working directory if data_path provided
  if (!is.null(data_path)) {
    if (dir.exists(data_path)) {
      setwd(data_path)
      cat("Working directory set to:", data_path, "\n")
    } else {
      warning("Data path does not exist:", data_path)
    }
  }
  
  # Load required packages
  required_packages <- c("igraph", "data.table", "tidyverse", "progress", "parallel", "foreach", "doParallel",
                        "plm", "lme4", "car", "readxl", "tictoc", "benchmarkme")
  
  cat("Checking required packages...\n")
  for (pkg in required_packages) {
    if (!require(pkg, character.only = TRUE)) {
      cat("Installing package:", pkg, "\n")
      install.packages(pkg)
      library(pkg, character.only = TRUE)
    }
  }
  
  # Handle pglm package separately (may not be available on CRAN)
  if (!require("pglm", character.only = TRUE)) {
    cat("Attempting to install pglm package...\n")
    tryCatch({
      install.packages("pglm")
      library("pglm", character.only = TRUE)
    }, error = function(e) {
      cat("Warning: pglm package not available. Some regression functions may not work.\n")
      cat("Consider using alternative packages like 'plm' or 'lme4'.\n")
    })
  }
  
  cat("Quick setup completed!\n")
  cat("Available functions:\n")
  cat("- Core functions:", length(modules$core_functions), "\n")
  cat("- Analysis functions:", length(modules$analysis_functions), "\n")
  cat("- Utility functions:", length(modules$utility_functions), "\n")
  
  return(modules)
}

#' Load specific module group
#' @param module_group "config", "core", "analysis", "utils", or "all"
#' @return Loaded modules
load_module_group <- function(module_group = "all") {
  
  if (module_group == "all") {
    return(load_vc_modules())
  }
  
  if (module_group == "config") {
    source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/config/parameters.R")
    source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/config/constants.R")
    source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/config/paths.R")
    cat("Configuration modules loaded.\n")
  }
  
  if (module_group == "core") {
    source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/core/network_construction.R")
    source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/core/centrality_calculation.R")
    source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/core/sampling.R")
    source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/core/data_processing.R")
    cat("Core modules loaded.\n")
  }
  
  if (module_group == "analysis") {
    source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/analysis/diversity_analysis.R")
    source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/analysis/imprinting_analysis.R")
    source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/analysis/performance_analysis.R")
    source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/analysis/regression_analysis.R")
    cat("Analysis modules loaded.\n")
  }
  
  if (module_group == "utils") {
    source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/utils/validation.R")
    cat("Utility modules loaded.\n")
  }
}

#' Load specific analysis module
#' @param analysis_type "diversity", "imprinting", "performance", "regression", or "all"
#' @return Loaded analysis modules
load_analysis_module <- function(analysis_type = "all") {
  
  if (analysis_type == "all") {
    source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/analysis/diversity_analysis.R")
    source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/analysis/imprinting_analysis.R")
    source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/analysis/performance_analysis.R")
    source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/analysis/regression_analysis.R")
    cat("All analysis modules loaded.\n")
  }
  
  if (analysis_type == "diversity") {
    source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/analysis/diversity_analysis.R")
    cat("Diversity analysis module loaded.\n")
  }
  
  if (analysis_type == "imprinting") {
    source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/analysis/imprinting_analysis.R")
    cat("Imprinting analysis module loaded.\n")
  }
  
  if (analysis_type == "performance") {
    source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/analysis/performance_analysis.R")
    cat("Performance analysis module loaded.\n")
  }
  
  if (analysis_type == "regression") {
    source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/analysis/regression_analysis.R")
    cat("Regression analysis module loaded.\n")
  }
}

# Auto-load when sourced
if (interactive()) {
  cat("VC Network Analysis modules ready for use.\n")
  cat("Use load_vc_modules() to load all modules.\n")
  cat("Use quick_setup() for complete setup.\n")
  cat("Use load_module_group() to load specific modules.\n")
  cat("Use load_analysis_module() to load specific analysis modules.\n")
} 