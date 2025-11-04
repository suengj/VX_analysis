# CVC Full Flow Testing Script
# Based on CVC_preprcs_v4.R original logic
# Date: 2025-10-11
# Purpose: Test refactored code with complete CVC analysis workflow

# Clear environment
rm(list = ls())
gc()

# ================================
# SETUP
# ================================

# Set working directory
setwd("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor")

# Load required packages
if (!require('igraph')) install.packages('igraph'); library('igraph')
if (!require('data.table')) install.packages('data.table'); library('data.table')
if (!require('tidyverse')) install.packages('tidyverse'); library('tidyverse')
if (!require('lubridate')) install.packages('lubridate'); library('lubridate')
if (!require('readxl')) install.packages('readxl'); library(readxl)
if (!require('progress')) install.packages('progress'); library('progress')
if (!require('doParallel')) install.packages('doParallel'); library('doParallel')
if (!require('foreach')) install.packages('foreach'); library('foreach')
if (!require('survival')) install.packages('survival'); library('survival')
if (!require('psych')) install.packages('psych'); library('psych')
if (!require('broom')) install.packages('broom'); library('broom')

# Load refactored functions
source("R/config/paths.R")
source("R/config/constants.R")
source("R/config/parameters.R")
source("R/core/network_construction.R")
source("R/core/centrality_calculation.R")
source("R/core/data_processing.R")
source("R/core/sampling.R")

# Set output directory
output_dir <- "/Users/suengj/Documents/Code/Python/Research/VC/testing_results/cvc_flow"
data_dir <- file.path(output_dir, "data")
results_dir <- file.path(output_dir, "results")
logs_dir <- file.path(output_dir, "logs")

# Start logging
log_file <- file.path(logs_dir, paste0("cvc_test_", format(Sys.Date(), "%Y%m%d"), ".log"))
sink(log_file, append = TRUE, split = TRUE)

cat("="

, rep("=", 60), "\n", sep = "")
cat("CVC FLOW TESTING STARTED\n")
cat("Time:", as.character(Sys.time()), "\n")
cat("=", rep("=", 60), "\n\n", sep = "")

# ================================
# PARAMETERS
# ================================

cat("Setting parameters...\n")

# Core settings
capacity <- 0.8
cores <- round(parallel::detectCores() * capacity, digits = 0)
registerDoParallel(cores = cores)

# Analysis settings
time_window <- 5
edge_cutpoint <- 5
sample_ratio <- 10
todayDate <- format(Sys.Date(), "%y%b%d")

# Year range (limited for testing - 원본은 1980-2022)
min_year <- 1985
max_year <- 2000  # 테스트용으로 축소

cat("Parameters set:\n")
cat("  - Cores:", cores, "\n")
cat("  - Time window:", time_window, "\n")
cat("  - Sample ratio:", sample_ratio, "\n")
cat("  - Year range:", min_year, "-", max_year, "\n\n")

# ================================
# STEP 1: LOAD RAW DATA
# ================================

cat("="

, rep("=", 60), "\n", sep = "")
cat("STEP 1: LOADING RAW DATA\n")
cat("=", rep("=", 60), "\n\n", sep = "")

start_time <- Sys.time()

# Load original data files
base_dir <- "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Yang, Rhee, Ma/data"

cat("Loading company data...\n")
comdta <- read.csv(file.path(base_dir, "new/comdta_new.csv")) %>% as_tibble() %>%
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
                                               "Insurance Firm Affiliate") ~ "Financial",
                               firmtype %in% c("Private Equity Firm")~"IVC",
                               firmtype %in% c("Incubator/Development Program",
                                               "Government Affiliated Program",
                                               "University Program")~"Non-Financial",
                               firmtype %in% c("Service Provider","Other","Non-Private Equity")~"Other")) %>%
  mutate(firmtype3 = ifelse(firmtype2 %in% c("IVC"),"IVC","non-IVC"))
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
funddta <- read_excel(file.path(base_dir, "new/fund_all.xlsx")) %>% as_tibble() %>% unique()
cat("  - Rows:", nrow(funddta), "\n\n")

end_time <- Sys.time()
cat("Data loading completed in", round(difftime(end_time, start_time, units = "secs"), 2), "seconds\n\n")

# ================================
# STEP 2: DATA PREPROCESSING
# ================================

cat("=", rep("=", 60), "\n", sep = "")
cat("STEP 2: DATA PREPROCESSING\n")
cat("=", rep("=", 60), "\n\n", sep = "")

start_time <- Sys.time()

# Filter by year
cat("Filtering by year range...\n")
round <- round %>% filter(year >= min_year, year <= max_year)
cat("  - Rows after filtering:", nrow(round), "\n\n")

# Filter US only
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

# Create quarter column (원본 로직)
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

# Create event column
cat("Creating event identifiers...\n")
round <- round %>%
  mutate(event = paste(comname, year, sep = "-"))
cat("  - Unique events:", length(unique(round$event)), "\n\n")

# Create edgeRound for network analysis
edgeRound <- round %>%
  select(year, firmname, event) %>%
  distinct()

cat("Edge data created:\n")
cat("  - Rows:", nrow(edgeRound), "\n")
cat("  - Unique firms:", length(unique(edgeRound$firmname)), "\n")
cat("  - Unique events:", length(unique(edgeRound$event)), "\n\n")

# Save preprocessed data
cat("Saving preprocessed data...\n")
write.csv(round, file.path(data_dir, "round_preprocessed.csv"), row.names = FALSE)
write.csv(edgeRound, file.path(data_dir, "edgeRound.csv"), row.names = FALSE)

end_time <- Sys.time()
cat("Preprocessing completed in", round(difftime(end_time, start_time, units = "secs"), 2), "seconds\n\n")

# ================================
# STEP 3: IDENTIFY LEAD VC
# ================================

cat("=", rep("=", 60), "\n", sep = "")
cat("STEP 3: IDENTIFYING LEAD VCs\n")
cat("=", rep("=", 60), "\n\n", sep = "")

start_time <- Sys.time()

LeadVCdta <- leadVC_identifier(round)

cat("Lead VC identification completed:\n")
cat("  - Number of Lead VCs:", nrow(LeadVCdta), "\n")
cat("  - Unique companies:", length(unique(LeadVCdta$comname)), "\n\n")

# Save Lead VC data
write.csv(LeadVCdta, file.path(data_dir, "leadVC_data.csv"), row.names = FALSE)

end_time <- Sys.time()
cat("Lead VC identification completed in", round(difftime(end_time, start_time, units = "mins"), 2), "minutes\n\n")

# ================================
# STEP 4: CASE-CONTROL SAMPLING
# ================================

cat("=", rep("=", 60), "\n", sep = "")
cat("STEP 4: CASE-CONTROL SAMPLING (1:", sample_ratio, ")\n", sep = "")
cat("=", rep("=", 60), "\n\n", sep = "")

start_time <- Sys.time()

# Get unique quarters
YQ <- round %>%
  select(quarter) %>%
  unique() %>%
  arrange() %>%
  pull()

cat("Total quarters to process:", length(YQ), "\n\n")

# Sampling loop (limited for testing)
cc_list <- list()
v_loop <- 1

cat("Starting sampling loop...\n")
pb <- txtProgressBar(min = 0, max = length(YQ), style = 3)

for (i in YQ) {
  cc_list[[i]] <- VC_sampling_opt1_output(round, LeadVCdta, quarter, ratio = sample_ratio, i)
  cc_list[[i]]$quarter <- i
  
  setTxtProgressBar(pb, v_loop)
  v_loop <- v_loop + 1
}

close(pb)

samp_dta <- do.call("rbind", cc_list)

cat("\nSampling completed:\n")
cat("  - Total rows:", nrow(samp_dta), "\n")
cat("  - Realized ties:", sum(samp_dta$realized == 1), "\n")
cat("  - Unrealized ties:", sum(samp_dta$realized == 0), "\n")
cat("  - Ratio:", round(sum(samp_dta$realized == 0) / sum(samp_dta$realized == 1), 2), ":1\n\n")

# Save sampling data
write.csv(samp_dta, file.path(data_dir, "sampling_data.csv"), row.names = FALSE)

end_time <- Sys.time()
cat("Sampling completed in", round(difftime(end_time, start_time, units = "mins"), 2), "minutes\n\n")

# ================================
# STEP 5: CENTRALITY CALCULATION
# ================================

cat("=", rep("=", 60), "\n", sep = "")
cat("STEP 5: CALCULATING NETWORK CENTRALITY\n")
cat("=", rep("=", 60), "\n\n", sep = "")

start_time <- Sys.time()

cat("Calculating centrality for years", min_year + 5, "-", max_year, "\n")
cat("Using parallel processing with", cores, "cores\n\n")

cent <- foreach(y = (min_year + 5):max_year,
                .combine = rbind,
                .packages = c("igraph", "data.table", "tidyverse")) %dopar% {
  
  result <- VC_centralities(edgeRound, y, time_window, edge_cutpoint)
  
  if (nrow(result) > 0) {
    result$year <- y
  }
  
  return(result)
}

cent <- cent %>% as_tibble()
colnames(cent)[colnames(cent) == "rn"] <- "firmname"

cat("Centrality calculation completed:\n")
cat("  - Total rows:", nrow(cent), "\n")
cat("  - Unique firms:", length(unique(cent$firmname)), "\n")
cat("  - Year range:", min(cent$year), "-", max(cent$year), "\n\n")

# Save centrality data
write.csv(cent, file.path(data_dir, "centrality_data.csv"), row.names = FALSE)

end_time <- Sys.time()
cat("Centrality calculation completed in", round(difftime(end_time, start_time, units = "mins"), 2), "minutes\n\n")

# ================================
# STEP 6: MERGE AND CREATE VARIABLES
# ================================

cat("=", rep("=", 60), "\n", sep = "")
cat("STEP 6: MERGING DATA AND CREATING VARIABLES\n")
cat("=", rep("=", 60), "\n\n", sep = "")

start_time <- Sys.time()

# Prepare raw dataset
cat("Preparing raw dataset...\n")
raw <- samp_dta %>%
  mutate(year = as.numeric(substr(quarter, 1, 4))) %>%
  filter(year >= min_year + 5)  # Need 5 years for centrality

cat("  - Rows:", nrow(raw), "\n\n")

# Merge centrality data
cat("Merging centrality data...\n")
raw <- raw %>%
  left_join(cent, by = c("year" = "year", "leadVC" = "firmname")) %>%
  left_join(cent, by = c("year" = "year", "coVC" = "firmname"), suffix = c("_lead", "_co"))

cat("  - Rows after merge:", nrow(raw), "\n\n")

# Merge firm founding dates and calculate ages
cat("Merging firm founding dates...\n")
raw <- raw %>%
  left_join(firmdta %>% select(firmname, firmfounding) %>% unique(), 
            by = c("leadVC" = "firmname")) %>%
  left_join(firmdta %>% select(firmname, firmfounding) %>% unique(), 
            by = c("coVC" = "firmname"), suffix = c(".x", ".y"))

# Calculate firm ages
cat("Calculating firm ages...\n")
raw <- raw %>%
  mutate(
    leadVC_age = year - year(firmfounding.x),
    coVC_age = year - year(firmfounding.y)
  ) %>%
  select(-firmfounding.x, -firmfounding.y)

# Merge firm types
cat("Merging firm types...\n")
raw <- raw %>%
  left_join(firmdta %>% select(firmname, firmtype2) %>% unique(), 
            by = c("leadVC" = "firmname")) %>%
  left_join(firmdta %>% select(firmname, firmtype2) %>% unique(), 
            by = c("coVC" = "firmname"), suffix = c("_lead", "_co"))

# Handle negative ages (set to 0)
cat("Handling negative ages...\n")
raw <- raw %>%
  mutate(
    leadVC_age = ifelse(leadVC_age < 0, 0, leadVC_age),
    coVC_age = ifelse(coVC_age < 0, 0, coVC_age)
  )

# Create log variables
cat("Creating log variables...\n")
raw <- raw %>%
  mutate(
    ln_leadVC_age = log(leadVC_age + 1),
    ln_coVC_age = log(coVC_age + 1),
    ln_coVC_dgr = log(dgr_cent_co + 1),
    ln_leadVC_dgr = log(dgr_cent_lead + 1)
  )

# Create dyad type variables
cat("Creating dyad type variables...\n")
raw <- raw %>%
  mutate(
    both_prv = ifelse(firmtype2_lead == "IVC" & firmtype2_co == "IVC", 1, 0),
    both_cvc = ifelse(firmtype2_lead == "CVC" & firmtype2_co == "CVC", 1, 0),
    prvcvc = ifelse((firmtype2_lead == "IVC" & firmtype2_co == "CVC") |
                      (firmtype2_lead == "CVC" & firmtype2_co == "IVC"), 1, 0)
  )

# Create power asymmetry variables
cat("Creating power asymmetry variables...\n")
raw <- raw %>%
  rowwise() %>%
  mutate(
    bp_abs_max = abs(pwr_max_lead - pwr_max_co),
    bp_asy_max = pwr_max_lead - pwr_max_co,
    bp_abs_dis_max = bp_abs_max / sum(c(pwr_max_lead, pwr_max_co), na.rm = TRUE),
    z_bp_abs_dis_max = scale(bp_abs_dis_max)
  ) %>%
  ungroup()

cat("Final dataset created:\n")
cat("  - Total rows:", nrow(raw), "\n")
cat("  - Realized ties:", sum(raw$realized == 1, na.rm = TRUE), "\n")
cat("  - Unrealized ties:", sum(raw$realized == 0, na.rm = TRUE), "\n\n")

# Save final dataset
write.csv(raw, file.path(data_dir, "final_cvc_data.csv"), row.names = FALSE)

end_time <- Sys.time()
cat("Variable creation completed in", round(difftime(end_time, start_time, units = "mins"), 2), "minutes\n\n")

# ================================
# STEP 7: STATISTICAL ANALYSIS
# ================================

cat("=", rep("=", 60), "\n", sep = "")
cat("STEP 7: STATISTICAL ANALYSIS\n")
cat("=", rep("=", 60), "\n\n", sep = "")

start_time <- Sys.time()

# Create syndicate-level identifier
cat("Creating syndicate-level identifier...\n")
dta <- raw %>%
  group_by(quarter, comname) %>%
  mutate(synd_lv = cur_group_id()) %>%
  ungroup()

cat("  - Unique syndicates:", length(unique(dta$synd_lv)), "\n\n")

# Handle missing values
cat("Handling missing values...\n")
dta <- dta %>%
  mutate(across(contains("_dgr"), ~ replace_na(.x, 0))) %>%
  mutate(across(contains("_btw"), ~ replace_na(.x, 0))) %>%
  mutate(across(contains("_max"), ~ replace_na(.x, 0))) %>%
  mutate(across(contains("constraint"), ~ replace_na(.x, 0)))

# Descriptive statistics
cat("Calculating descriptive statistics...\n")
desc_vars <- c("realized", "ln_coVC_age", "ln_coVC_dgr", "ln_leadVC_dgr",
               "both_prv", "prvcvc", "both_cvc", "bp_abs_dis_max")

desc_stats <- psych::describe(dta[, desc_vars], fast = TRUE)
write.csv(desc_stats, file.path(results_dir, "descriptive_stats.csv"))

cat("  - Descriptive stats saved\n\n")

# Correlation matrix
cat("Calculating correlation matrix...\n")
corr_data <- dta %>%
  select(all_of(desc_vars)) %>%
  drop_na()

corr_matrix <- cor(corr_data)
write.csv(corr_matrix, file.path(results_dir, "correlation_matrix.csv"))

cat("  - Correlation matrix saved\n\n")

# Model 0: Base model
cat("Running Model 0 (Base model)...\n")
model_0 <- tryCatch({
  survival::clogit(realized ~ log(coVC_age + 1) + 
                     strata(synd_lv),
                   data = dta,
                   method = "approximate")
}, error = function(e) {
  cat("  - Error:", e$message, "\n")
  return(NULL)
})

if (!is.null(model_0)) {
  model_0_summary <- broom::tidy(model_0)
  write.csv(model_0_summary, file.path(results_dir, "model_0_results.csv"), row.names = FALSE)
  cat("  - Model 0 completed\n\n")
} else {
  cat("  - Model 0 failed\n\n")
}

# Model 1: VC type effect
cat("Running Model 1 (VC type effect)...\n")
model_1 <- tryCatch({
  survival::clogit(realized ~ factor(firmtype2_co) + log(coVC_age + 1) +
                     z_bp_abs_dis_max + strata(synd_lv),
                   data = dta,
                   method = "approximate")
}, error = function(e) {
  cat("  - Error:", e$message, "\n")
  return(NULL)
})

if (!is.null(model_1)) {
  model_1_summary <- broom::tidy(model_1)
  write.csv(model_1_summary, file.path(results_dir, "model_1_results.csv"), row.names = FALSE)
  cat("  - Model 1 completed\n\n")
} else {
  cat("  - Model 1 failed\n\n")
}

# Model 2: Interaction effect (both_prv)
cat("Running Model 2 (both_prv interaction)...\n")
model_2 <- tryCatch({
  survival::clogit(realized ~ both_prv * z_bp_abs_dis_max + 
                     log(coVC_age + 1) + strata(synd_lv),
                   data = dta,
                   method = "approximate")
}, error = function(e) {
  cat("  - Error:", e$message, "\n")
  return(NULL)
})

if (!is.null(model_2)) {
  model_2_summary <- broom::tidy(model_2)
  write.csv(model_2_summary, file.path(results_dir, "model_2_results.csv"), row.names = FALSE)
  cat("  - Model 2 completed\n\n")
} else {
  cat("  - Model 2 failed\n\n")
}

# Model 3: Interaction effect (prvcvc)
cat("Running Model 3 (prvcvc interaction)...\n")
model_3 <- tryCatch({
  survival::clogit(realized ~ prvcvc * z_bp_abs_dis_max + 
                     log(coVC_age + 1) + strata(synd_lv),
                   data = dta,
                   method = "approximate")
}, error = function(e) {
  cat("  - Error:", e$message, "\n")
  return(NULL)
})

if (!is.null(model_3)) {
  model_3_summary <- broom::tidy(model_3)
  write.csv(model_3_summary, file.path(results_dir, "model_3_results.csv"), row.names = FALSE)
  cat("  - Model 3 completed\n\n")
} else {
  cat("  - Model 3 failed\n\n")
}

end_time <- Sys.time()
cat("Statistical analysis completed in", round(difftime(end_time, start_time, units = "mins"), 2), "minutes\n\n")

# ================================
# FINAL SUMMARY
# ================================

cat("=", rep("=", 60), "\n", sep = "")
cat("CVC FLOW TESTING COMPLETED\n")
cat("=", rep("=", 60), "\n\n", sep = "")

cat("Output files saved to:\n")
cat("  - Data:", data_dir, "\n")
cat("  - Results:", results_dir, "\n")
cat("  - Logs:", log_file, "\n\n")

cat("Total execution time:", round(difftime(Sys.time(), start_time, units = "mins"), 2), "minutes\n\n")

# Stop logging
sink()

cat("Testing completed successfully!\n")

