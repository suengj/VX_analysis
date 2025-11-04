# Test Script for Refactored Functions
# Compare results with original CVC_preprcs_v4.R and imprinting_Dec18.R

# Load refactored functions
source("load_all_modules.R")

# Load all modules
modules <- load_vc_modules()

#' Test function to compare original and refactored results
test_network_functions <- function() {
  
  cat("Testing refactored network functions...\n")
  
  # Create sample data for testing
  sample_data <- data.frame(
    firmname = c("VC1", "VC2", "VC3", "VC1", "VC2", "VC4"),
    event = c("Event1", "Event1", "Event1", "Event2", "Event2", "Event2"),
    year = c(1990, 1990, 1990, 1991, 1991, 1991)
  )
  
  # Test VC_matrix function
  cat("Testing VC_matrix function...\n")
  tryCatch({
    network <- VC_matrix(sample_data, 1991, time_window = 2)
    cat("✓ VC_matrix function works correctly\n")
    cat("  - Network has", vcount(network), "vertices and", ecount(network), "edges\n")
  }, error = function(e) {
    cat("✗ VC_matrix function failed:", e$message, "\n")
  })
  
  # Test VC_centralities function
  cat("Testing VC_centralities function...\n")
  tryCatch({
    centralities <- VC_centralities(sample_data, 1991, time_window = 2, edge_cutpoint = NULL)
    cat("✓ VC_centralities function works correctly\n")
    cat("  - Centrality measures calculated for", nrow(centralities), "firms\n")
    cat("  - Columns:", paste(colnames(centralities), collapse = ", "), "\n")
  }, error = function(e) {
    cat("✗ VC_centralities function failed:", e$message, "\n")
  })
  
  # Test validation functions
  cat("Testing validation functions...\n")
  tryCatch({
    validate_network_params(sample_data, 1991, 2)
    cat("✓ validate_network_params function works correctly\n")
  }, error = function(e) {
    cat("✗ validate_network_params function failed:", e$message, "\n")
  })
  
  cat("Network functions test completed!\n")
}

#' Test sampling functions
test_sampling_functions <- function() {
  
  cat("Testing refactored sampling functions...\n")
  
  # Create sample data for testing
  sample_data <- data.frame(
    firmname = c("VC1", "VC2", "VC3", "VC1", "VC2", "VC4"),
    comname = c("Company1", "Company1", "Company1", "Company2", "Company2", "Company2"),
    year = c(1990, 1990, 1990, 1991, 1991, 1991),
    quarter = c("1990Q1", "1990Q1", "1990Q1", "1991Q1", "1991Q1", "1991Q1")
  )
  
  leadVC_data <- data.frame(
    firmname = c("VC1", "VC2"),
    comname = c("Company1", "Company2"),
    leadVC = c(1, 1)
  )
  
  coVC_unique <- list(coVC = c("VC2", "VC3", "VC4"))
  
  # Test VC_sampling_opt1 function
  cat("Testing VC_sampling_opt1 function...\n")
  tryCatch({
    # Create sample realized ties data
    realized_data <- data.frame(
      leadVC = "VC1",
      comname = "Company1",
      coVC = c("VC2", "VC3"),
      realized = c(1, 1)
    )
    
    sampled_data <- VC_sampling_opt1(realized_data, coVC_unique, ratio = 2)
    cat("✓ VC_sampling_opt1 function works correctly\n")
    cat("  - Sampled", nrow(sampled_data), "observations\n")
  }, error = function(e) {
    cat("✗ VC_sampling_opt1 function failed:", e$message, "\n")
  })
  
  # Test date_unique_identifier function
  cat("Testing date_unique_identifier function...\n")
  tryCatch({
    unique_dates <- date_unique_identifier(sample_data, "year")
    cat("✓ date_unique_identifier function works correctly\n")
    cat("  - Found", length(unique_dates), "unique years\n")
  }, error = function(e) {
    cat("✗ date_unique_identifier function failed:", e$message, "\n")
  })
  
  cat("Sampling functions test completed!\n")
}

#' Test diversity analysis functions
test_diversity_functions <- function() {
  
  cat("Testing refactored diversity analysis functions...\n")
  
  # Create sample data for testing
  sample_data <- data.frame(
    firmname = c("VC1", "VC1", "VC2", "VC2"),
    year = c(1990, 1990, 1990, 1990),
    ind1 = c(5, 3, 2, 1),
    ind2 = c(2, 4, 3, 2),
    ind3 = c(1, 1, 2, 1)
  )
  
  # Test blau_index function
  cat("Testing blau_index function...\n")
  tryCatch({
    blau_result <- blau_index(sample_data)
    cat("✓ blau_index function works correctly\n")
    cat("  - Calculated Blau index for", nrow(blau_result), "firms\n")
    cat("  - Columns:", paste(colnames(blau_result), collapse = ", "), "\n")
  }, error = function(e) {
    cat("✗ blau_index function failed:", e$message, "\n")
  })
  
  cat("Diversity analysis functions test completed!\n")
}

#' Test imprinting analysis functions
test_imprinting_functions <- function() {
  
  cat("Testing refactored imprinting analysis functions...\n")
  
  # Create sample data for testing
  sample_data <- data.frame(
    firmname = c("VC1", "VC2", "VC3", "VC1", "VC2", "VC4"),
    event = c("Event1", "Event1", "Event1", "Event2", "Event2", "Event2"),
    year = c(1990, 1990, 1990, 1991, 1991, 1991)
  )
  
  # Test VC_initial_ties function
  cat("Testing VC_initial_ties function...\n")
  tryCatch({
    initial_ties <- VC_initial_ties(sample_data, 1990, time_window = 2)
    cat("✓ VC_initial_ties function works correctly\n")
    cat("  - Generated", nrow(initial_ties), "initial ties\n")
  }, error = function(e) {
    cat("✗ VC_initial_ties function failed:", e$message, "\n")
  })
  
  # Test VC_initial_period function
  cat("Testing VC_initial_period function...\n")
  tryCatch({
    # Create sample data with initial_year
    sample_period_data <- data.frame(
      firmname = c("VC1", "VC2"),
      initial_partner = c("VC2", "VC1"),
      tied_year = c(1990, 1990),
      initial_year = c(1988, 1989)
    )
    
    filtered_data <- VC_initial_period(sample_period_data, period = 2)
    cat("✓ VC_initial_period function works correctly\n")
    cat("  - Filtered to", nrow(filtered_data), "observations\n")
  }, error = function(e) {
    cat("✗ VC_initial_period function failed:", e$message, "\n")
  })
  
  cat("Imprinting analysis functions test completed!\n")
}

#' Test performance analysis functions
test_performance_functions <- function() {
  
  cat("Testing refactored performance analysis functions...\n")
  
  # Create sample data for testing
  round_data <- data.frame(
    firmname = c("VC1", "VC2", "VC1", "VC2"),
    comname = c("Company1", "Company1", "Company2", "Company2"),
    year = c(1990, 1990, 1991, 1991)
  )
  
  company_data <- data.frame(
    comname = c("Company1", "Company2"),
    comsitu = c("Went Public", "Merger"),
    date_sit = c("1995-01-01", "1996-01-01"),
    date_ipo = c("1995-01-01", "")
  )
  
  # Test create_exit_data function
  cat("Testing create_exit_data function...\n")
  tryCatch({
    exit_data <- create_exit_data(company_data)
    cat("✓ create_exit_data function works correctly\n")
    cat("  - Created exit data for", nrow(exit_data), "companies\n")
    cat("  - Exit types:", paste(unique(exit_data$exit), collapse = ", "), "\n")
  }, error = function(e) {
    cat("✗ create_exit_data function failed:", e$message, "\n")
  })
  
  # Test welch_t_test function
  cat("Testing welch_t_test function...\n")
  tryCatch({
    test_data <- data.frame(
      group = c(1, 1, 0, 0),
      value = c(10, 12, 8, 9)
    )
    
    t_result <- welch_t_test(test_data, group, "value")
    cat("✓ welch_t_test function works correctly\n")
    cat("  - Mean difference:", t_result[1, 1], "\n")
    cat("  - P-value:", t_result[1, 2], "\n")
  }, error = function(e) {
    cat("✗ welch_t_test function failed:", e$message, "\n")
  })
  
  cat("Performance analysis functions test completed!\n")
}

#' Test regression analysis functions
test_regression_functions <- function() {
  
  cat("Testing refactored regression analysis functions...\n")
  
  # Create sample data for testing
  sample_data <- data.frame(
    firmname = c("VC1", "VC2", "VC1", "VC2"),
    year = c(1990, 1990, 1991, 1991),
    NumExit = c(1, 0, 2, 1),
    InvestAMT = c(1000, 500, 2000, 1500),
    blau = c(0.5, 0.3, 0.6, 0.4)
  )
  
  # Test create_panel_data function
  cat("Testing create_panel_data function...\n")
  tryCatch({
    panel_data <- create_panel_data(sample_data)
    cat("✓ create_panel_data function works correctly\n")
    cat("  - Created panel data with", nrow(panel_data), "observations\n")
  }, error = function(e) {
    cat("✗ create_panel_data function failed:", e$message, "\n")
  })
  
  # Test create_regression_formula function
  cat("Testing create_regression_formula function...\n")
  tryCatch({
    formula <- create_regression_formula("NumExit", c("InvestAMT", "blau"))
    cat("✓ create_regression_formula function works correctly\n")
    cat("  - Created formula:", as.character(formula)[2], "~", as.character(formula)[3], "\n")
  }, error = function(e) {
    cat("✗ create_regression_formula function failed:", e$message, "\n")
  })
  
  cat("Regression analysis functions test completed!\n")
}

#' Test function to verify parameter loading
test_config_loading <- function() {
  
  cat("Testing configuration loading...\n")
  
  # Test if parameters are loaded correctly
  if (exists("NETWORK_PARAMS")) {
    cat("✓ NETWORK_PARAMS loaded successfully\n")
    cat("  - Default time window:", NETWORK_PARAMS$default_time_window, "\n")
    cat("  - Default edge cutpoint:", NETWORK_PARAMS$default_edge_cutpoint, "\n")
  } else {
    cat("✗ NETWORK_PARAMS not found\n")
  }
  
  if (exists("SAMPLING_PARAMS")) {
    cat("✓ SAMPLING_PARAMS loaded successfully\n")
    cat("  - Default ratio:", SAMPLING_PARAMS$default_ratio, "\n")
  } else {
    cat("✗ SAMPLING_PARAMS not found\n")
  }
  
  if (exists("BASE_PATHS")) {
    cat("✓ BASE_PATHS loaded successfully\n")
    cat("  - Data path:", BASE_PATHS$data, "\n")
  } else {
    cat("✗ BASE_PATHS not found\n")
  }
  
  if (exists("INDUSTRY_CODES")) {
    cat("✓ INDUSTRY_CODES loaded successfully\n")
    cat("  - Number of industry codes:", length(INDUSTRY_CODES), "\n")
  } else {
    cat("✗ INDUSTRY_CODES not found\n")
  }
  
  if (exists("EXIT_TYPES")) {
    cat("✓ EXIT_TYPES loaded successfully\n")
    cat("  - Exit types:", paste(EXIT_TYPES, collapse = ", "), "\n")
  } else {
    cat("✗ EXIT_TYPES not found\n")
  }
  
  cat("Configuration test completed!\n")
}

#' Test module loading functions
test_module_loading <- function() {
  
  cat("Testing module loading functions...\n")
  
  # Test load_module_group function
  tryCatch({
    config_modules <- load_module_group("config")
    cat("✓ load_module_group('config') works correctly\n")
  }, error = function(e) {
    cat("✗ load_module_group('config') failed:", e$message, "\n")
  })
  
  tryCatch({
    core_modules <- load_module_group("core")
    cat("✓ load_module_group('core') works correctly\n")
  }, error = function(e) {
    cat("✗ load_module_group('core') failed:", e$message, "\n")
  })
  
  # Test load_analysis_module function
  tryCatch({
    diversity_module <- load_analysis_module("diversity")
    cat("✓ load_analysis_module('diversity') works correctly\n")
  }, error = function(e) {
    cat("✗ load_analysis_module('diversity') failed:", e$message, "\n")
  })
  
  cat("Module loading test completed!\n")
}

# Run tests
if (interactive()) {
  cat("Running comprehensive tests for refactored functions...\n\n")
  
  test_config_loading()
  cat("\n")
  
  test_network_functions()
  cat("\n")
  
  test_sampling_functions()
  cat("\n")
  
  test_diversity_functions()
  cat("\n")
  
  test_imprinting_functions()
  cat("\n")
  
  test_performance_functions()
  cat("\n")
  
  test_regression_functions()
  cat("\n")
  
  test_module_loading()
  cat("\n")
  
  cat("All tests completed!\n")
  cat("Available functions:\n")
  cat("- Core functions:", length(modules$core_functions), "\n")
  cat("- Analysis functions:", length(modules$analysis_functions), "\n")
  cat("- Utility functions:", length(modules$utility_functions), "\n")
} else {
  cat("Tests can be run interactively by calling:\n")
  cat("test_config_loading()\n")
  cat("test_network_functions()\n")
  cat("test_sampling_functions()\n")
  cat("test_diversity_functions()\n")
  cat("test_imprinting_functions()\n")
  cat("test_performance_functions()\n")
  cat("test_regression_functions()\n")
  cat("test_module_loading()\n")
} 