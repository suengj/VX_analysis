# CVC Analysis Example Script
# Using Refactored VC Network Analysis Modules
# Based on CVC_preprcs_v4.R and CVC_analysis.R

# Set working directory to data location first
setwd("/Users/suengj/Documents/Code/Python/Research/VC/raw/extract")

# Load all modules (use absolute path to avoid path issues)
source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/load_all_modules.R")
modules <- load_vc_modules()

#' Complete CVC Analysis Workflow
#' This example demonstrates the complete CVC analysis process
#' using the refactored modules

# =============================================================================
# 1. DATA LOADING AND PREPROCESSING
# =============================================================================

cat("Step 1: Loading and preprocessing data...\n")

# Load data - handle both .pkl and .rds files
tryCatch({
  # Try to load .pkl files first (Python pickle format)
  if (require("reticulate")) {
    comdta <- reticulate::py_load_object('company_data.pkl') %>% as_tibble()
    firmdta <- reticulate::py_load_object('VC_firm_US.pkl') %>% as_tibble()
    round <- reticulate::py_load_object("round_data_US.pkl")
  } else {
    # Fallback to .rds files (if they exist)
    cat("reticulate not available, trying .rds files...\n")
    comdta <- readRDS('company_data.rds') %>% as_tibble()
    firmdta <- readRDS('VC_firm_US.rds') %>% as_tibble()
    round <- readRDS("round_data_US.rds")
  }
}, error = function(e) {
  # If .pkl fails, try .rds files
  cat("Loading .rds files instead...\n")
  comdta <- readRDS('company_data.rds') %>% as_tibble()
  firmdta <- readRDS('VC_firm_US.rds') %>% as_tibble()
  round <- readRDS("round_data_US.rds")
})

# Process company data
comdta <- comdta %>%
  mutate(exit = ifelse(comsitu %in% EXIT_TYPES & (date_sit != "" | date_ipo != ""), 1, 0)) %>%
  mutate(ipoExit = ifelse(comsitu %in% "Went Public" & (date_sit != "" | date_ipo != ""), 1, 0)) %>%
  mutate(MnAExit = ifelse(comsitu %in% c("Merger", "Acquisition") & date_sit != "", 1, 0))

# Process firm data
firmdta <- firmdta %>%
  mutate(fnd_year = year(firmfounding)) %>%
  mutate(firmtype2 = case_when(
    firmtype %in% c("Angel Group","Individuals") ~ "Angel",
    firmtype %in% c("Corporate PE/Venture")~ "CVC",
    firmtype %in% c("Investment Management Firm", "Bank Affiliated",
                    "Private Equity Advisor or Fund of Funds",
                    "SBIC","Endowment, Foundation or Pension Fund",
                    "Insurance Firm Affiliate") ~ "Financial",
    firmtype %in% c("Private Equity Firm")~"IVC",
    firmtype %in% c("Incubator/Development Program",
                    "Government Affiliated Program",
                    "University Program")~"Non-Financial",
    firmtype %in% c("Service Provider","Other","Non-Private Equity")~"Other"
  )) %>%
  mutate(firmtype3 = ifelse(firmtype2 %in% c("IVC"),"IVC","non-IVC"))

# Process round data
round <- round %>%
  filter(firmname != "Undisclosed Firm", comname != "Undisclosed Company") %>%
  mutate(rnddate = as.Date(rnddate, origin="1899-12-30")) %>%
  mutate(year = year(rnddate), month = month(rnddate), day = day(rnddate)) %>%
  filter(year > 1979)

# Merge firm information
round <- left_join(round, firmdta %>% select(firmname, firmnation, firmtype2, firmtype3), by="firmname")
round <- left_join(round, comdta %>% select(comname, comnation), by="comname")

cat("✓ Data loaded successfully\n")

# =============================================================================
# 2. NETWORK CONSTRUCTION AND CENTRALITY CALCULATION
# =============================================================================

cat("\nStep 2: Constructing networks and calculating centrality...\n")

# Define analysis parameters with data filtering option
if (exists("EXAMPLE_PARAMS") && EXAMPLE_PARAMS$use_limited_data) {
  analysis_years <- EXAMPLE_PARAMS$example_years
  cat("Using limited data for example: years", min(analysis_years), "to", max(analysis_years), "\n")
} else {
  analysis_years <- 1990:2010
  cat("Using full data: years", min(analysis_years), "to", max(analysis_years), "\n")
}
time_window <- NETWORK_PARAMS$default_time_window
edge_cutpoint <- NETWORK_PARAMS$default_edge_cutpoint

# Calculate centrality for each year
centrality_list <- list()

for (year in analysis_years) {
  cat("Processing year:", year, "\n")
  
  tryCatch({
    centrality_data <- VC_centralities(round, year, time_window, edge_cutpoint)
    centrality_list[[as.character(year)]] <- centrality_data
  }, error = function(e) {
    cat("Error processing year", year, ":", e$message, "\n")
  })
}

# Combine centrality data
centrality_df <- do.call("rbind", centrality_list)
centrality_df <- centrality_df %>% as_tibble()

cat("✓ Network centrality calculated for", length(analysis_years), "years\n")

# =============================================================================
# 3. SAMPLING AND DATA PROCESSING
# =============================================================================

cat("\nStep 3: Creating sampling dataset...\n")

# Create lead VC data
leadVC_data <- round %>%
  group_by(comname, year) %>%
  filter(row_number() == 1) %>%
  ungroup() %>%
  select(firmname, comname, year, quarter) %>%
  mutate(leadVC = 1)

# Create co-investment data
coVC_data <- round %>%
  group_by(comname, year) %>%
  filter(n() > 1) %>%
  ungroup() %>%
  select(firmname, comname, year, quarter) %>%
  mutate(leadVC = 0)

# Combine lead and co-investment data
investment_data <- rbind(leadVC_data, coVC_data)

# Create unique co-investor list
coVC_unique <- list(coVC = unique(coVC_data$firmname))

# Create realized ties data
realized_ties <- investment_data %>%
  group_by(comname, year, quarter) %>%
  filter(n() > 1) %>%
  ungroup() %>%
  group_by(comname, year, quarter) %>%
  do({
    lead_vc <- .$firmname[.$leadVC == 1]
    co_vcs <- .$firmname[.$leadVC == 0]
    if (length(lead_vc) > 0 && length(co_vcs) > 0) {
      expand.grid(leadVC = lead_vc, coVC = co_vcs, stringsAsFactors = FALSE) %>%
        mutate(realized = 1, comname = .$comname[1], year = .$year[1], quarter = .$quarter[1])
    } else {
      data.frame()
    }
  }) %>%
  ungroup()

# Perform sampling
sampled_data <- VC_sampling_opt1_output(round, leadVC_data, "quarter", 
                                       SAMPLING_PARAMS$default_ratio, "1995Q1")

cat("✓ Sampling dataset created with", nrow(sampled_data), "observations\n")

# =============================================================================
# 4. DIVERSITY ANALYSIS
# =============================================================================

cat("\nStep 4: Calculating portfolio diversity...\n")

# Prepare industry data for diversity analysis
industry_data <- round %>%
  group_by(firmname, year) %>%
  summarise(
    ind1 = sum(comindmnr == "Internet Specific", na.rm = TRUE),
    ind2 = sum(comindmnr == "Medical/Health", na.rm = TRUE),
    ind3 = sum(comindmnr == "Consumer Related", na.rm = TRUE),
    ind4 = sum(comindmnr == "Semiconductors/Other Elect.", na.rm = TRUE),
    ind5 = sum(comindmnr == "Communications and Media", na.rm = TRUE),
    ind6 = sum(comindmnr == "Industrial/Energy", na.rm = TRUE),
    ind7 = sum(comindmnr == "Computer Software and Services", na.rm = TRUE),
    ind8 = sum(comindmnr == "Computer Hardware", na.rm = TRUE),
    ind9 = sum(comindmnr == "Biotechnology", na.rm = TRUE),
    ind10 = sum(comindmnr == "Other Products", na.rm = TRUE),
    .groups = "drop"
  )

# Calculate Blau index
diversity_data <- blau_index(industry_data)

# Calculate additional diversity measures
portfolio_diversity <- calculate_portfolio_diversity(industry_data)
geographic_diversity <- calculate_geographic_diversity(round)
stage_diversity <- calculate_stage_diversity(round)

cat("✓ Portfolio diversity calculated\n")

# =============================================================================
# 5. PERFORMANCE ANALYSIS
# =============================================================================

cat("\nStep 5: Analyzing VC performance...\n")

# Create exit data
exit_data <- create_exit_data(comdta)

# Calculate performance metrics with data filtering option
if (exists("EXAMPLE_PARAMS") && EXAMPLE_PARAMS$use_limited_data) {
  performance_years <- EXAMPLE_PARAMS$example_years
  cat("Using limited data for performance analysis: years", min(performance_years), "to", max(performance_years), "\n")
} else {
  performance_years <- 1995:2005
  cat("Using full data for performance analysis: years", min(performance_years), "to", max(performance_years), "\n")
}
performance_data <- calculate_performance_metrics(round, comdta, performance_years, time_window = 5)

# Calculate exit percentages
investment_summary <- round %>%
  group_by(firmname, year) %>%
  summarise(
    total_investments = n(),
    total_amount = sum(rndamt, na.rm = TRUE),
    .groups = "drop"
  )

exit_percentages <- calculate_exit_percentages(performance_data, investment_summary)

cat("✓ Performance metrics calculated\n")

# =============================================================================
# 6. CVC SPECIFIC ANALYSIS
# =============================================================================

cat("\nStep 6: CVC-specific analysis...\n")

# Identify CVC firms
cvc_firms <- firmdta %>% filter(firmtype2 == "CVC") %>% pull(firmname)

# Filter data for CVC analysis
cvc_rounds <- round %>% filter(firmname %in% cvc_firms)
cvc_centrality <- centrality_df %>% filter(firmname %in% cvc_firms)

# CVC partnership analysis
cvc_partnerships <- round %>%
  filter(firmname %in% cvc_firms) %>%
  group_by(comname, year) %>%
  filter(n() > 1) %>%
  ungroup() %>%
  mutate(cvc_present = firmname %in% cvc_firms) %>%
  group_by(comname, year) %>%
  summarise(
    cvc_count = sum(cvc_present),
    total_vcs = n(),
    cvc_ratio = cvc_count / total_vcs,
    .groups = "drop"
  )

cat("✓ CVC-specific analysis completed\n")

# =============================================================================
# 7. REGRESSION ANALYSIS
# =============================================================================

cat("\nStep 7: Running regression analysis...\n")

# Prepare data for regression
regression_data <- sampled_data %>%
  left_join(centrality_df, by = c("leadVC" = "firmname", "year")) %>%
  left_join(diversity_data, by = c("leadVC" = "firmname", "year")) %>%
  left_join(performance_data, by = c("leadVC" = "firmname", "year")) %>%
  left_join(cvc_partnerships, by = c("comname", "year")) %>%
  mutate(
    cvc_dummy = ifelse(leadVC %in% cvc_firms, 1, 0),
    log_investment = log(rndamt + 1),
    log_centrality = log(dgr + 1)
  )

# Create panel data
panel_data <- create_panel_data(regression_data)

# Run CVC regression models
cvc_models <- list()

# Base model
cvc_models$base <- run_cvc_regression(regression_data, "realized", "base")

# Network effects model
cvc_models$network <- run_cvc_regression(regression_data, "realized", "network")

# CVC specific model
cvc_models$cvc <- run_cvc_regression(regression_data, "realized", "cvc")

cat("✓ Regression analysis completed\n")

# =============================================================================
# 8. RESULTS AND SUMMARY
# =============================================================================

cat("\nStep 8: Generating results and summary...\n")

# Summary statistics
cat("\n=== SUMMARY STATISTICS ===\n")
cat("Total observations:", nrow(regression_data), "\n")
cat("CVC firms:", length(cvc_firms), "\n")
cat("Analysis period:", min(analysis_years), "-", max(analysis_years), "\n")
cat("Time window:", time_window, "years\n")

# Network statistics
cat("\n=== NETWORK STATISTICS ===\n")
cat("Average degree centrality:", mean(centrality_df$dgr, na.rm = TRUE), "\n")
cat("Average betweenness centrality:", mean(centrality_df$btw, na.rm = TRUE), "\n")
cat("Average power centrality:", mean(centrality_df$pwr_max, na.rm = TRUE), "\n")

# Performance statistics
cat("\n=== PERFORMANCE STATISTICS ===\n")
cat("Average exits per VC:", mean(performance_data$exitNum, na.rm = TRUE), "\n")
cat("Average IPOs per VC:", mean(performance_data$ipoNum, na.rm = TRUE), "\n")
cat("Average M&As per VC:", mean(performance_data$MnANum, na.rm = TRUE), "\n")

# Diversity statistics
cat("\n=== DIVERSITY STATISTICS ===\n")
cat("Average Blau index:", mean(diversity_data$blau, na.rm = TRUE), "\n")
cat("Average portfolio diversity:", mean(portfolio_diversity$portfolio_diversity, na.rm = TRUE), "\n")

# CVC statistics
cat("\n=== CVC STATISTICS ===\n")
cat("CVC partnership ratio:", mean(cvc_partnerships$cvc_ratio, na.rm = TRUE), "\n")
cat("CVC firms in sample:", sum(regression_data$cvc_dummy), "\n")

# Model results
cat("\n=== REGRESSION RESULTS ===\n")
for (model_name in names(cvc_models)) {
  cat("\nModel:", model_name, "\n")
  print(summary(cvc_models[[model_name]]))
}

# =============================================================================
# 9. SAVE RESULTS
# =============================================================================

cat("\nStep 9: Saving results...\n")

# Create timestamp for file naming
timestamp <- format(Sys.time(), "%y%m%d_%H%M")

# Create results directory structure
base_dir <- "/Users/suengj/Documents/Code/Python/Research/VC/rst"
cvc_dir <- file.path(base_dir, "cvc_rst")
if (!dir.exists(base_dir)) dir.create(base_dir, recursive = TRUE)
if (!dir.exists(cvc_dir)) dir.create(cvc_dir, recursive = TRUE)

# Save processed data with timestamp
write.csv(centrality_df, file.path(cvc_dir, paste0("centrality_data_", timestamp, ".csv")), row.names = FALSE)
write.csv(diversity_data, file.path(cvc_dir, paste0("diversity_data_", timestamp, ".csv")), row.names = FALSE)
write.csv(performance_data, file.path(cvc_dir, paste0("performance_data_", timestamp, ".csv")), row.names = FALSE)
write.csv(regression_data, file.path(cvc_dir, paste0("regression_data_", timestamp, ".csv")), row.names = FALSE)
write.csv(cvc_partnerships, file.path(cvc_dir, paste0("cvc_partnerships_", timestamp, ".csv")), row.names = FALSE)

# Save model results as CSV for cross-platform compatibility
for (model_name in names(cvc_models)) {
  model_summary <- summary(cvc_models[[model_name]])
  model_coef <- as.data.frame(model_summary$coefficients)
  write.csv(model_coef, file.path(cvc_dir, paste0("cvc_model_", model_name, "_", timestamp, ".csv")), row.names = TRUE)
}

cat("✓ Results saved to CVC results directory\n")

# =============================================================================
# 10. CLEANUP
# =============================================================================

cat("\nStep 10: Cleanup...\n")

# Remove temporary objects
rm(centrality_list, sampled_data, industry_data, exit_data, investment_summary)

cat("✓ Analysis completed successfully!\n")
cat("\nFiles saved in cvc_rst directory:\n")
cat("- centrality_data_", timestamp, ".csv: Network centrality measures\n")
cat("- diversity_data_", timestamp, ".csv: Portfolio diversity measures\n")
cat("- performance_data_", timestamp, ".csv: VC performance metrics\n")
cat("- regression_data_", timestamp, ".csv: Regression analysis dataset\n")
cat("- cvc_partnerships_", timestamp, ".csv: CVC partnership data\n")
cat("- cvc_model_*.csv: Regression model coefficients\n") 