## run_imprinting_main.R
## Main entry to run imprinting analysis in R with minimal edits
## 1) Set DV/INIT_SET/MODEL below
## 2) source() this file or run via Rscript

# Auto-install missing packages
required_packages <- c("dplyr", "tidyr")
missing_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]
if(length(missing_packages) > 0) {
  message("Installing missing packages: ", paste(missing_packages, collapse = ", "))
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

# Ensure that required columns exist in the dataframe (create NA columns if missing)
ensure_columns_exist <- function(df, cols) {
  cols <- unique(stats::na.omit(cols))
  if (length(cols) == 0) return(df)
  for (col in cols) {
    if (!col %in% names(df)) {
      df[[col]] <- NA_real_
    }
  }
  df
}

## -----------------------------------------------------------------------------
## Configuration (edit here)
## All variable names must match those in the .fst/.parquet output files from Python
## -----------------------------------------------------------------------------

## 1. Dependent Variable (DV) Configuration
## -----------------------------------------------------------------------------
# Dependent variable: variable name from .fst/.parquet file
# Examples: "perf_IPO", "perf_all", "perf_MnA"
DV <- Sys.getenv("DV", unset = "perf_IPO")

## 2. Sample Period Filter Configuration
## -----------------------------------------------------------------------------
# Restrict analysis to a specific calendar-year range (inclusive).
# Set to NULL to skip filtering on that bound.
SAMPLE_YEAR_MIN <- 1980  # e.g., 1985
SAMPLE_YEAR_MAX <- 2020  # e.g., 2020

## 2. Years-Since-Init Sample Filter
## -----------------------------------------------------------------------------
# Filter out observations where years_since_init exceeds the specified threshold.
# Set to Inf or NULL to skip filtering. Default keeps all rows.
MAX_YEARS_SINCE_INIT <- 10
# Examples:
# MAX_YEARS_SINCE_INIT <- 20   # keep only rows with years_since_init <= 20
# MAX_YEARS_SINCE_INIT <- NULL # disable filtering

## 3. After-Threshold Dummy Configuration
## -----------------------------------------------------------------------------
# Dummy variables: specify thresholds (in years since initial) to create afterX dummies
# Example: AFTER_THRESHOLD_LIST <- c(5, 7, 10) creates after5, after7, after10 (1 if years_since_init > threshold)
AFTER_THRESHOLD_LIST <- c(7)  # Default includes after7 for backward compatibility
# Note: Duplicates are ignored; NA values are removed

## 4. Year Fixed Effects Configuration
## -----------------------------------------------------------------------------
# Year fixed effects options:
# - "none": No year fixed effects
# - "year": factor(year) - full year fixed effects (may cause NA issues)
# - "decade": factor(decade) - decade fixed effects (80s, 90s, 00s, 10s, 20s)
YEAR_FE_TYPE_MAIN <- "decade"    # For main ZINB model: "none", "year", or "decade"
YEAR_FE_TYPE_ROBUST <- "none"    # For robustness models: "none", "year", or "decade"

## 5. Control Variables (CV) Configuration
## -----------------------------------------------------------------------------
# Control variables: specify variable names directly from .fst/.parquet file
# These will be divided into lagged vs. non-lagged based on VARS_TO_LAG and VARS_NO_LAG settings below
CV_LIST <- c(
  "years_since_init",
#  "after7",
  "firmage",
  "firm_hq_CA",
  "firm_hq_MA",
  "early_stage_ratio",
  "industry_blau",
  "inv_amt",
  "inv_num",
  "dgr_cent",
  "sh",
  "pwr_p0",
  "ego_dens",
  "VC_reputation",
  "market_heat",
  "new_venture_demand"
)
# Note: Variables listed here will be used in models, but lagging is controlled separately below

## 6. Independent Variables (IV) Configuration
## -----------------------------------------------------------------------------
# Independent variables: specify variable names directly from .fst/.parquet file
# Examples: c("initial_pwr_p75_mean", "initial_pwr_p0_mean", "some_other_var")
IV_LIST <- c("initial_sh_mean") # c("initial_pwr_p0_mean")  # Default: empty
# Example:
# IV_LIST <- c("initial_pwr_p75_mean")

# Interaction terms: list of character vectors, each vector contains two variable names to interact
# Format: list(c("var1", "var2"), c("var3", "var4")) creates var1:var2 and var3:var4 interactions
# Example: INTERACTION_TERMS <- list(c("initial_pwr_p75_mean", "years_since_init"))
INTERACTION_TERMS <- list(
#  c("initial_pwr_p0_mean", "VC_reputation")
#  c("initial_sh_mean", "VC_reputation")
  c("initial_sh_mean", "ego_dens")
)  # Default: no interactions
# Example:
# INTERACTION_TERMS <- list(
#   c("initial_pwr_p75_mean", "years_since_init"),  # Initial status × Time since
#   c("initial_pwr_p75_mean", "after7")             # Initial status × After 7 years
# )

## 7. Lagging Configuration
## -----------------------------------------------------------------------------
# Variables that should NOT be lagged (used as-is in models)
# These are typically: time-adjusted variables, dummy variables, firm-level constants
VARS_NO_LAG <- c(
  "years_since_init",      # Time-since variable (already time-adjusted)
#  "after7",                 # Dummy variable
  "firmage"            # Firm age (already reflects time difference)
)

# Variables that should be lagged by 1 period (X_{t-1} predicts y_t)
# These will be automatically lagged and used as {var}_lag1 in models
VARS_TO_LAG <- c(
  "early_stage_ratio",
  "industry_blau",
  "inv_amt",
  "inv_num",
  "dgr_cent",
  "sh",
  "pwr_p0",
  "VC_reputation",
  "market_heat",
  "new_venture_demand"
)
# Note: Variables in VARS_TO_LAG must also be in CV_LIST

## 8. Factor Variables Configuration
## -----------------------------------------------------------------------------
# Variables to convert to factors (categorical variables)
# These will be automatically converted using factor() function
VARS_TO_FACTOR <- character(0) # c("firm_hq_CA", "firm_hq_MA", "firm_hq_NY")  # Default: empty
# Example:
# VARS_TO_FACTOR <- c("firm_hq", "some_categorical_var")
# Note: Variables will be converted to factors before modeling

## 9. Log Transformation Configuration
## -----------------------------------------------------------------------------
# Variables to log-transform using log1p() (log(1 + x) to handle zeros)
# These will be automatically transformed and used as {var}_log in models
VARS_TO_LOG <- c("inv_amt","inv_num","firmage","dgr_cent")  # Default: empty
# Example:
# VARS_TO_LOG <- c("inv_amt", "inv_num", "some_other_var")
# Note: Variables will be log-transformed before modeling
# Note: If a variable already has "_log" suffix in the data, it will not be transformed again

## 10. Mundlak Terms Configuration
## -----------------------------------------------------------------------------
# Variables for Mundlak terms (firm-level means of time-varying covariates)
# These are created automatically as {var}_firm_mean for each variable listed here
# Mundlak terms control for unobserved firm heterogeneity in random effects models
# MUNDLAK_VARS <- c(
#   "early_stage_ratio",
#   "industry_blau",
#   "inv_amt_log",
#   "dgr_cent"
# )
# Resulting Mundlak terms will be: early_stage_ratio_firm_mean, industry_blau_firm_mean, etc.
# Note: Variables listed here should typically be time-varying covariates

## 11. Model Type Configuration
## -----------------------------------------------------------------------------
# Model: one of "zinb" (main), "poisson_fe", "nb_nozi_re", or "all"
MODEL <- Sys.getenv("MODEL", unset = "zinb")

# Output directory (results will be written here)
OUT_DIR <- file.path(
  "/Users","suengj","Documents","Code","Python","Research","VC",
  "refactor_v2","notebooks","output"
)

# Base path for regression modules
REG_DIR <- file.path(
  "/Users","suengj","Documents","Code","Python","Research","VC",
  "refactor_v2","R","regression"
)


## -----------------------------------------------------------------------------
## Source modules
## -----------------------------------------------------------------------------
source(file.path(REG_DIR, "data_loader.R"))
source(file.path(REG_DIR, "panel_setup_and_vars.R"))
source(file.path(REG_DIR, "diagnostics.R"))
source(file.path(REG_DIR, "models_zinb_glmmTMB.R"))
source(file.path(REG_DIR, "models_robustness.R"))
source(file.path(REG_DIR, "results_export.R"))
source(file.path(REG_DIR, "visualization_prep.R"))

## -----------------------------------------------------------------------------
## Load & prepare data
## -----------------------------------------------------------------------------
message("Loading analysis data...")
df_raw <- load_and_prepare()
df <- derive_panel_vars(df_raw)

# Filter by calendar year if bounds are set
pre_rows_year <- nrow(df)
if (!is.null(SAMPLE_YEAR_MIN)) {
  df <- df %>% dplyr::filter(year >= SAMPLE_YEAR_MIN)
}
if (!is.null(SAMPLE_YEAR_MAX)) {
  df <- df %>% dplyr::filter(year <= SAMPLE_YEAR_MAX)
}
post_rows_year <- nrow(df)
if (!is.null(SAMPLE_YEAR_MIN) || !is.null(SAMPLE_YEAR_MAX)) {
  message(sprintf(
    "Filtered years (%s - %s): %d -> %d rows",
    ifelse(is.null(SAMPLE_YEAR_MIN), "-Inf", SAMPLE_YEAR_MIN),
    ifelse(is.null(SAMPLE_YEAR_MAX), "+Inf", SAMPLE_YEAR_MAX),
    pre_rows_year,
    post_rows_year
  ))
} else {
  message("No calendar year filtering applied")
}

# Filter by years_since_init threshold if requested
if (!is.null(MAX_YEARS_SINCE_INIT) && is.finite(MAX_YEARS_SINCE_INIT)) {
  pre_rows <- nrow(df)
  df <- df %>% dplyr::filter(is.na(years_since_init) | years_since_init <= MAX_YEARS_SINCE_INIT)
  post_rows <- nrow(df)
  message(sprintf("Filtered years_since_init > %s: %d -> %d rows", as.character(MAX_YEARS_SINCE_INIT), pre_rows, post_rows))
} else {
  message("No years_since_init filtering applied")
}

## -----------------------------------------------------------------------------
## Build modeling frame: after-threshold dummies, factor conversion, log transformation, Mundlak terms, and lagged variables
## -----------------------------------------------------------------------------
message(sprintf("Preparing modeling frame: DV=%s", DV))

# Create decade variable if needed for year FE
if (YEAR_FE_TYPE_MAIN == "decade" || YEAR_FE_TYPE_ROBUST == "decade") {
  message("Creating decade variable for year fixed effects...")
  df <- create_decade_variable(df)
}

# Create after-threshold dummies (years_since_init > threshold)
if (length(AFTER_THRESHOLD_LIST) > 0) {
  message(sprintf("Creating after-threshold dummies (%d): %s", length(AFTER_THRESHOLD_LIST), paste(AFTER_THRESHOLD_LIST, collapse=", ")))
  df <- create_after_dummies(df, thresholds = AFTER_THRESHOLD_LIST)
  created_after_cols <- paste0("after", unique(stats::na.omit(as.integer(AFTER_THRESHOLD_LIST))))
  created_after_cols <- created_after_cols[created_after_cols %in% names(df)]
  if (length(created_after_cols) > 0) {
    message(sprintf("After-threshold dummies created (%d): %s", length(created_after_cols), paste(created_after_cols, collapse=", ")))
  }
} else {
  message("No after-threshold dummies specified")
}

# Convert specified variables to factors
if (length(VARS_TO_FACTOR) > 0) {
  message(sprintf("Converting variables to factors (%d): %s", length(VARS_TO_FACTOR), paste(VARS_TO_FACTOR, collapse=", ")))
  for (var in VARS_TO_FACTOR) {
    if (var %in% names(df)) {
      df[[var]] <- factor(df[[var]])
      message(sprintf("  - %s converted to factor", var))
    } else {
      warning(sprintf("Variable %s not found in data, skipping factor conversion", var))
    }
  }
} else {
  message("No variables specified for factor conversion")
}

# Log-transform specified variables
if (length(VARS_TO_LOG) > 0) {
  message(sprintf("Log-transforming variables (%d): %s", length(VARS_TO_LOG), paste(VARS_TO_LOG, collapse=", ")))
  df <- create_log_vars(df, vars_to_log = VARS_TO_LOG)
  log_vars_created <- paste0(VARS_TO_LOG, "_log")
  log_vars_created <- log_vars_created[log_vars_created %in% names(df)]
  if (length(log_vars_created) > 0) {
    message(sprintf("Log-transformed variables created (%d): %s", length(log_vars_created), paste(log_vars_created, collapse=", ")))
  }
} else {
  message("No variables specified for log transformation")
}

# Add Mundlak terms (firm-level means) - computed before lagging
# Check if MUNDLAK_VARS exists (may be commented out)
if (!exists("MUNDLAK_VARS")) {
  MUNDLAK_VARS <- character(0)
}
if (length(MUNDLAK_VARS) > 0) {
  message(sprintf("Creating Mundlak terms for variables (%d): %s", length(MUNDLAK_VARS), paste(MUNDLAK_VARS, collapse=", ")))
  df <- add_mundlak_means(df, controls = MUNDLAK_VARS)
  mundlak_terms <- paste0(MUNDLAK_VARS, "_firm_mean")
  message(sprintf("Mundlak terms created (%d): %s", length(mundlak_terms), paste(mundlak_terms, collapse=", ")))
} else {
  mundlak_terms <- character(0)
  message("No Mundlak variables specified")
}

# Create lagged variables for time-varying covariates (lag by 1 period)
# This ensures X_{i,t-1} predicts y_{i,t} to avoid simultaneity
# Note: If variables are log-transformed, lag the log-transformed versions
if (length(VARS_TO_LAG) > 0) {
  # Determine which variables to lag (use log versions if they exist)
  vars_to_lag_final <- character(0)
  for (var in VARS_TO_LAG) {
    if (var %in% VARS_TO_LOG && paste0(var, "_log") %in% names(df)) {
      vars_to_lag_final <- c(vars_to_lag_final, paste0(var, "_log"))
    } else {
      vars_to_lag_final <- c(vars_to_lag_final, var)
    }
  }
  message(sprintf("Creating lagged variables (lag=1) for (%d): %s", length(vars_to_lag_final), paste(vars_to_lag_final, collapse=", ")))
  df <- create_lagged_vars(df, vars_to_lag = vars_to_lag_final)
} else {
  message("No variables specified for lagging")
}

# Independent variables: use IV_LIST directly
all_ivs <- IV_LIST
if (length(all_ivs) > 0) {
  message(sprintf("Independent variables (%d): %s", length(all_ivs), paste(all_ivs, collapse=", ")))
} else {
  message("No independent variables specified (IV_LIST is empty)")
}

# Control variables: combine non-lagged and lagged versions
# Variables in VARS_NO_LAG: use as-is
# Variables in VARS_TO_LAG: use lagged versions ({var}_lag1)
# Variables in VARS_TO_LOG: use log-transformed versions ({var}_log) if not already lagged
controls_for_model <- character(0)
if (length(VARS_NO_LAG) > 0) {
  # Only include variables that are also in CV_LIST
  vars_no_lag_in_cv <- intersect(VARS_NO_LAG, CV_LIST)
  # Check if any of these should be log-transformed
  vars_no_lag_final <- character(0)
  for (var in vars_no_lag_in_cv) {
    if (var %in% VARS_TO_LOG && paste0(var, "_log") %in% names(df)) {
      vars_no_lag_final <- c(vars_no_lag_final, paste0(var, "_log"))
    } else {
      vars_no_lag_final <- c(vars_no_lag_final, var)
    }
  }
  controls_for_model <- c(controls_for_model, vars_no_lag_final)
  if (length(vars_no_lag_final) > 0) {
    message(sprintf("Control variables (no lag, %d): %s", length(vars_no_lag_final), paste(vars_no_lag_final, collapse=", ")))
  }
}
if (length(VARS_TO_LAG) > 0) {
  # Only include variables that are also in CV_LIST
  vars_to_lag_in_cv <- intersect(VARS_TO_LAG, CV_LIST)
  # Check if any of these should be log-transformed before lagging
  lagged_vars <- character(0)
  for (var in vars_to_lag_in_cv) {
    # If variable was log-transformed, use the log version for lagging
    if (var %in% VARS_TO_LOG && paste0(var, "_log") %in% names(df)) {
      lagged_vars <- c(lagged_vars, paste0(var, "_log_lag1"))
    } else {
      lagged_vars <- c(lagged_vars, paste0(var, "_lag1"))
    }
  }
  # Only include lagged variables that actually exist in the data
  lagged_vars <- lagged_vars[lagged_vars %in% names(df)]
  controls_for_model <- c(controls_for_model, lagged_vars)
  if (length(lagged_vars) > 0) {
    message(sprintf("Control variables (lagged, %d): %s", length(lagged_vars), paste(lagged_vars, collapse=", ")))
  }
}
# Include any CV_LIST variables that are not in VARS_NO_LAG or VARS_TO_LAG
cv_not_specified <- setdiff(CV_LIST, c(VARS_NO_LAG, VARS_TO_LAG))
# Check if any of these should be log-transformed
cv_not_specified_final <- character(0)
for (var in cv_not_specified) {
  if (var %in% VARS_TO_LOG && paste0(var, "_log") %in% names(df)) {
    cv_not_specified_final <- c(cv_not_specified_final, paste0(var, "_log"))
  } else {
    cv_not_specified_final <- c(cv_not_specified_final, var)
  }
}
if (length(cv_not_specified_final) > 0) {
  controls_for_model <- c(controls_for_model, cv_not_specified_final)
  message(sprintf("Control variables (not specified in lag settings, %d): %s", length(cv_not_specified_final), paste(cv_not_specified_final, collapse=", ")))
}
message(sprintf("Total control variables for model (%d): %s", length(controls_for_model), paste(controls_for_model, collapse=", ")))

# Build interaction terms
# Format: "var1:var2" for each interaction pair
interaction_terms_str <- character(0)
if (length(INTERACTION_TERMS) > 0) {
  for (int_pair in INTERACTION_TERMS) {
    if (length(int_pair) == 2) {
      int_str <- paste(int_pair, collapse = ":")
      interaction_terms_str <- c(interaction_terms_str, int_str)
    } else {
      warning(sprintf("Skipping invalid interaction term (must have 2 variables): %s", paste(int_pair, collapse=", ")))
    }
  }
  if (length(interaction_terms_str) > 0) {
    message(sprintf("Interaction terms (%d): %s", length(interaction_terms_str), paste(interaction_terms_str, collapse=", ")))
  }
} else {
  message("No interaction terms specified")
}

# Combine all predictors for diagnostics (use lagged versions)
predictors <- c(all_ivs, controls_for_model, mundlak_terms)

## -----------------------------------------------------------------------------
## Diagnostics (Description / Correlation / VIF)
## -----------------------------------------------------------------------------
message("Running diagnostics...")
run_diagnostics(df, dv = DV, predictors = predictors, out_dir = OUT_DIR)

## -----------------------------------------------------------------------------
## Modeling
## -----------------------------------------------------------------------------
fitted_models <- list()

if (MODEL %in% c("zinb","all")) {
  message("Fitting main ZINB (firm RE + year FE + Mundlak, zi ~ 1)...")
  message(sprintf("Year FE type: %s", YEAR_FE_TYPE_MAIN))
  message("Note: Using lagged time-varying covariates (X_{t-1} predicts y_t)")
  m_zinb <- run_main_zinb_for_dv(df, dv = DV, init_vars = all_ivs, 
                                  controls = controls_for_model, 
                                  mundlak_terms = mundlak_terms,
                                  interaction_terms = interaction_terms_str,
                                  out_dir = OUT_DIR,
                                  year_fe_type = YEAR_FE_TYPE_MAIN)
  fitted_models[["ZINB_main"]] <- m_zinb
}

if (MODEL %in% c("poisson_fe","all")) {
  message("Fitting Poisson FE (firm FE + year FE)...")
  message(sprintf("Year FE type: %s", YEAR_FE_TYPE_ROBUST))
  message("Note: Using lagged time-varying covariates (X_{t-1} predicts y_t)")
  message("Note: Initial condition variables excluded (absorbed by firm FE)")
  rob_poiss <- run_robustness_for_dv(df, dv = DV, init_vars = NULL, 
                                      controls = controls_for_model, 
                                      interaction_terms = interaction_terms_str,
                                      out_dir = OUT_DIR,
                                      year_fe_type = YEAR_FE_TYPE_ROBUST)
  fitted_models[["Poisson_FE"]] <- rob_poiss$poisson_fe
}

if (MODEL %in% c("nb_nozi_re","all")) {
  message("Fitting NB (no ZI), firm RE + year FE...")
  message(sprintf("Year FE type: %s", YEAR_FE_TYPE_ROBUST))
  message("Note: Using lagged time-varying covariates (X_{t-1} predicts y_t)")
  rob_nb <- run_robustness_for_dv(df, dv = DV, init_vars = all_ivs, 
                                   controls = controls_for_model,
                                   interaction_terms = interaction_terms_str,
                                   out_dir = OUT_DIR,
                                   year_fe_type = YEAR_FE_TYPE_ROBUST)
  fitted_models[["NB_noZI_RE"]] <- rob_nb$nb_nozi_re
}

## -----------------------------------------------------------------------------
## Visualization prep (optional CSV for plotting)
## -----------------------------------------------------------------------------
if (length(fitted_models) > 0) {
  # Generate timestamp for file naming
  timestamp <- format(Sys.time(), "%y%m%d_%H%M")
  
  # Create model tag for output filename
  iv_tag <- if (length(IV_LIST) > 0) paste(IV_LIST, collapse="_") else "noiv"
  iv_tag <- gsub("[^A-Za-z0-9_]", "_", iv_tag)  # Sanitize for filename
  iv_tag <- substr(iv_tag, 1, 50)  # Limit length
  
  plot_tbl <- combine_models_for_plot(
    fitted_models,
    out_csv = file.path(OUT_DIR, paste0("viz_coefs_", DV, "_", iv_tag, "_", MODEL, "_", timestamp, ".csv")),
    include_zi = TRUE
  )
  message(sprintf("Exported coefficients for plotting: %s", nrow(plot_tbl)))
} else {
  message("No models fitted (check MODEL).")
}

message("Done.")


