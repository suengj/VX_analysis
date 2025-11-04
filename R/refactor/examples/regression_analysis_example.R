# Regression Analysis Example Script
# Using Refactored VC Network Analysis Modules
# Based on imprinting_Dec18.R and CVC_analysis.R regression models

# Set working directory to data location first
setwd("/Users/suengj/Documents/Code/Python/Research/VC/raw/extract")

# Load all modules and setup required packages (use absolute path to avoid path issues)
source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/load_all_modules.R")
modules <- quick_setup()  # This will install and load all required packages including reticulate

#' Complete Regression Analysis Workflow
#' This example demonstrates the complete regression analysis process
#' using the refactored modules

# =============================================================================
# 1. DATA LOADING AND PREPROCESSING
# =============================================================================

cat("Step 1: Loading and preprocessing data...\n")

# Load data from .rds files
comdta <- readRDS('company_data.rds') %>% as_tibble()
firmdta <- readRDS('firm_data.rds') %>% as_tibble()
round <- readRDS("round_data_US.rds")

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
# 2. NETWORK CENTRALITY CALCULATION
# =============================================================================

cat("\nStep 2: Calculating network centrality...\n")

# Define analysis parameters with data filtering option
if (exists("EXAMPLE_PARAMS") && EXAMPLE_PARAMS$use_limited_data) {
  analysis_years <- EXAMPLE_PARAMS$example_years
  cat("Using limited data for example: years", min(analysis_years), "to", max(analysis_years), "\n")
} else {
  analysis_years <- 1990:2010
  cat("Using full data: years", min(analysis_years), "to", max(analysis_years), "\n")
}
time_windows <- c(1, 3, 5)
edge_cutpoint <- NETWORK_PARAMS$default_edge_cutpoint

# Calculate centrality for different time windows
centrality_list <- list()

for (tw in time_windows) {
  cat("Processing time window:", tw, "years\n")
  
  tw_centrality_list <- list()
  
  for (year in analysis_years) {
    tryCatch({
      centrality_data <- VC_centralities(round, year, tw, edge_cutpoint)
      centrality_data$time_window <- tw
      tw_centrality_list[[as.character(year)]] <- centrality_data
    }, error = function(e) {
      # Skip years with insufficient data
    })
  }
  
  centrality_list[[paste0("_", tw, "y")]] <- do.call("rbind", tw_centrality_list)
}

# Combine all centrality data
centrality_df <- do.call("rbind", centrality_list)
centrality_df <- centrality_df %>% as_tibble()

cat("✓ Network centrality calculated for", length(time_windows), "time windows\n")

# =============================================================================
# 3. PERFORMANCE DATA PREPARATION
# =============================================================================

cat("\nStep 3: Preparing performance data...\n")

# Create exit data
exit_data <- create_exit_data(comdta)

# Calculate performance metrics with data filtering option
if (exists("EXAMPLE_PARAMS") && EXAMPLE_PARAMS$use_limited_data) {
  performance_years <- EXAMPLE_PARAMS$example_years
  cat("Using limited data for performance analysis: years", min(performance_years), "to", max(performance_years), "\n")
} else {
  performance_years <- 1995:2010
  cat("Using full data for performance analysis: years", min(performance_years), "to", max(performance_years), "\n")
}
performance_data <- calculate_performance_metrics(round, comdta, performance_years, time_window = 5)

# Calculate investment amounts
investment_data <- round %>%
  group_by(firmname, year) %>%
  summarise(
    InvestAMT = sum(rndamt, na.rm = TRUE),
    NumInvestments = n(),
    .groups = "drop"
  )

cat("✓ Performance data prepared\n")

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

cat("✓ Portfolio diversity calculated\n")

# =============================================================================
# 5. IMPRINTING DATA PREPARATION
# =============================================================================

cat("\nStep 5: Preparing imprinting data...\n")

# Create initial year data
initial_year_data <- round %>%
  group_by(firmname) %>%
  summarise(initial_year = min(year), .groups = "drop") %>%
  filter(initial_year >= 1970 & initial_year <= 2010)

# Define imprinting period
imprinting_period <- 3

# Calculate initial ties
initial_ties_list <- list()
for (year in unique(round$year)) {
  tryCatch({
    ties <- VC_initial_ties(round, year, imprinting_period)
    if (nrow(ties) > 0) {
      initial_ties_list[[as.character(year)]] <- ties
    }
  }, error = function(e) {
    # Skip years with insufficient data
  })
}

# Combine initial ties
initial_ties <- do.call("rbind", initial_ties_list)
initial_ties <- initial_ties %>% as_tibble()

# Add initial year information
initial_ties <- left_join(initial_ties, initial_year_data, by = "firmname")

# Filter by imprinting period
initial_partner_list <- VC_initial_period(initial_ties, imprinting_period)

# Calculate partner centrality
partner_centrality_list <- list()
for (tw in time_windows) {
  cent_tw <- centrality_df %>% 
    filter(time_window == tw) %>%
    select(-time_window)
  
  partner_centrality_list[[paste0("_", tw, "y")]] <- 
    VC_initial_partner_centrality(initial_partner_list, cent_tw)
}

# Combine partner centrality data
partner_centrality <- do.call("left_join", partner_centrality_list)

cat("✓ Imprinting data prepared\n")

# =============================================================================
# 6. REGRESSION DATASET CREATION
# =============================================================================

cat("\nStep 6: Creating regression dataset...\n")

# Create comprehensive regression dataset
regression_dataset <- centrality_df %>%
  filter(time_window == 3) %>%  # Use 3-year window for main analysis
  select(-time_window) %>%
  left_join(performance_data, by = c("firmname", "year")) %>%
  left_join(investment_data, by = c("firmname", "year")) %>%
  left_join(diversity_data, by = c("firmname", "year")) %>%
  left_join(firmdta %>% select(firmname, firmtype2, firmtype3, fnd_year), by = "firmname") %>%
  left_join(initial_year_data, by = "firmname") %>%
  left_join(partner_centrality, by = c("firmname", "year")) %>%
  mutate(
    timesince = year - initial_year,
    CAMA = ifelse(year >= 2000, 1, 0),  # Dot-com bubble period
    earlyStage = 1,  # Placeholder for early stage investments
    blau = ifelse(is.na(blau), 0, blau),
    initial_partner_num = n_distinct(initial_partner, na.rm = TRUE),
    firm_age = year - fnd_year
  ) %>%
  filter(!is.na(NumExit) & !is.na(initial_year))

cat("✓ Regression dataset created with", nrow(regression_dataset), "observations\n")

# =============================================================================
# 7. IMPRINTING REGRESSION ANALYSIS
# =============================================================================

cat("\nStep 7: Running imprinting regression analysis...\n")

# Create panel data
panel_data <- create_panel_data(regression_dataset)

# Run imprinting regression models
imprinting_models <- list()

# H0: Base model
imprinting_models$H0 <- run_imprinting_regression(panel_data, "H0")

# H1: Partner power centrality effect
imprinting_models$H1 <- run_imprinting_regression(panel_data, "H1")

# H2: Interaction effect
imprinting_models$H2 <- run_imprinting_regression(panel_data, "H2")

cat("✓ Imprinting regression analysis completed\n")

# =============================================================================
# 8. CVC REGRESSION ANALYSIS
# =============================================================================

cat("\nStep 8: Running CVC regression analysis...\n")

# Prepare CVC analysis data
cvc_data <- regression_dataset %>%
  mutate(
    cvc_dummy = ifelse(firmtype2 == "CVC", 1, 0),
    ivc_dummy = ifelse(firmtype3 == "IVC", 1, 0),
    realized = 1,  # Placeholder for partnership realization
    nt_size_sum = NumInvestments
  )

# Run CVC regression models
cvc_models <- list()

# Base model
cvc_models$base <- run_cvc_regression(cvc_data, "realized", "base")

# Network effects model
cvc_models$network <- run_cvc_regression(cvc_data, "realized", "network")

# CVC specific model
cvc_models$cvc <- run_cvc_regression(cvc_data, "realized", "cvc")

cat("✓ CVC regression analysis completed\n")

# =============================================================================
# 9. MODEL COMPARISON
# =============================================================================

cat("\nStep 9: Comparing models...\n")

# Define model specifications for comparison
model_specs <- list(
  list(type = "imprinting", hypothesis = "H0"),
  list(type = "imprinting", hypothesis = "H1"),
  list(type = "imprinting", hypothesis = "H2"),
  list(type = "cvc", dependent_var = "realized", model_type = "base"),
  list(type = "cvc", dependent_var = "realized", model_type = "network"),
  list(type = "cvc", dependent_var = "realized", model_type = "cvc")
)

# Run model comparison
model_comparison <- run_model_comparison(regression_dataset, model_specs)

cat("✓ Model comparison completed\n")

# =============================================================================
# 10. VIF ANALYSIS
# =============================================================================

cat("\nStep 10: Running VIF analysis...\n")

# Calculate VIF for imprinting models
vif_results <- list()

for (model_name in names(imprinting_models)) {
  tryCatch({
    vif_results[[model_name]] <- calculate_vif(imprinting_models[[model_name]])
  }, error = function(e) {
    cat("VIF calculation failed for", model_name, ":", e$message, "\n")
  })
}

cat("✓ VIF analysis completed\n")

# =============================================================================
# 11. ROBUSTNESS CHECKS
# =============================================================================

cat("\nStep 11: Running robustness checks...\n")

# Define robustness specifications
robustness_specs <- list(
  list(type = "subsample", condition = year >= 1995, model_type = "H1"),
  list(type = "subsample", condition = year <= 2005, model_type = "H1"),
  list(type = "subsample", condition = firmtype2 == "IVC", model_type = "H1"),
  list(type = "alternative_spec", model_type = "H0")
)

# Run robustness checks
robustness_results <- run_robustness_checks(regression_dataset, imprinting_models$H1, robustness_specs)

cat("✓ Robustness checks completed\n")

# =============================================================================
# 12. MODEL RESULTS EXTRACTION
# =============================================================================

cat("\nStep 12: Extracting model results...\n")

# Extract results for all models
model_results <- list()

# Imprinting models
for (model_name in names(imprinting_models)) {
  model_results[[paste0("imprinting_", model_name)]] <- 
    extract_model_results(imprinting_models[[model_name]])
}

# CVC models
for (model_name in names(cvc_models)) {
  model_results[[paste0("cvc_", model_name)]] <- 
    extract_model_results(cvc_models[[model_name]])
}

cat("✓ Model results extracted\n")

# =============================================================================
# 13. RESULTS AND SUMMARY
# =============================================================================

cat("\nStep 13: Generating results and summary...\n")

# Summary statistics
cat("\n=== SUMMARY STATISTICS ===\n")
cat("Total observations:", nrow(regression_dataset), "\n")
cat("Analysis period:", min(analysis_years), "-", max(analysis_years), "\n")
cat("Time window:", time_windows[2], "years\n")
cat("Imprinting period:", imprinting_period, "years\n")

# Network statistics
cat("\n=== NETWORK STATISTICS ===\n")
cat("Average degree centrality:", mean(centrality_df$dgr, na.rm = TRUE), "\n")
cat("Average betweenness centrality:", mean(centrality_df$btw, na.rm = TRUE), "\n")
cat("Average power centrality:", mean(centrality_df$pwr_max, na.rm = TRUE), "\n")
cat("Average constraint:", mean(centrality_df$cons_value, na.rm = TRUE), "\n")

# Performance statistics
cat("\n=== PERFORMANCE STATISTICS ===\n")
cat("Average exits per firm:", mean(regression_dataset$NumExit, na.rm = TRUE), "\n")
cat("Average investment amount:", mean(regression_dataset$InvestAMT, na.rm = TRUE), "\n")
cat("Average portfolio diversity (Blau index):", mean(regression_dataset$blau, na.rm = TRUE), "\n")

# Model results
cat("\n=== IMPRINTING REGRESSION RESULTS ===\n")
for (model_name in names(imprinting_models)) {
  cat("\nModel:", model_name, "\n")
  print(summary(imprinting_models[[model_name]]))
}

cat("\n=== CVC REGRESSION RESULTS ===\n")
for (model_name in names(cvc_models)) {
  cat("\nModel:", model_name, "\n")
  print(summary(cvc_models[[model_name]]))
}

# VIF results
cat("\n=== VIF RESULTS ===\n")
for (model_name in names(vif_results)) {
  cat("\nModel:", model_name, "\n")
  print(vif_results[[model_name]])
}

# =============================================================================
# 14. SAVE RESULTS
# =============================================================================

cat("\nStep 14: Saving results...\n")

# Create timestamp for file naming
timestamp <- format(Sys.time(), "%y%m%d_%H%M")

# Create results directory structure
base_dir <- "/Users/suengj/Documents/Code/Python/Research/VC/rst"
reg_dir <- file.path(base_dir, "reg_rst")
if (!dir.exists(base_dir)) dir.create(base_dir, recursive = TRUE)
if (!dir.exists(reg_dir)) dir.create(reg_dir, recursive = TRUE)

# Save processed data with timestamp
write.csv(regression_dataset, file.path(reg_dir, paste0("regression_dataset_", timestamp, ".csv")), row.names = FALSE)
write.csv(centrality_df, file.path(reg_dir, paste0("centrality_data_", timestamp, ".csv")), row.names = FALSE)
write.csv(performance_data, file.path(reg_dir, paste0("performance_data_", timestamp, ".csv")), row.names = FALSE)
write.csv(diversity_data, file.path(reg_dir, paste0("diversity_data_", timestamp, ".csv")), row.names = FALSE)
write.csv(partner_centrality, file.path(reg_dir, paste0("partner_centrality_", timestamp, ".csv")), row.names = FALSE)

# Save model results as CSV for cross-platform compatibility
for (model_name in names(imprinting_models)) {
  model_summary <- summary(imprinting_models[[model_name]])
  model_coef <- as.data.frame(model_summary$coefficients)
  write.csv(model_coef, file.path(reg_dir, paste0("imprinting_model_", model_name, "_", timestamp, ".csv")), row.names = TRUE)
}

for (model_name in names(cvc_models)) {
  model_summary <- summary(cvc_models[[model_name]])
  model_coef <- as.data.frame(model_summary$coefficients)
  write.csv(model_coef, file.path(reg_dir, paste0("cvc_model_", model_name, "_", timestamp, ".csv")), row.names = TRUE)
}

# Save model comparison results
if (length(model_comparison) > 0) {
  write.csv(model_comparison, file.path(reg_dir, paste0("model_comparison_", timestamp, ".csv")), row.names = FALSE)
}

# Save VIF results
if (length(vif_results) > 0) {
  vif_df <- do.call(rbind, lapply(names(vif_results), function(name) {
    data.frame(model = name, vif_results[[name]])
  }))
  write.csv(vif_df, file.path(reg_dir, paste0("vif_results_", timestamp, ".csv")), row.names = FALSE)
}

# Save robustness results
if (length(robustness_results) > 0) {
  write.csv(robustness_results, file.path(reg_dir, paste0("robustness_results_", timestamp, ".csv")), row.names = FALSE)
}

# Save extracted results
for (result_name in names(model_results)) {
  write.csv(model_results[[result_name]], 
            file.path(reg_dir, paste0(result_name, "_results_", timestamp, ".csv")), 
            row.names = FALSE)
}

cat("✓ Results saved to regression results directory\n")

# =============================================================================
# 15. CLEANUP
# =============================================================================

cat("\nStep 15: Cleanup...\n")

# Remove temporary objects
rm(centrality_list, initial_ties_list, partner_centrality_list,
   industry_data, diversity_data, exit_data, investment_data, performance_data)

cat("✓ Analysis completed successfully!\n")
cat("\nFiles saved in reg_rst directory:\n")
cat("- regression_dataset_", timestamp, ".csv: Complete regression dataset\n")
cat("- centrality_data_", timestamp, ".csv: Network centrality measures\n")
cat("- performance_data_", timestamp, ".csv: VC performance metrics\n")
cat("- diversity_data_", timestamp, ".csv: Portfolio diversity measures\n")
cat("- partner_centrality_", timestamp, ".csv: Partner centrality measures\n")
cat("- imprinting_model_*.csv: Imprinting regression model coefficients\n")
cat("- cvc_model_*.csv: CVC regression model coefficients\n")
cat("- model_comparison_", timestamp, ".csv: Model comparison results\n")
cat("- vif_results_", timestamp, ".csv: VIF analysis results\n")
cat("- robustness_results_", timestamp, ".csv: Robustness check results\n")
cat("- *_results_", timestamp, ".csv: Extracted model results\n") 