# Imprinting Flow - Full Testing Script
# Created: 2025-10-11
# Purpose: Test complete imprinting analysis pipeline from raw data to statistical results

# ================================
# SETUP
# ================================

# Clear workspace
rm(list = ls())
gc()

# Load required packages
cat("Loading required packages...\n")
library(igraph)
library(data.table)
library(tidyverse)
library(lubridate)
library(readxl)
library(progress)
library(doParallel)
library(foreach)
library(plm)
library(psych)
library(broom)

# Try to load pglm (may not be available)
if(require('pglm', quietly = TRUE)) {
  library(pglm)
  cat("✅ pglm loaded\n")
} else {
  cat("⚠️ pglm not available - will use plm alternatives\n")
}

cat("All packages loaded successfully!\n\n")

# Set working directory to refactor folder
setwd("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor")
cat("Working directory:", getwd(), "\n\n")

# Source refactored modules
cat("Sourcing refactored modules...\n")
source("R/config/paths.R")
source("R/config/constants.R")
source("R/core/network_construction.R")
source("R/core/centrality_calculation.R")
source("R/analysis/imprinting_analysis.R")
source("R/utils/error_handler.R")
source("R/utils/checkpoint.R")

cat("All modules sourced successfully!\n\n")

# Setup parallel processing
capacity <- 0.8
cores <- round(parallel::detectCores() * capacity, digits = 0)
registerDoParallel(cores = cores)
cat("Parallel processing setup:", cores, "cores\n\n")

# Define output directories
output_dir <- "/Users/suengj/Documents/Code/Python/Research/VC/refactor_v2/testing/imprinting_flow"
data_dir <- file.path(output_dir, "data")
results_dir <- file.path(output_dir, "results")
log_dir <- file.path(output_dir, "logs")
checkpoint_dir <- file.path(output_dir, "checkpoints")

# Create error log
error_log <- create_error_log(log_dir, prefix = "imprinting_error")
cat("Error log created:", error_log, "\n\n")

# Define imprinting period
imprinting_period <- 3  # 3-year imprinting period

# Define data paths
base_dir <- "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Yang, Rhee, Ma/data"

# ================================
# STEP 1: DATA LOADING
# ================================

cat("=", rep("=", 60), "\n", sep = "")
cat("STEP 1: LOADING RAW DATA\n")
cat("=", rep("=", 60), "\n\n", sep = "")

start_time <- Sys.time()

# Load company data
cat("Loading company data...\n")
comdta <- read.csv(file.path(base_dir, "new/comdta_new.csv")) %>% as_tibble() %>%
  mutate(date_sit = as.Date(date_sit)) %>%
  mutate(exit = ifelse(comsitu %in% c("Went Public","Merger","Acquisition") & (!is.na(date_sit) | !is.na(date_ipo)),1,0)) %>%
  mutate(ipoExit = ifelse(comsitu %in% c("Went Public") & (!is.na(date_sit) | !is.na(date_ipo)),1,0)) %>%
  mutate(MnAExit = ifelse(comsitu %in% c("Merger","Acquisition") & !is.na(date_sit),1,0))
cat("  - Rows:", nrow(comdta), "\n")

cat("Loading firm data...\n")
firmdta <- read_excel(file.path(base_dir, "new/firmdta_all.xlsx")) %>% as_tibble() %>%
  mutate(fnd_year = year(firmfounding)) %>%
  mutate(firmtype2 = case_when(firmtype %in% c("Angel Group","Individuals") ~ "Angel",
                               firmtype %in% c("Corporate PE/Venture")~ "CVC",
                               firmtype %in% c("Investment Management Firm", "Bank Affiliated",
                                              "Private Equity Advisor or Fund of Funds",
                                              "SBIC","Endowment, Foundation or Pension Fund",
                                              "Other Financial Institution","Private Equity Firm",
                                              "Hedge Fund (Fund of Funds)") ~ "IVC",
                               TRUE ~ "Others"))
cat("  - Rows:", nrow(firmdta), "\n")

cat("Loading round data...\n")
round <- read.csv(file.path(base_dir, "Mar25/round_Mar25.csv")) %>% as_tibble() %>%
  filter(firmname != "Undisclosed Firm") %>%
  filter(comname != "Undisclosed Company") %>%
  mutate(rnddate = as.Date(rnddate, origin="1899-12-30")) %>%
  mutate(year = year(rnddate),
         month = month(rnddate),
         day = day(rnddate))
cat("  - Rows:", nrow(round), "\n")

cat("Loading fund data...\n")
funddta <- read_excel(file.path(base_dir, "new/fund_all.xlsx")) %>% as_tibble()
cat("  - Rows:", nrow(funddta), "\n\n")

end_time <- Sys.time()
cat("Data loading completed in", round(difftime(end_time, start_time, units = "secs"), 2), "seconds\n\n")

# Save checkpoint
checkpoint_save("01_raw_data", list(comdta = comdta, firmdta = firmdta, round = round, funddta = funddta), 
                checkpoint_dir = checkpoint_dir)

# ================================
# STEP 2: DATA PREPROCESSING
# ================================

cat("=", rep("=", 60), "\n", sep = "")
cat("STEP 2: DATA PREPROCESSING\n")
cat("=", rep("=", 60), "\n\n", sep = "")

start_time <- Sys.time()

# Filter by year (1980-2000 for reduced memory usage)
min_year <- 1980
max_year <- 2000

cat("Filtering by year range (", min_year, "-", max_year, ")...\n", sep = "")
round <- round %>% filter(year >= min_year, year <= max_year)
cat("  - Rows after filtering:", nrow(round), "\n\n")

# Filter US only (both firm and company must be US)
cat("Filtering US cases only...\n")
ini_round <- nrow(round)

round <- round %>%
  left_join(firmdta %>% select(firmname, firmnation) %>% unique(), by = "firmname") %>%
  left_join(comdta %>% select(comname, comnation) %>% unique(), by = "comname") %>%
  filter(!is.na(firmnation), !is.na(comnation))

fin_round <- nrow(round)
cat("  - Rows removed (non-US):", ini_round - fin_round, "(",
    round((ini_round - fin_round) / ini_round * 100, 2), "%)\n")
cat("  - Rows remaining:", fin_round, "\n\n")

# Exclude Angel
cat("Excluding Angel groups...\n")
round <- round %>%
  left_join(firmdta %>% select(firmname, firmtype2) %>% unique(), by = "firmname") %>%
  filter(!firmtype2 %in% c("Angel"))
cat("  - Rows after Angel exclusion:", nrow(round), "\n\n")

# Exclude negative firm age
cat("Excluding negative firm age...\n")
round <- round %>%
  left_join(firmdta %>% select(firmname, firmfounding) %>% unique(), by = "firmname") %>%
  mutate(firmage = year - year(firmfounding)) %>%
  filter(firmage >= 0)
cat("  - Rows after age filter:", nrow(round), "\n\n")

# Create quarter column
cat("Creating quarter identifiers...\n")
round <- round %>%
  mutate(
    month = month(rnddate),
    quarter = ifelse(month < 4, paste0(as.character(year), "1Q"),
                    ifelse(month < 8 & month >= 4, paste0(as.character(year), "2Q"),
                           ifelse(month < 10 & month >= 8, paste0(as.character(year), "3Q"),
                                  paste0(as.character(year), "4Q"))))
  )
cat("  - Unique quarters:", length(unique(round$quarter)), "\n\n")

# Create event column for network analysis
cat("Creating event identifiers...\n")
round <- round %>%
  mutate(event = paste(comname, year, sep = "-"))
cat("  - Unique events:", length(unique(round$event)), "\n\n")

# Clean up duplicate columns from multiple joins
cat("Cleaning up duplicate columns...\n")
round <- round %>%
  select(-ends_with(".x"), -ends_with(".y")) %>%
  select(comname, firmname, year, month, day, rnddate, quarter, event, everything())

cat("  - Final columns:", ncol(round), "\n\n")

# Create edge data for network analysis
cat("Creating edge data...\n")

# For VC_initial_ties (bipartite: firm-company)
edge_raw <- round %>%
  select(firmname, comname, year) %>%
  distinct()

# For VC_centralities (bipartite: firm-event)
edgeRound <- round %>%
  select(firmname, year, event) %>%
  distinct()

cat("Edge data created:\n")
cat("  - edge_raw (for initial ties): ", nrow(edge_raw), "rows\n")
cat("    - Unique firms:", length(unique(edge_raw$firmname)), "\n")
cat("    - Unique companies:", length(unique(edge_raw$comname)), "\n")
cat("  - edgeRound (for centrality): ", nrow(edgeRound), "rows\n")
cat("    - Unique firms:", length(unique(edgeRound$firmname)), "\n")
cat("    - Unique events:", length(unique(edgeRound$event)), "\n\n")

# Save preprocessed data
cat("Saving preprocessed data...\n")
write.csv(round, file.path(data_dir, "round_preprocessed.csv"), row.names = FALSE)
write.csv(edge_raw, file.path(data_dir, "edge_raw.csv"), row.names = FALSE)

end_time <- Sys.time()
cat("Preprocessing completed in", round(difftime(end_time, start_time, units = "secs"), 2), "seconds\n\n")

# Save checkpoint
checkpoint_save("02_preprocessed_data", list(round = round, edge_raw = edge_raw), 
                checkpoint_dir = checkpoint_dir)

# ================================
# STEP 3: IDENTIFY INITIAL TIES
# ================================

cat("=", rep("=", 60), "\n", sep = "")
cat("STEP 3: IDENTIFYING INITIAL TIES\n")
cat("=", rep("=", 60), "\n\n", sep = "")

start_time <- Sys.time()

# Calculate initial ties using VC_initial_ties function
cat("Calculating initial ties (", imprinting_period, "-year window)...\n", sep = "")
cat("This may take several minutes...\n\n")

# Use parallel processing
initial_raw <- foreach(y = min_year:max_year,
                      .combine = rbind,
                      .packages = c("dplyr", "igraph")) %dopar% {
  VC_initial_ties(edge_raw, y, imprinting_period)
}

# Rename columns to match expected names
colnames(initial_raw) <- c("firmname", "initial_partner", "tied_year")

cat("Initial ties calculated:\n")
cat("  - Total rows:", nrow(initial_raw), "\n")
cat("  - Unique firms:", length(unique(initial_raw$firmname)), "\n")
cat("  - Year range:", min(initial_raw$tied_year), "-", max(initial_raw$tied_year), "\n\n")

# Get initial year for each firm (first year with ties)
initial_partner_list <- initial_raw %>%
  group_by(firmname) %>%
  mutate(initial_year = min(tied_year)) %>%
  ungroup()

cat("Initial year identified:\n")
cat("  - Firms with initial year:", length(unique(initial_partner_list$firmname)), "\n\n")

# Save initial ties data
write.csv(initial_partner_list, file.path(data_dir, "initial_ties_data.csv"), row.names = FALSE)

end_time <- Sys.time()
cat("Initial ties identification completed in", round(difftime(end_time, start_time, units = "mins"), 2), "minutes\n\n")

# Save checkpoint
checkpoint_save("03_initial_ties", initial_partner_list, checkpoint_dir = checkpoint_dir)

# ================================
# STEP 4: CALCULATE CENTRALITY (1Y, 3Y, 5Y)
# ================================

cat("=", rep("=", 60), "\n", sep = "")
cat("STEP 4: CALCULATING NETWORK CENTRALITY\n")
cat("=", rep("=", 60), "\n\n", sep = "")

# Define time windows for centrality calculation
time_windows <- c(1, 3, 5)

for (tw in time_windows) {
  cat(sprintf("\n--- Calculating %d-year centrality ---\n", tw))
  start_time <- Sys.time()
  
  # Get unique years
  years <- unique(edgeRound$year)
  years <- years[years >= min(years) + tw - 1]  # Ensure enough history
  
  cat("Years to process:", length(years), "\n\n")
  
  # Parallel centrality calculation
  centrality_list <- foreach(y = years,
                             .combine = c,
                             .packages = c("igraph", "data.table")) %dopar% {
    result <- VC_centralities(edgeRound, y, time_window = tw, edge_cutpoint = NULL)
    list(result)
  }
  
  # Combine results
  cent <- do.call("rbind", centrality_list)
  
  cat(sprintf("\n%d-year centrality calculated:\n", tw))
  cat("  - Total rows:", nrow(cent), "\n")
  cat("  - Unique firms:", length(unique(cent$firmname)), "\n")
  cat("  - Year range:", min(cent$year), "-", max(cent$year), "\n\n")
  
  # Save centrality data
  write.csv(cent, file.path(data_dir, sprintf("centrality_%dy.csv", tw)), row.names = FALSE)
  
  # Save checkpoint
  checkpoint_save(sprintf("04_centrality_%dy", tw), cent, checkpoint_dir = checkpoint_dir)
  
  end_time <- Sys.time()
  cat(sprintf("%d-year centrality completed in %.2f minutes\n\n", tw, 
             difftime(end_time, start_time, units = "mins")))
}

# For subsequent steps, use 3-year centrality
cent <- read.csv(file.path(data_dir, "centrality_3y.csv"))

# ================================
# STEP 5: INITIAL PARTNER & FOCAL CENTRALITY
# ================================

cat("=", rep("=", 60), "\n", sep = "")
cat("STEP 5: CALCULATING PARTNER & FOCAL CENTRALITY\n")
cat("=", rep("=", 60), "\n\n", sep = "")

start_time <- Sys.time()

# Calculate initial partner centrality
cat("Calculating initial partner centrality...\n")
partner_cent <- VC_initial_partner_centrality(initial_partner_list, cent)

cat("  - Rows:", nrow(partner_cent), "\n")
cat("  - Variables:", paste(names(partner_cent)[grepl("^p_", names(partner_cent))], collapse = ", "), "\n\n")

# Calculate initial focal centrality
cat("Calculating initial focal centrality...\n")
focal_cent <- VC_initial_focal_centrality(initial_partner_list, cent)

cat("  - Rows:", nrow(focal_cent), "\n")
cat("  - Variables:", paste(names(focal_cent)[grepl("^f_", names(focal_cent))], collapse = ", "), "\n\n")

end_time <- Sys.time()
cat("Partner & focal centrality completed in", round(difftime(end_time, start_time, units = "mins"), 2), "minutes\n\n")

# Save checkpoint
checkpoint_save("05_partner_focal_centrality", 
                list(partner_cent = partner_cent, focal_cent = focal_cent), 
                checkpoint_dir = checkpoint_dir)

# ================================
# STEP 6: CREATE FINAL DATASET
# ================================

cat("=", rep("=", 60), "\n", sep = "")
cat("STEP 6: CREATING FINAL IMPRINTING DATASET\n")
cat("=", rep("=", 60), "\n\n", sep = "")

start_time <- Sys.time()

# Start with initial partner list
cat("Building final dataset...\n")
imp_dta <- initial_partner_list %>%
  filter(tied_year >= initial_year)  # Keep only ties during/after initial year

cat("  - Base rows:", nrow(imp_dta), "\n\n")

# Merge partner centrality
cat("Merging partner centrality...\n")
imp_dta <- imp_dta %>%
  left_join(partner_cent, by = c("firmname", "tied_year"))
cat("  - Rows after merge:", nrow(imp_dta), "\n\n")

# Merge focal centrality
cat("Merging focal centrality...\n")
imp_dta <- imp_dta %>%
  left_join(focal_cent, by = c("firmname", "tied_year"))
cat("  - Rows after merge:", nrow(imp_dta), "\n\n")

# Merge firm types
cat("Merging firm types...\n")
imp_dta <- imp_dta %>%
  left_join(firmdta %>% select(firmname, firmtype2) %>% unique(), by = "firmname")
cat("  - Rows after merge:", nrow(imp_dta), "\n\n")

# Calculate Blau index (diversity index)
cat("Calculating Blau diversity index...\n")
imp_dta <- imp_dta %>%
  group_by(firmname, tied_year) %>%
  mutate(
    n_partners = n(),
    blau_index = 1 - sum((table(firmtype2) / n_partners)^2, na.rm = TRUE)
  ) %>%
  ungroup()

# Merge exit performance
cat("Merging exit performance...\n")
imp_dta <- imp_dta %>%
  left_join(
    round %>%
      left_join(comdta %>% select(comname, ipoExit, MnAExit), by = "comname") %>%
      group_by(firmname) %>%
      summarise(
        n_exits_ipo = sum(ipoExit, na.rm = TRUE),
        n_exits_mna = sum(MnAExit, na.rm = TRUE),
        n_exits_total = n_exits_ipo + n_exits_mna
      ),
    by = "firmname"
  )

# Create log variables
cat("Creating log-transformed variables...\n")
imp_dta <- imp_dta %>%
  mutate(
    ln_p_dgr = log(p_dgr_cent + 1),
    ln_f_dgr = log(f_dgr_cent + 1),
    ln_n_partners = log(n_partners + 1)
  )

# Replace NA with 0 for centrality measures
cat("Handling missing values...\n")
imp_dta <- imp_dta %>%
  mutate(across(starts_with("p_"), ~ replace_na(.x, 0))) %>%
  mutate(across(starts_with("f_"), ~ replace_na(.x, 0)))

cat("\nFinal dataset created:\n")
cat("  - Total rows:", nrow(imp_dta), "\n")
cat("  - Unique firms:", length(unique(imp_dta$firmname)), "\n")
cat("  - Variables:", ncol(imp_dta), "\n\n")

# Save final dataset
write.csv(imp_dta, file.path(data_dir, "final_imprinting_data.csv"), row.names = FALSE)

end_time <- Sys.time()
cat("Final dataset creation completed in", round(difftime(end_time, start_time, units = "mins"), 2), "minutes\n\n")

# Save checkpoint
checkpoint_save("06_final_dataset", imp_dta, checkpoint_dir = checkpoint_dir)

# ================================
# STEP 7: STATISTICAL ANALYSIS
# ================================

cat("=", rep("=", 60), "\n", sep = "")
cat("STEP 7: STATISTICAL ANALYSIS\n")
cat("=", rep("=", 60), "\n\n", sep = "")

start_time <- Sys.time()

# Create panel identifier
cat("Creating panel identifiers...\n")
dta <- imp_dta %>%
  mutate(firm_id = as.numeric(factor(firmname))) %>%
  filter(!is.na(ln_p_dgr), !is.na(blau_index))

cat("  - Firms:", length(unique(dta$firmname)), "\n")
cat("  - Observations:", nrow(dta), "\n\n")

# Descriptive statistics
cat("Calculating descriptive statistics...\n")
desc_vars <- c("n_exits_total", "ln_p_dgr", "ln_f_dgr", "blau_index", "ln_n_partners")
desc_stats <- psych::describe(dta[, desc_vars], fast = TRUE)
write.csv(desc_stats, file.path(results_dir, "descriptive_stats.csv"))
cat("  - Descriptive stats saved\n\n")

# Model 0: Base model (exits ~ partner centrality)
cat("Running Model 0 (Base model)...\n")
model_0 <- tryCatch({
  if(require('pglm', quietly = TRUE)) {
    pglm(n_exits_total ~ ln_p_dgr,
         data = dta,
         family = poisson,
         effect = "individual",
         model = "pooling",
         method = "bfgs")
  } else {
    # Fallback to glm
    glm(n_exits_total ~ ln_p_dgr + factor(firmname),
        data = dta,
        family = poisson)
  }
}, error = function(e) {
  cat("  - Error:", e$message, "\n")
  log_error(e, "Model 0", log_file = error_log)
  return(NULL)
})

if (!is.null(model_0)) {
  model_0_summary <- broom::tidy(model_0)
  write.csv(model_0_summary, file.path(results_dir, "model_0_results.csv"), row.names = FALSE)
  cat("  - Model 0 completed\n\n")
} else {
  cat("  - Model 0 failed\n\n")
}

# Model 1: Partner centrality + Focal centrality
cat("Running Model 1 (Partner + Focal centrality)...\n")
model_1 <- tryCatch({
  if(require('pglm', quietly = TRUE)) {
    pglm(n_exits_total ~ ln_p_dgr + ln_f_dgr,
         data = dta,
         family = poisson,
         effect = "individual",
         model = "pooling",
         method = "bfgs")
  } else {
    glm(n_exits_total ~ ln_p_dgr + ln_f_dgr + factor(firmname),
        data = dta,
        family = poisson)
  }
}, error = function(e) {
  cat("  - Error:", e$message, "\n")
  log_error(e, "Model 1", log_file = error_log)
  return(NULL)
})

if (!is.null(model_1)) {
  model_1_summary <- broom::tidy(model_1)
  write.csv(model_1_summary, file.path(results_dir, "model_1_results.csv"), row.names = FALSE)
  cat("  - Model 1 completed\n\n")
} else {
  cat("  - Model 1 failed\n\n")
}

# Model 2: Full model with diversity
cat("Running Model 2 (Full model with diversity)...\n")
model_2 <- tryCatch({
  if(require('pglm', quietly = TRUE)) {
    pglm(n_exits_total ~ ln_p_dgr + ln_f_dgr + blau_index,
         data = dta,
         family = poisson,
         effect = "individual",
         model = "pooling",
         method = "bfgs")
  } else {
    glm(n_exits_total ~ ln_p_dgr + ln_f_dgr + blau_index + factor(firmname),
        data = dta,
        family = poisson)
  }
}, error = function(e) {
  cat("  - Error:", e$message, "\n")
  log_error(e, "Model 2", log_file = error_log)
  return(NULL)
})

if (!is.null(model_2)) {
  model_2_summary <- broom::tidy(model_2)
  write.csv(model_2_summary, file.path(results_dir, "model_2_results.csv"), row.names = FALSE)
  cat("  - Model 2 completed\n\n")
} else {
  cat("  - Model 2 failed\n\n")
}

end_time <- Sys.time()
cat("Statistical analysis completed in", round(difftime(end_time, start_time, units = "mins"), 2), "minutes\n\n")

# ================================
# FINAL SUMMARY
# ================================

cat("=", rep("=", 60), "\n", sep = "")
cat("IMPRINTING FLOW TESTING COMPLETED!\n")
cat("=", rep("=", 60), "\n\n", sep = "")

cat("📁 Output locations:\n")
cat("  Data files:  ", data_dir, "\n")
cat("  Results:     ", results_dir, "\n")
cat("  Logs:        ", log_dir, "\n")
cat("  Checkpoints: ", checkpoint_dir, "\n\n")

cat("📊 Generated files:\n")
cat("  Data:\n")
list.files(data_dir) %>% walk(~ cat("    -", .x, "\n"))
cat("\n  Results:\n")
list.files(results_dir) %>% walk(~ cat("    -", .x, "\n"))
cat("\n")

send_notification("Imprinting flow testing completed successfully!", 
                 type = "success", log_file = error_log)

cat("Analysis completed successfully!\n")

