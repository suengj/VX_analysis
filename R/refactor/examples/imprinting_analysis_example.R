# Imprinting Analysis Example Script
# Using Refactored VC Network Analysis Modules
# Based on imprinting_Dec18.R

# Set working directory to data location first
setwd("/Users/suengj/Documents/Code/Python/Research/VC/raw/extract")

# Load all modules and setup required packages (use absolute path to avoid path issues)
source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/load_all_modules.R")
modules <- quick_setup()  # This will install and load all required packages including reticulate

# Define constants if not loaded properly
if (!exists("EXIT_TYPES")) {
  EXIT_TYPES <- c("Went Public", "Merger", "Acquisition")
  cat("EXIT_TYPES defined locally\n")
}

#' Complete Imprinting Analysis Workflow
#' This example demonstrates the complete imprinting analysis process
#' using the refactored modules

# =============================================================================
# 1. DATA LOADING AND PREPROCESSING
# =============================================================================

cat("Step 1: Loading and preprocessing data...\n")

# Display system information and CPU usage limits
cat("System Information:\n")
cat("- Total CPU cores:", parallel::detectCores(), "\n")
if (exists("PARALLEL_PARAMS")) {
  cat("- CPU usage limit:", round(PARALLEL_PARAMS$capacity * 100), "%\n")
  cat("- Available cores for parallel processing:", PARALLEL_PARAMS$cores, "\n")
} else {
  cat("- CPU usage limit: 80% (default)\n")
  cat("- Available cores for parallel processing:", floor(parallel::detectCores() * 0.8), "\n")
}
cat("\n")

# Load data from .rds files
comdta <- readRDS('company_data.rds') %>% as_tibble()
firmdta <- readRDS('firm_data.rds') %>% as_tibble()
round <- readRDS("round_data_US.rds")

# Process company data
comdta <- comdta %>%
  # Date columns are already POSIXct format, just check for NA values
  mutate(exit = ifelse(comsitu %in% EXIT_TYPES & (!is.na(date_sit) | !is.na(date_ipo)), 1, 0)) %>%
  mutate(ipoExit = ifelse(comsitu %in% "Went Public" & (!is.na(date_sit) | !is.na(date_ipo)), 1, 0)) %>%
  mutate(MnAExit = ifelse(comsitu %in% c("Merger", "Acquisition") & !is.na(date_sit), 1, 0))

# Remove duplicates from comdta
comdta <- comdta %>%
  group_by(comname) %>%
  slice(1) %>%  # Keep only the first occurrence of each comname
  ungroup()

cat("✓ Company data processed. Unique companies:", n_distinct(comdta$comname), "\n")

# Process firm data
firmdta <- firmdta %>%
  # Founding date is already POSIXct format, extract year directly
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

# Remove duplicates from firmdta (following original logic)
firmdta <- firmdta %>%
  group_by(firmname) %>%
  slice(1) %>%  # Keep only the first occurrence of each firmname
  ungroup()

cat("✓ Firm data processed. Unique firms:", n_distinct(firmdta$firmname), "\n")

# Process round data
round <- round %>%
  filter(firmname != "Undisclosed Firm", comname != "Undisclosed Company") %>%
  # Round date is already POSIXct format, extract date components directly
  mutate(year = year(rnddate), month = month(rnddate), day = day(rnddate)) %>%
  filter(year > 1979) %>%
  # Create timewave (year or quarter) and event identifier
  mutate(
    quarter = ceiling(month / 3),
    timewave = year,  # Default to year, can be changed to quarter
    event = paste(comname, timewave, sep = "-")  # company-timewave combination
  )

# Merge firm information step by step (following original CVC_preprcs_v4.R logic)
# Step 1: Merge firm nation
round <- left_join(round, firmdta %>% select(firmname, firmnation) %>% unique(), by="firmname")
round <- left_join(round, comdta %>% select(comname, comnation) %>% unique(), by="comname")

# Filter US cases only
round <- round %>%
  filter_at(vars(firmnation, comnation), all_vars(!is.na(.)))

# Step 2: Merge firm type
round <- left_join(round, firmdta %>% select(firmname, firmtype2, firmtype3) %>% unique(), by="firmname")

# Filter out Angel groups
round <- round %>%
  filter(!firmtype2 %in% c("Angel"))

cat("✓ Data loaded successfully\n")

# =============================================================================
# 2. INITIAL YEAR IDENTIFICATION
# =============================================================================

cat("\nStep 2: Identifying initial years for firms...\n")

# Create initial year data
initial_year_data <- round %>%
  group_by(firmname) %>%
  summarise(initial_year = min(year), .groups = "drop") %>%
  filter(initial_year >= 1970 & initial_year <= 2010)

# Validate initial year logic
cat("Initial year validation:\n")
cat("Initial year range:", range(initial_year_data$initial_year), "\n")
cat("Initial year distribution:\n")
print(table(cut(initial_year_data$initial_year, breaks = seq(1970, 2010, 5))))

cat("✓ Initial years identified for", nrow(initial_year_data), "firms\n")

# =============================================================================
# 3. NETWORK CENTRALITY CALCULATION (OPTIMIZED)
# =============================================================================

cat("\nStep 3: Calculating network centrality for different time windows (optimized)...\n")

# Define analysis parameters with data filtering option
if (exists("EXAMPLE_PARAMS") && EXAMPLE_PARAMS$use_limited_data) {
  analysis_years <- EXAMPLE_PARAMS$example_years
  cat("Using limited data for example: years", min(analysis_years), "to", max(analysis_years), "\n")
} else {
  analysis_years <- 1970:2010
  cat("Using full data: years", min(analysis_years), "to", max(analysis_years), "\n")
}

time_windows <- c(1, 3, 5)
edge_cutpoint <- NETWORK_PARAMS$default_edge_cutpoint

# Use optimized vectorized calculation
centrality_list <- list()

for (tw in time_windows) {
  cat("Processing time window:", tw, "years\n")
  
  # Use vectorized calculation with progress tracking
  tw_centrality_data <- time_execution({
    vectorized_centrality_calculation(round, analysis_years, tw, edge_cutpoint, use_parallel = TRUE)
  }, paste0("Centrality calculation for ", tw, "-year window"))
  
  if (nrow(tw_centrality_data$result) > 0) {
    tw_centrality_data$result$time_window <- tw
    centrality_list[[paste0("_", tw, "y")]] <- tw_centrality_data$result
  }
}

# Combine all centrality data
if (length(centrality_list) > 0) {
  centrality_df <- do.call("rbind", centrality_list)
  centrality_df <- centrality_df %>% as_tibble()
  
  # Ensure time_window column exists
  if (!"time_window" %in% colnames(centrality_df)) {
    cat("Warning: time_window column not found, adding it...\n")
    centrality_df$time_window <- rep(time_windows, each = nrow(centrality_df) / length(time_windows))
  }
} else {
  cat("Warning: No centrality data generated\n")
  centrality_df <- data.frame() %>% as_tibble()
}

cat("✓ Network centrality calculated for", length(time_windows), "time windows\n")

# Debug: Check centrality_df structure
cat("Debug: centrality_df dimensions:", dim(centrality_df), "\n")
cat("Debug: centrality_df columns:", colnames(centrality_df), "\n")
if (nrow(centrality_df) > 0) {
  cat("Debug: centrality_df time_window values:", unique(centrality_df$time_window), "\n")
}

# =============================================================================
# 4. INITIAL TIES IDENTIFICATION
# =============================================================================

cat("\nStep 4: Identifying initial network ties...\n")

# Define imprinting period
imprinting_period <- 3

# Calculate initial ties correctly
cat("Calculating initial ties for", length(unique(round$year)), "years...\n")

# Fix the initial ties calculation logic
initial_ties <- round %>%
  # Join with initial year data first
  left_join(initial_year_data, by = "firmname") %>%
  # Only consider ties that occur after or at the initial year
  filter(year >= initial_year) %>%
  # Group by firm and get the first tie for each firm
  group_by(firmname) %>%
  # Get the earliest tie for each firm (this is the initial tie)
  filter(year == min(year)) %>%
  # Get all ties in that initial year
  group_by(firmname, comname, year, initial_year) %>%
  summarise(.groups = "drop") %>%
  # Rename year to tied_year for clarity
  rename(tied_year = year) %>%
  # Add initial partner information
  group_by(firmname) %>%
  mutate(initial_partner = first(comname)) %>%
  ungroup()

# Ensure initial_year column exists
if (!"initial_year" %in% colnames(initial_ties)) {
  cat("ERROR: initial_year column missing from initial_ties\n")
  cat("Available columns:", colnames(initial_ties), "\n")
  stop("initial_year column is required")
}

cat("Initial ties calculation completed\n")

# Initial year information is already included from the previous step
# No need to join again

# Validate initial year vs tied year logic
cat("Initial year vs tied year validation:\n")
cat("Total ties:", nrow(initial_ties), "\n")
cat("Initial year <= tied year:", sum(initial_ties$initial_year <= initial_ties$tied_year, na.rm = TRUE), "\n")
cat("Initial year > tied year (ERROR):", sum(initial_ties$initial_year > initial_ties$tied_year, na.rm = TRUE), "\n")

# Check for logical errors
if (sum(initial_ties$initial_year > initial_ties$tied_year, na.rm = TRUE) > 0) {
  cat("ERROR: Found", sum(initial_ties$initial_year > initial_ties$tied_year, na.rm = TRUE), "cases where initial_year > tied_year\n")
  cat("This violates the definition that initial_year should be the first networking year\n")
  # Show sample of problematic cases
  problematic_cases <- initial_ties %>% 
    filter(initial_year > tied_year) %>% 
    head(5)
  cat("Sample problematic cases:\n")
  print(problematic_cases)
}

cat("✓ Initial ties identified for", nrow(initial_ties), "connections\n")

# =============================================================================
# 5. IMPRINTING PERIOD FILTERING
# =============================================================================

cat("\nStep 5: Filtering by imprinting period...\n")

# Filter initial ties by imprinting period
initial_partner_list <- VC_initial_period(initial_ties, imprinting_period)

cat("✓ Filtered to", nrow(initial_partner_list), "imprinting period connections\n")

# =============================================================================
# 6. PARTNER CENTRALITY CALCULATION
# =============================================================================

cat("\nStep 6: Calculating initial partner centrality...\n")

# Calculate partner centrality for different time windows
partner_centrality_list <- list()

for (tw in time_windows) {
  cat("Processing partner centrality for", tw, "year window\n")
  
  # Debug: Check centrality_df before filtering
  cat("Debug: centrality_df columns before filter:", colnames(centrality_df), "\n")
  cat("Debug: centrality_df nrow before filter:", nrow(centrality_df), "\n")
  
  # Filter centrality data for time window
  cent_tw <- centrality_df %>% 
    filter(time_window == tw) %>%
    select(-time_window)
  
  # Calculate partner centrality
  partner_centrality_list[[paste0(tw, "y")]] <- 
    VC_initial_partner_centrality(initial_partner_list, cent_tw)
}

# Combine partner centrality data (fixed left_join error with explicit column naming)
if (length(partner_centrality_list) > 0) {
  partner_centrality <- partner_centrality_list[[1]]
  if (length(partner_centrality_list) > 1) {
    for (i in 2:length(partner_centrality_list)) {
      # Use explicit suffix to avoid .x/.y conflicts
      partner_centrality <- left_join(partner_centrality, partner_centrality_list[[i]], 
                                     by = c("firmname", "tied_year"),
                                     suffix = c("", paste0("_", names(partner_centrality_list)[i])))
    }
  }
  
  # Rename columns to avoid confusion and ensure consistency
  # Use explicit column renaming instead of rename_with
  # Check if column already has prefix to avoid double underscores
  colnames_to_rename <- grep("^(dgr_cent|btw_cent|pwr_|constraint_value|ego_density)", colnames(partner_centrality), value = TRUE)
  for (col in colnames_to_rename) {
    # Only add prefix if it doesn't already have one
    if (!grepl("^[pf]_", col)) {
      new_name <- paste0("p_", col)
      colnames(partner_centrality)[colnames(partner_centrality) == col] <- new_name
    }
  }
} else {
  partner_centrality <- data.frame()
}

cat("✓ Partner centrality calculated for", length(time_windows), "time windows\n")

# =============================================================================
# 7. FOCAL FIRM CENTRALITY CALCULATION
# =============================================================================

cat("\nStep 7: Calculating focal firm centrality...\n")

# Calculate focal firm centrality for different time windows
focal_centrality_list <- list()

for (tw in time_windows) {
  cat("Processing focal centrality for", tw, "year window\n")
  
  # Filter centrality data for time window
  cent_tw <- centrality_df %>% 
    filter(time_window == tw) %>%
    select(-time_window)
  
  # Calculate focal centrality
  focal_centrality_list[[paste0(tw, "y")]] <- 
    VC_initial_focal_centrality(initial_partner_list, cent_tw)
}

# Combine focal centrality data (fixed left_join error with explicit column naming)
if (length(focal_centrality_list) > 0) {
  focal_centrality <- focal_centrality_list[[1]]
  if (length(focal_centrality_list) > 1) {
    for (i in 2:length(focal_centrality_list)) {
      # Use explicit suffix to avoid .x/.y conflicts
      focal_centrality <- left_join(focal_centrality, focal_centrality_list[[i]], 
                                   by = c("firmname", "tied_year"),
                                   suffix = c("", paste0("_", names(focal_centrality_list)[i])))
    }
  }
  
  # Rename columns to avoid confusion and ensure consistency
  # Use explicit column renaming instead of rename_with
  # Check if column already has prefix to avoid double underscores
  colnames_to_rename <- grep("^(dgr_cent|btw_cent|pwr_|constraint_value|ego_density)", colnames(focal_centrality), value = TRUE)
  for (col in colnames_to_rename) {
    # Only add prefix if it doesn't already have one
    if (!grepl("^[pf]_", col)) {
      new_name <- paste0("f_", col)
      colnames(focal_centrality)[colnames(focal_centrality) == col] <- new_name
    }
  }
} else {
  focal_centrality <- data.frame()
}

cat("✓ Focal firm centrality calculated for", length(time_windows), "time windows\n")

# =============================================================================
# 8. PERFORMANCE DATA PREPARATION
# =============================================================================

cat("\nStep 8: Preparing performance data...\n")

# Create exit data
exit_data <- create_exit_data(comdta)

# Validate exit data
cat("Exit data validation:\n")
cat("Exit years range:", range(exit_data$situ_yr, na.rm = TRUE), "\n")
cat("Total companies with exit:", sum(exit_data$exit == 1, na.rm = TRUE), "\n")

# Filter out unrealistic exit years
exit_data <- exit_data %>%
  filter(situ_yr >= 1970 & situ_yr <= 2020)

cat("After filtering unrealistic years:\n")
cat("Exit years range:", range(exit_data$situ_yr, na.rm = TRUE), "\n")
cat("Total companies with exit:", sum(exit_data$exit == 1, na.rm = TRUE), "\n")

# Calculate performance metrics
performance_years <- 1975:2010
performance_data <- calculate_performance_metrics(round, comdta, performance_years, time_window = 5)

# Calculate investment amounts (using correct column names)
investment_data <- round %>%
  group_by(firmname, year) %>%
  summarise(
    InvestAMT = sum(rndamt_disclosed, na.rm = TRUE) + sum(rndamt_estimated, na.rm = TRUE),
    NumInvestments = n(),
    .groups = "drop"
  )

cat("✓ Performance data prepared\n")

# =============================================================================
# 9. IMPRINTING DATASET CREATION
# =============================================================================

cat("\nStep 9: Creating comprehensive imprinting dataset...\n")

# Merge all imprinting data (fix column matching)
cat("Starting comprehensive merge...\n")

# Step 1: Merge partner centrality
cat("Step 1: Merging partner centrality...\n")
imprinting_dataset <- initial_partner_list %>%
  left_join(partner_centrality, by = c("firmname", "tied_year"))

cat("After partner centrality merge:", nrow(imprinting_dataset), "rows\n")
cat("Non-zero centrality values:", sum(imprinting_dataset$p_dgr_cent > 0, na.rm = TRUE), "\n")

# Step 2: Merge focal centrality
cat("Step 2: Merging focal centrality...\n")
imprinting_dataset <- imprinting_dataset %>%
  left_join(focal_centrality, by = c("firmname", "tied_year"))

cat("After focal centrality merge:", nrow(imprinting_dataset), "rows\n")
cat("Non-zero focal centrality values:", sum(imprinting_dataset$f_dgr_cent > 0, na.rm = TRUE), "\n")

# Step 3: Add year column and merge performance data
cat("Step 3: Merging performance data...\n")
imprinting_dataset <- imprinting_dataset %>%
  mutate(year = tied_year) %>%
  left_join(performance_data, by = c("firmname", "year"))

cat("After performance data merge:", nrow(imprinting_dataset), "rows\n")
cat("Non-zero performance values:", sum(imprinting_dataset$exitNum > 0, na.rm = TRUE), "\n")

# Step 4: Merge investment data
cat("Step 4: Merging investment data...\n")
imprinting_dataset <- imprinting_dataset %>%
  left_join(investment_data, by = c("firmname", "year"))

cat("After investment data merge:", nrow(imprinting_dataset), "rows\n")
cat("Non-zero investment values:", sum(imprinting_dataset$InvestAMT > 0, na.rm = TRUE), "\n")

# Step 5: Add derived variables
cat("Step 5: Adding derived variables...\n")
imprinting_dataset <- imprinting_dataset %>%
  mutate(
    initial_partner_num = n_distinct(initial_partner, na.rm = TRUE),
    timesince = tied_year - initial_year
  )

cat("Final dataset validation:\n")
cat("Total rows:", nrow(imprinting_dataset), "\n")
cat("Rows with any centrality data:", sum(!is.na(imprinting_dataset$p_dgr_cent) | !is.na(imprinting_dataset$f_dgr_cent)), "\n")
cat("Rows with performance data:", sum(!is.na(imprinting_dataset$exitNum)), "\n")
cat("Rows with investment data:", sum(!is.na(imprinting_dataset$InvestAMT)), "\n")

# Add diversity measures (using correct industry columns from company data)
industry_data <- round %>%
  left_join(comdta %>% select(comname, comindmnr), by = "comname") %>%
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

diversity_data <- blau_index(industry_data)

imprinting_dataset <- imprinting_dataset %>%
  left_join(diversity_data, by = c("firmname", "year"))

cat("✓ Comprehensive imprinting dataset created with", nrow(imprinting_dataset), "observations\n")
cat("Debug: imprinting_dataset columns:", colnames(imprinting_dataset), "\n")
cat("Debug: imprinting_dataset dimensions:", dim(imprinting_dataset), "\n")

# =============================================================================
# 10. REGRESSION ANALYSIS
# =============================================================================

cat("\nStep 10: Running imprinting regression analysis...\n")

# Prepare data for regression (fix column name)
regression_data <- imprinting_dataset %>%
  filter(!is.na(exitNum) & !is.na(initial_year)) %>%
  mutate(
    CAMA = ifelse(year >= 2000, 1, 0),  # Dot-com bubble period
    earlyStage = 1,  # Placeholder for early stage investments
    blau = ifelse(is.na(blau), 0, blau)
  )

# Create panel data
panel_data <- create_panel_data(regression_data)

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
# 11. IMPRINTING EFFECTS ANALYSIS
# =============================================================================

cat("\nStep 11: Analyzing imprinting effects...\n")

# Calculate imprinting effect measures
imprinting_effects <- calculate_imprinting_effects(imprinting_dataset, performance_data)

# Summary statistics for imprinting effects
cat("\n=== IMPRINTING EFFECTS SUMMARY ===\n")
cat("Average initial partner count:", mean(imprinting_effects$initial_partner_count, na.rm = TRUE), "\n")
cat("Average partner degree centrality:", mean(imprinting_effects$avg_partner_degree, na.rm = TRUE), "\n")
cat("Average partner betweenness centrality:", mean(imprinting_effects$avg_partner_betweenness, na.rm = TRUE), "\n")
cat("Average partner power centrality:", mean(imprinting_effects$avg_partner_power, na.rm = TRUE), "\n")
cat("Average focal firm degree centrality:", mean(imprinting_effects$focal_degree, na.rm = TRUE), "\n")
cat("Average focal firm betweenness centrality:", mean(imprinting_effects$focal_betweenness, na.rm = TRUE), "\n")
cat("Average focal firm power centrality:", mean(imprinting_effects$focal_power, na.rm = TRUE), "\n")

# =============================================================================
# 12. ROBUSTNESS CHECKS
# =============================================================================

cat("\nStep 12: Running robustness checks...\n")

# Define robustness specifications
robustness_specs <- list(
  list(type = "subsample", condition = year >= 1990, model_type = "H1"),
  list(type = "subsample", condition = year <= 2000, model_type = "H1"),
  list(type = "alternative_spec", model_type = "H0")
)

# Run robustness checks
robustness_results <- run_robustness_checks(regression_data, imprinting_models$H1, robustness_specs)

cat("✓ Robustness checks completed\n")

# =============================================================================
# 13. RESULTS AND SUMMARY
# =============================================================================

cat("\nStep 13: Generating results and summary...\n")

# Summary statistics
cat("\n=== SUMMARY STATISTICS ===\n")
cat("Total observations:", nrow(regression_data), "\n")
cat("Firms with imprinting data:", n_distinct(imprinting_dataset$firmname), "\n")
cat("Analysis period:", min(analysis_years), "-", max(analysis_years), "\n")
cat("Imprinting period:", imprinting_period, "years\n")

# Network statistics
cat("\n=== NETWORK STATISTICS ===\n")
cat("Average partner degree centrality (1y):", mean(imprinting_dataset$p_dgr_1y, na.rm = TRUE), "\n")
cat("Average partner betweenness centrality (1y):", mean(imprinting_dataset$p_btw_1y, na.rm = TRUE), "\n")
cat("Average partner power centrality (5y):", mean(imprinting_dataset$p_pwr_max_5y, na.rm = TRUE), "\n")
cat("Average focal firm degree centrality (1y):", mean(imprinting_dataset$f_dgr_1y, na.rm = TRUE), "\n")
cat("Average focal firm betweenness centrality (1y):", mean(imprinting_dataset$f_btw_1y, na.rm = TRUE), "\n")
cat("Average focal firm power centrality (5y):", mean(imprinting_dataset$f_pwr_max_5y, na.rm = TRUE), "\n")

# Performance statistics
cat("\n=== PERFORMANCE STATISTICS ===\n")
cat("Average exits per firm:", mean(imprinting_dataset$exitNum, na.rm = TRUE), "\n")
cat("Average investment amount:", mean(imprinting_dataset$InvestAMT, na.rm = TRUE), "\n")
cat("Average portfolio diversity (Blau index):", mean(imprinting_dataset$blau, na.rm = TRUE), "\n")

# Model results
cat("\n=== REGRESSION RESULTS ===\n")
for (model_name in names(imprinting_models)) {
  cat("\nModel:", model_name, "\n")
  print(summary(imprinting_models[[model_name]]))
}

# =============================================================================
# 14. SAVE RESULTS
# =============================================================================

cat("\nStep 14: Saving results...\n")

# Create timestamp for file naming
timestamp <- format(Sys.time(), "%y%m%d_%H%M")

# Create results directory structure
base_dir <- "/Users/suengj/Documents/Code/Python/Research/VC/rst"
imprint_dir <- file.path(base_dir, "imprint_rst")
if (!dir.exists(base_dir)) dir.create(base_dir, recursive = TRUE)
if (!dir.exists(imprint_dir)) dir.create(imprint_dir, recursive = TRUE)

# Save processed data with timestamp
write.csv(imprinting_dataset, file.path(imprint_dir, paste0("imprinting_dataset_", timestamp, ".csv")), row.names = FALSE)
write.csv(imprinting_effects, file.path(imprint_dir, paste0("imprinting_effects_", timestamp, ".csv")), row.names = FALSE)
write.csv(initial_ties, file.path(imprint_dir, paste0("initial_ties_", timestamp, ".csv")), row.names = FALSE)
write.csv(initial_partner_list, file.path(imprint_dir, paste0("initial_partner_list_", timestamp, ".csv")), row.names = FALSE)
write.csv(partner_centrality, file.path(imprint_dir, paste0("partner_centrality_", timestamp, ".csv")), row.names = FALSE)
write.csv(focal_centrality, file.path(imprint_dir, paste0("focal_centrality_", timestamp, ".csv")), row.names = FALSE)
write.csv(centrality_df, file.path(imprint_dir, paste0("centrality_data_", timestamp, ".csv")), row.names = FALSE)

# Save model results as CSV for cross-platform compatibility
for (model_name in names(imprinting_models)) {
  model_summary <- summary(imprinting_models[[model_name]])
  model_coef <- as.data.frame(model_summary$coefficients)
  write.csv(model_coef, file.path(imprint_dir, paste0("imprinting_model_", model_name, "_", timestamp, ".csv")), row.names = TRUE)
}

# Save robustness results
if (length(robustness_results) > 0) {
  write.csv(robustness_results, file.path(imprint_dir, paste0("robustness_results_", timestamp, ".csv")), row.names = FALSE)
}

cat("✓ Results saved to imprinting results directory\n")

# =============================================================================
# 15. CLEANUP
# =============================================================================

cat("\nStep 15: Cleanup...\n")

# Remove temporary objects
rm(centrality_list, initial_ties_list, partner_centrality_list, focal_centrality_list,
   industry_data, diversity_data, exit_data, investment_data, performance_data)

cat("✓ Analysis completed successfully!\n")
cat("\nFiles saved in imprint_rst directory:\n")
cat("- imprinting_dataset_", timestamp, ".csv: Complete imprinting analysis dataset\n")
cat("- imprinting_effects_", timestamp, ".csv: Imprinting effect measures\n")
cat("- initial_ties_", timestamp, ".csv: Initial network ties\n")
cat("- initial_partner_list_", timestamp, ".csv: Filtered initial partner list\n")
cat("- partner_centrality_", timestamp, ".csv: Initial partner centrality measures\n")
cat("- focal_centrality_", timestamp, ".csv: Focal firm centrality measures\n")
cat("- centrality_data_", timestamp, ".csv: Network centrality measures\n")
cat("- imprinting_model_*.csv: Regression model coefficients\n")
cat("- robustness_results_", timestamp, ".csv: Robustness check results\n") 