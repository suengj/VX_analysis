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

## -----------------------------------------------------------------------------
## Configuration (edit here)
## -----------------------------------------------------------------------------
# Dependent variable: one of "perf_IPO", "perf_all", "perf_MnA"
DV <- Sys.getenv("DV", unset = "perf_IPO")

# Initial-condition power set: one of "p75", "p0", "p99"
INIT_SET <- Sys.getenv("INIT_SET", unset = "p75")

# Initial-condition aggregation types: c("mean"), c("max"), c("min"), or combinations like c("mean", "max")
# This controls which aggregations (_mean, _max, _min) are included for initial partner status variables
INIT_VAR_AGG_TYPES <- c("mean")  # Default: only _mean

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
## Variable Configuration (edit here to control which variables enter models)
## -----------------------------------------------------------------------------
# Main control variables (time-varying covariates)
# Note: Time-varying variables will be lagged by 1 period (t-1) to predict DV at time t
MAIN_CONTROLS <- c(
  "years_since_init",      # Time-since variable (no lag needed)
  "after7",                 # Dummy variable (no lag needed)
  "firmage_log",            # Time-varying (will be lagged)
  "early_stage_ratio",      # Time-varying (will be lagged)
  "industry_blau",          # Time-varying (will be lagged)
  "inv_amt_log",            # Time-varying (will be lagged)
  "dgr_cent"                # Time-varying (will be lagged)
)

# Variables that should be lagged (time-varying covariates)
# These will be lagged by 1 period: X_{i,t-1} predicts y_{i,t}
VARS_TO_LAG <- c(
  "firmage_log",
  "early_stage_ratio",
  "industry_blau",
  "inv_amt_log",
  "dgr_cent"
)
# Note: initial_* variables and Mundlak terms are firm-level constants (no lag needed)
# Note: years_since_init and after7 are time-since/dummy variables (no lag needed)

# Variables for Mundlak terms (firm-level means of time-varying covariates)
# These are created automatically as {var}_firm_mean for each variable listed here
MUNDLAK_VARS <- c(
  "early_stage_ratio",
  "industry_blau",
  "inv_amt_log",
  "dgr_cent"
)
# Resulting Mundlak terms will be: early_stage_ratio_firm_mean, industry_blau_firm_mean, etc.

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

## -----------------------------------------------------------------------------
## Build modeling frame with Mundlak terms and lagged variables
## -----------------------------------------------------------------------------
message(sprintf("Preparing modeling frame: DV=%s, INIT_SET=%s, INIT_VAR_AGG_TYPES=%s", 
                DV, INIT_SET, paste(INIT_VAR_AGG_TYPES, collapse=",")))

# Add Mundlak terms (firm-level means) - computed before lagging
df <- add_mundlak_means(df, controls = MUNDLAK_VARS)

# Create lagged variables for time-varying covariates (lag by 1 period)
# This ensures X_{i,t-1} predicts y_{i,t} to avoid simultaneity
message("Creating lagged variables (lag=1) for time-varying covariates...")
df <- create_lagged_vars(df, vars_to_lag = VARS_TO_LAG)

# Build initial condition variables based on INIT_SET and INIT_VAR_AGG_TYPES
initvars <- build_initial_vars(init_set = INIT_SET, agg_types = INIT_VAR_AGG_TYPES)
message(sprintf("Initial condition variables (%d): %s", length(initvars), paste(initvars, collapse=", ")))

# Build Mundlak term names (these are created by add_mundlak_means)
mundlak_terms <- paste0(MUNDLAK_VARS, "_firm_mean")
message(sprintf("Mundlak terms (%d): %s", length(mundlak_terms), paste(mundlak_terms, collapse=", ")))

# Replace time-varying controls with lagged versions for modeling
# Variables that don't need lagging: years_since_init, after7 (keep as-is)
controls_for_model <- c(
  "years_since_init",      # No lag (time-since variable)
  "after7",                 # No lag (dummy variable)
  paste0(VARS_TO_LAG, "_lag1")  # Lagged time-varying variables
)
message(sprintf("Control variables for model (%d): %s", length(controls_for_model), paste(controls_for_model, collapse=", ")))

# Combine all predictors for diagnostics (use lagged versions)
predictors <- c(initvars, controls_for_model, mundlak_terms)

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
  message("Note: Using lagged time-varying covariates (X_{t-1} predicts y_t)")
  m_zinb <- run_main_zinb_for_dv(df, dv = DV, init_vars = initvars, 
                                  controls = controls_for_model, mundlak_terms = mundlak_terms,
                                  out_dir = OUT_DIR)
  fitted_models[["ZINB_main"]] <- m_zinb
}

if (MODEL %in% c("poisson_fe","all")) {
  message("Fitting Poisson FE (firm FE + year FE)...")
  message("Note: Using lagged time-varying covariates (X_{t-1} predicts y_t)")
  rob_poiss <- run_robustness_for_dv(df, dv = DV, init_vars = NULL, 
                                      controls = controls_for_model, out_dir = OUT_DIR)
  fitted_models[["Poisson_FE"]] <- rob_poiss$poisson_fe
}

if (MODEL %in% c("nb_nozi_re","all")) {
  message("Fitting NB (no ZI), firm RE + year FE...")
  message("Note: Using lagged time-varying covariates (X_{t-1} predicts y_t)")
  rob_nb <- run_robustness_for_dv(df, dv = DV, init_vars = initvars, 
                                   controls = controls_for_model, out_dir = OUT_DIR)
  fitted_models[["NB_noZI_RE"]] <- rob_nb$nb_nozi_re
}

## -----------------------------------------------------------------------------
## Visualization prep (optional CSV for plotting)
## -----------------------------------------------------------------------------
if (length(fitted_models) > 0) {
  # Generate timestamp for file naming
  timestamp <- format(Sys.time(), "%y%m%d_%H%M")
  
  plot_tbl <- combine_models_for_plot(
    fitted_models,
    out_csv = file.path(OUT_DIR, paste0("viz_coefs_", DV, "_", INIT_SET, "_", MODEL, "_", timestamp, ".csv")),
    include_zi = TRUE
  )
  message(sprintf("Exported coefficients for plotting: %s", nrow(plot_tbl)))
} else {
  message("No models fitted (check MODEL).")
}

message("Done.")


