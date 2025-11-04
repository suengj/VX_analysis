# Performance Analysis Example Script
# Using Refactored VC Network Analysis Modules
# Based on CVC_preprcs_v4.R performance functions

# Set working directory to data location first
setwd("/Users/suengj/Documents/Code/Python/Research/VC/raw/extract")

# Load all modules and setup required packages (use absolute path to avoid path issues)
source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/load_all_modules.R")
modules <- quick_setup()  # This will install and load all required packages including reticulate

#' Complete Performance Analysis Workflow
#' This example demonstrates the complete VC performance analysis process
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
# 2. EXIT DATA CREATION
# =============================================================================

cat("\nStep 2: Creating exit data...\n")

# Create exit data
exit_data <- create_exit_data(comdta)

# Summary of exit data
cat("✓ Exit data created successfully\n")
cat("Total companies with exit data:", nrow(exit_data), "\n")
cat("Companies with exits:", sum(exit_data$exit), "\n")
cat("Companies with IPOs:", sum(exit_data$ipoExit), "\n")
cat("Companies with M&As:", sum(exit_data$MnAExit), "\n")

# =============================================================================
# 3. PERFORMANCE METRICS CALCULATION
# =============================================================================

cat("\nStep 3: Calculating performance metrics...\n")

# Define analysis parameters with data filtering option
if (exists("EXAMPLE_PARAMS") && EXAMPLE_PARAMS$use_limited_data) {
  performance_years <- EXAMPLE_PARAMS$example_years
  cat("Using limited data for example: years", min(performance_years), "to", max(performance_years), "\n")
} else {
  performance_years <- 1980:2010
  cat("Using full data: years", min(performance_years), "to", max(performance_years), "\n")
}
time_window <- 5

# Calculate performance metrics for each year
performance_list <- list()

for (year in performance_years) {
  cat("Processing year:", year, "\n")
  
  tryCatch({
    # Calculate exit numbers
    exit_numbers <- VC_exit_num(round, exit_data, year, time_window)
    
    # Calculate IPO numbers
    ipo_numbers <- VC_IPO_num(round, exit_data, year, time_window)
    
    # Calculate M&A numbers
    mna_numbers <- VC_MnA_num(round, exit_data, year, time_window)
    
    # Combine results
    year_performance <- left_join(exit_numbers, ipo_numbers, by = c("firmname", "newyr")) %>%
      left_join(mna_numbers, by = c("firmname", "newyr")) %>%
      rename(year = newyr)
    
    performance_list[[as.character(year)]] <- year_performance
    
  }, error = function(e) {
    cat("Error processing year", year, ":", e$message, "\n")
  })
}

# Combine all performance data
performance_data <- do.call("rbind", performance_list)
performance_data <- performance_data %>% as_tibble()

cat("✓ Performance metrics calculated for", length(performance_years), "years\n")

# =============================================================================
# 4. INVESTMENT DATA PREPARATION
# =============================================================================

cat("\nStep 4: Preparing investment data...\n")

# Calculate investment summary
investment_summary <- round %>%
  group_by(firmname, year) %>%
  summarise(
    total_investments = n(),
    total_amount = sum(rndamt, na.rm = TRUE),
    avg_investment = mean(rndamt, na.rm = TRUE),
    .groups = "drop"
  )

# Calculate exit percentages
exit_percentages <- calculate_exit_percentages(performance_data, investment_summary)

cat("✓ Investment data prepared\n")

# =============================================================================
# 5. NETWORK CENTRALITY CALCULATION
# =============================================================================

cat("\nStep 5: Calculating network centrality...\n")

# Define network analysis parameters with data filtering option
if (exists("EXAMPLE_PARAMS") && EXAMPLE_PARAMS$use_limited_data) {
  network_years <- EXAMPLE_PARAMS$example_years
  cat("Using limited data for network analysis: years", min(network_years), "to", max(network_years), "\n")
} else {
  network_years <- 1980:2010
  cat("Using full data for network analysis: years", min(network_years), "to", max(network_years), "\n")
}
time_window_network <- 3
edge_cutpoint <- NETWORK_PARAMS$default_edge_cutpoint

# Calculate centrality for each year
centrality_list <- list()

for (year in network_years) {
  cat("Processing network for year:", year, "\n")
  
  tryCatch({
    centrality_data <- VC_centralities(round, year, time_window_network, edge_cutpoint)
    centrality_list[[as.character(year)]] <- centrality_data
  }, error = function(e) {
    cat("Error processing network for year", year, ":", e$message, "\n")
  })
}

# Combine centrality data
centrality_df <- do.call("rbind", centrality_list)
centrality_df <- centrality_df %>% as_tibble()

cat("✓ Network centrality calculated for", length(network_years), "years\n")

# =============================================================================
# 6. DIVERSITY ANALYSIS
# =============================================================================

cat("\nStep 6: Calculating portfolio diversity...\n")

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
# 7. PERFORMANCE SUMMARY BY VC TYPE
# =============================================================================

cat("\nStep 7: Analyzing performance by VC type...\n")

# Merge performance data with firm type information
performance_by_type <- performance_data %>%
  left_join(firmdta %>% select(firmname, firmtype2, firmtype3), by = "firmname") %>%
  left_join(investment_summary, by = c("firmname", "year")) %>%
  left_join(centrality_df, by = c("firmname", "year")) %>%
  left_join(diversity_data, by = c("firmname", "year"))

# Calculate performance summary by VC type
vc_type_performance <- calculate_performance_summary(performance_by_type, firmtype2)

# Calculate performance summary by IVC vs non-IVC
ivc_performance <- calculate_performance_summary(performance_by_type, firmtype3)

cat("✓ Performance analysis by VC type completed\n")

# =============================================================================
# 8. STATISTICAL TESTS
# =============================================================================

cat("\nStep 8: Running statistical tests...\n")

# Prepare data for statistical tests
test_data <- performance_by_type %>%
  filter(!is.na(firmtype2) & !is.na(exitNum)) %>%
  mutate(
    cvc_dummy = ifelse(firmtype2 == "CVC", 1, 0),
    ivc_dummy = ifelse(firmtype3 == "IVC", 1, 0)
  )

# Welch's t-test for CVC vs non-CVC
cvc_exit_test <- welch_t_test(test_data, cvc_dummy, "exitNum")
cvc_ipo_test <- welch_t_test(test_data, cvc_dummy, "ipoNum")
cvc_mna_test <- welch_t_test(test_data, cvc_dummy, "MnANum")

# Welch's t-test for IVC vs non-IVC
ivc_exit_test <- welch_t_test(test_data, ivc_dummy, "exitNum")
ivc_ipo_test <- welch_t_test(test_data, ivc_dummy, "ipoNum")
ivc_mna_test <- welch_t_test(test_data, ivc_dummy, "MnANum")

cat("✓ Statistical tests completed\n")

# =============================================================================
# 9. TIME SERIES ANALYSIS
# =============================================================================

cat("\nStep 9: Analyzing performance over time...\n")

# Calculate annual performance trends
annual_performance <- performance_data %>%
  group_by(year) %>%
  summarise(
    avg_exits = mean(exitNum, na.rm = TRUE),
    avg_ipos = mean(ipoNum, na.rm = TRUE),
    avg_mnas = mean(MnANum, na.rm = TRUE),
    total_exits = sum(exitNum, na.rm = TRUE),
    total_ipos = sum(ipoNum, na.rm = TRUE),
    total_mnas = sum(MnANum, na.rm = TRUE),
    num_firms = n(),
    .groups = "drop"
  )

# Calculate performance by decade
decade_performance <- performance_data %>%
  mutate(decade = floor(year / 10) * 10) %>%
  group_by(decade) %>%
  summarise(
    avg_exits = mean(exitNum, na.rm = TRUE),
    avg_ipos = mean(ipoNum, na.rm = TRUE),
    avg_mnas = mean(MnANum, na.rm = TRUE),
    total_exits = sum(exitNum, na.rm = TRUE),
    total_ipos = sum(ipoNum, na.rm = TRUE),
    total_mnas = sum(MnANum, na.rm = TRUE),
    num_firms = n(),
    .groups = "drop"
  )

cat("✓ Time series analysis completed\n")

# =============================================================================
# 10. CORRELATION ANALYSIS
# =============================================================================

cat("\nStep 10: Analyzing correlations...\n")

# Prepare correlation data
correlation_data <- performance_by_type %>%
  select(exitNum, ipoNum, MnANum, dgr, btw, pwr_max, cons_value, blau, total_investments, total_amount) %>%
  filter(complete.cases(.))

# Calculate correlation matrix
correlation_matrix <- cor(correlation_data, use = "complete.obs")

cat("✓ Correlation analysis completed\n")

# =============================================================================
# 11. RESULTS AND SUMMARY
# =============================================================================

cat("\nStep 11: Generating results and summary...\n")

# Summary statistics
cat("\n=== SUMMARY STATISTICS ===\n")
cat("Total observations:", nrow(performance_data), "\n")
cat("Analysis period:", min(performance_years), "-", max(performance_years), "\n")
cat("Time window for performance:", time_window, "years\n")
cat("Time window for network:", time_window_network, "years\n")

# Performance statistics
cat("\n=== PERFORMANCE STATISTICS ===\n")
cat("Average exits per VC:", mean(performance_data$exitNum, na.rm = TRUE), "\n")
cat("Average IPOs per VC:", mean(performance_data$ipoNum, na.rm = TRUE), "\n")
cat("Average M&As per VC:", mean(performance_data$MnANum, na.rm = TRUE), "\n")
cat("Total exits across all VCs:", sum(performance_data$exitNum, na.rm = TRUE), "\n")
cat("Total IPOs across all VCs:", sum(performance_data$ipoNum, na.rm = TRUE), "\n")
cat("Total M&As across all VCs:", sum(performance_data$MnANum, na.rm = TRUE), "\n")

# Network statistics
cat("\n=== NETWORK STATISTICS ===\n")
cat("Average degree centrality:", mean(centrality_df$dgr, na.rm = TRUE), "\n")
cat("Average betweenness centrality:", mean(centrality_df$btw, na.rm = TRUE), "\n")
cat("Average power centrality:", mean(centrality_df$pwr_max, na.rm = TRUE), "\n")
cat("Average constraint:", mean(centrality_df$cons_value, na.rm = TRUE), "\n")

# Diversity statistics
cat("\n=== DIVERSITY STATISTICS ===\n")
cat("Average Blau index:", mean(diversity_data$blau, na.rm = TRUE), "\n")
cat("Average portfolio diversity:", mean(portfolio_diversity$portfolio_diversity, na.rm = TRUE), "\n")

# VC type performance
cat("\n=== VC TYPE PERFORMANCE ===\n")
print(vc_type_performance)

# Statistical test results
cat("\n=== STATISTICAL TEST RESULTS ===\n")
cat("CVC vs Non-CVC Exit Test:\n")
print(cvc_exit_test)
cat("CVC vs Non-CVC IPO Test:\n")
print(cvc_ipo_test)
cat("CVC vs Non-CVC M&A Test:\n")
print(cvc_mna_test)

# Annual trends
cat("\n=== ANNUAL PERFORMANCE TRENDS ===\n")
cat("Average exits per year:", mean(annual_performance$avg_exits, na.rm = TRUE), "\n")
cat("Average IPOs per year:", mean(annual_performance$avg_ipos, na.rm = TRUE), "\n")
cat("Average M&As per year:", mean(annual_performance$avg_mnas, na.rm = TRUE), "\n")

# =============================================================================
# 12. SAVE RESULTS
# =============================================================================

cat("\nStep 12: Saving results...\n")

# Create timestamp for file naming
timestamp <- format(Sys.time(), "%y%m%d_%H%M")

# Create results directory structure
base_dir <- "/Users/suengj/Documents/Code/Python/Research/VC/rst"
perf_dir <- file.path(base_dir, "perf_rst")
if (!dir.exists(base_dir)) dir.create(base_dir, recursive = TRUE)
if (!dir.exists(perf_dir)) dir.create(perf_dir, recursive = TRUE)

# Save processed data with timestamp
write.csv(performance_data, file.path(perf_dir, paste0("performance_data_", timestamp, ".csv")), row.names = FALSE)
write.csv(exit_percentages, file.path(perf_dir, paste0("exit_percentages_", timestamp, ".csv")), row.names = FALSE)
write.csv(centrality_df, file.path(perf_dir, paste0("centrality_data_", timestamp, ".csv")), row.names = FALSE)
write.csv(diversity_data, file.path(perf_dir, paste0("diversity_data_", timestamp, ".csv")), row.names = FALSE)
write.csv(performance_by_type, file.path(perf_dir, paste0("performance_by_type_", timestamp, ".csv")), row.names = FALSE)
write.csv(vc_type_performance, file.path(perf_dir, paste0("vc_type_performance_", timestamp, ".csv")), row.names = FALSE)
write.csv(ivc_performance, file.path(perf_dir, paste0("ivc_performance_", timestamp, ".csv")), row.names = FALSE)
write.csv(annual_performance, file.path(perf_dir, paste0("annual_performance_", timestamp, ".csv")), row.names = FALSE)
write.csv(decade_performance, file.path(perf_dir, paste0("decade_performance_", timestamp, ".csv")), row.names = FALSE)
write.csv(correlation_matrix, file.path(perf_dir, paste0("correlation_matrix_", timestamp, ".csv")))

# Save statistical test results as CSV
test_results_df <- data.frame(
  test_name = c("cvc_exit_test", "cvc_ipo_test", "cvc_mna_test", "ivc_exit_test", "ivc_ipo_test", "ivc_mna_test"),
  t_statistic = c(cvc_exit_test$statistic, cvc_ipo_test$statistic, cvc_mna_test$statistic, 
                  ivc_exit_test$statistic, ivc_ipo_test$statistic, ivc_mna_test$statistic),
  p_value = c(cvc_exit_test$p.value, cvc_ipo_test$p.value, cvc_mna_test$p.value,
              ivc_exit_test$p.value, ivc_ipo_test$p.value, ivc_mna_test$p.value),
  df = c(cvc_exit_test$parameter, cvc_ipo_test$parameter, cvc_mna_test$parameter,
         ivc_exit_test$parameter, ivc_ipo_test$parameter, ivc_mna_test$parameter)
)
write.csv(test_results_df, file.path(perf_dir, paste0("statistical_tests_", timestamp, ".csv")), row.names = FALSE)

cat("✓ Results saved to performance results directory\n")

# =============================================================================
# 13. CLEANUP
# =============================================================================

cat("\nStep 13: Cleanup...\n")

# Remove temporary objects
rm(performance_list, centrality_list, industry_data, exit_data, investment_summary)

cat("✓ Analysis completed successfully!\n")
cat("\nFiles saved in perf_rst directory:\n")
cat("- performance_data_", timestamp, ".csv: VC performance metrics\n")
cat("- exit_percentages_", timestamp, ".csv: Exit percentages\n")
cat("- centrality_data_", timestamp, ".csv: Network centrality measures\n")
cat("- diversity_data_", timestamp, ".csv: Portfolio diversity measures\n")
cat("- performance_by_type_", timestamp, ".csv: Performance by VC type\n")
cat("- vc_type_performance_", timestamp, ".csv: Summary by VC type\n")
cat("- ivc_performance_", timestamp, ".csv: Summary by IVC vs non-IVC\n")
cat("- annual_performance_", timestamp, ".csv: Annual performance trends\n")
cat("- decade_performance_", timestamp, ".csv: Decade performance trends\n")
cat("- correlation_matrix_", timestamp, ".csv: Correlation matrix\n")
cat("- statistical_tests_", timestamp, ".csv: Statistical test results\n") 