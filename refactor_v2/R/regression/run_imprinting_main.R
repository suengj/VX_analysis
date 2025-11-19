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

## =============================================================================
## Configuration (edit here)
## All variable names must match those in the .fst/.parquet output files
## =============================================================================

## ---------------------------------------------------------------------------
## 1. Dependent Variable (DV)
## ---------------------------------------------------------------------------
# Dependent variable (e.g., "perf_IPO", "perf_all", "perf_MnA")
# DV <- Sys.getenv("DV", unset = "perf_IPO")
DV <- Sys.getenv("DV", unset = "pwr_p0")
# DV <- Sys.getenv("DV", unset = "VC_reputation")

## ---------------------------------------------------------------------------
## 2. Sample Filters
## ---------------------------------------------------------------------------
# Calendar-year bounds (inclusive). Use NULL to skip a bound.
SAMPLE_YEAR_MIN <- 1990
SAMPLE_YEAR_MAX <- 2020

# Years-since-initial cutoff (use Inf or NULL to disable)
MAX_YEARS_SINCE_INIT <- 7

## ---------------------------------------------------------------------------
## 3. After-Threshold Dummies
## ---------------------------------------------------------------------------
# Thresholds (years_since_init) for afterX dummies (duplicates removed)
AFTER_THRESHOLD_LIST <- c(0) # c(10)

## ---------------------------------------------------------------------------
## 4. Year Fixed Effects
## ---------------------------------------------------------------------------
# Options per model: "none", "year", "decade"
YEAR_FE_TYPE_MAIN   <- "decade" # "decade"  # Main ZINB
YEAR_FE_TYPE_ROBUST <- "none"    # Robustness models

## ---------------------------------------------------------------------------
## 5. Control Variables (CV)
## ---------------------------------------------------------------------------
# Control variables pulled directly from .fst/.parquet files
CV_LIST <- c(
#  "initial_inv_num",
#  "initial_inv_amt",
  "n_initial_partners",
  "initial_firmage",
  "firm_hq_CA",
  "firm_hq_MA",

  # "years_since_init",
  # "after10",
#  "firmage",
  "early_stage_ratio",
  "industry_blau",
  "inv_amt",
  "inv_num",

  "dgr_cent",
  # "sh",
  "pwr_p0",
  "ego_dens",

  "perf_IPO",

 "VC_reputation",
  "market_heat"
  # "new_venture_demand"
)

## ---------------------------------------------------------------------------
## 6. Independent Variables (IV) & Interactions
## ---------------------------------------------------------------------------
# Independent variables (specify directly from .fst/.parquet files)
IV_LIST <- c(
  # "initial_sh_mean"
#  "initial_pwr_p0_mean"
  "initial_VC_reputation_mean"
)

# Two-way interactions: each item is c("var1", "var2")
INTERACTION_TERMS <- list(
 # c("initial_VC_reputation_mean", "after10")
  #c("initial_pwr_p0_mean", "VC_reputation")
  # c("initial_sh_mean", "VC_reputation"),
  # c("initial_sh_mean", "ego_dens")
  # c("initial_sh_mean", "years_since_init")
  # c("initial_pwr_p0_mean", "years_since_init")
  c("initial_VC_reputation_mean", "years_since_init")
)

# Three-way interactions: each item is c("var1", "var2", "var3")
# -> automatically expands to pairwise combos + 3-way term (a:b, a:c, b:c, a:b:c)
INTERACTION_TERMS_3WAY <- list(
# c("initial_sh_mean", "early_stage_ratio", "years_since_init")
#  c("initial_pwr_p0_mean", "early_stage_ratio", "years_since_init")  
  c("initial_VC_reputation_mean", "early_stage_ratio", "years_since_init")
)

## ---------------------------------------------------------------------------
## 7. Lagging Setup
## ---------------------------------------------------------------------------
# Variables kept in current period (typically time-adjusted / dummy / constants)
VARS_NO_LAG <- c(
#  "years_since_init",
#  "after7",
#  "firmage"
) # 일종의 안전장치일뿐

# Variables to lag by 1 period (must also appear in CV_LIST)
VARS_TO_LAG <- c(
  "early_stage_ratio",
  "industry_blau",
  "inv_amt",
  "inv_num",
  "ego_dens",
  "dgr_cent",
  "sh",
  "pwr_p0",
 "VC_reputation",
  "market_heat",
  # "new_venture_demand",
  "perf_IPO"
)

## ---------------------------------------------------------------------------
## 8. Factor Variables
## ---------------------------------------------------------------------------
VARS_TO_FACTOR <- c(
  # "firm_hq_CA",
  # "firm_hq_MA",
  # "firm_hq_NY"
)

## ---------------------------------------------------------------------------
## 9. Log Transformations
## ---------------------------------------------------------------------------
VARS_TO_LOG <- c(
  "inv_amt",
  "inv_num",
  "firmage",
  "dgr_cent",

#  "initial_inv_num",
#  "initial_inv_amt",
  "n_initial_partners"

)

## ---------------------------------------------------------------------------
## 10. Mundlak Terms
## ---------------------------------------------------------------------------
# Example: list variables in their original names; log transforms are resolved automatically
MUNDLAK_VARS <- c() # c("sh","ego_dens", "dgr_cent", "inv_amt")

## ---------------------------------------------------------------------------
## 11. Model Selection
## ---------------------------------------------------------------------------
# Options: "gaussian_glm", "logistic_glm", "poisson_fe", "nb_nozi_re", "all", "zinb" (currently commented)
# MODEL <- Sys.getenv("MODEL", unset = "zinb")
MODEL <- Sys.getenv("MODEL", unset = "gaussian_glm")

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
source(file.path(REG_DIR, "glm_helpers.R"))

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

# Helper: resolve transformed variable names (log / lag)
resolve_transformed_var <- function(var_name,
                                    df_cols,
                                    allow_lag = TRUE,
                                    strict = FALSE,
                                    context = "variable") {
  candidates <- character(0)
  if (allow_lag && var_name %in% VARS_TO_LAG) {
    if (var_name %in% VARS_TO_LOG) {
      candidates <- c(candidates, paste0(var_name, "_log_lag1"))
    }
    candidates <- c(candidates, paste0(var_name, "_lag1"))
  }
  if (var_name %in% VARS_TO_LOG) {
    candidates <- c(candidates, paste0(var_name, "_log"))
  }
  candidates <- c(candidates, var_name)
  for (cand in candidates) {
    if (!is.null(cand) && cand %in% df_cols) return(cand)
  }
  msg <- sprintf(
    "%s '%s' not found in data after applying log/lag transformations.",
    context, var_name
  )
  if (strict) {
    stop(paste0(msg, " Check spelling and ensure the variable exists in CV/IV lists or dataset."))
  } else {
    warning(paste0(msg, " Using original name, which may cause downstream errors."))
    var_name
  }
}

resolve_transformed_vector <- function(vars_vec,
                                       df_cols,
                                       allow_lag = TRUE,
                                       strict = FALSE,
                                       context = "variable") {
  vapply(
    vars_vec,
    resolve_transformed_var,
    character(1),
    df_cols = df_cols,
    allow_lag = allow_lag,
    strict = strict,
    context = context
  )
}

# Add Mundlak terms (firm-level means) - computed before lagging
# Check if MUNDLAK_VARS exists (may be commented out)
if (!exists("MUNDLAK_VARS")) {
  MUNDLAK_VARS <- character(0)
}
if (length(MUNDLAK_VARS) > 0) {
  df_cols_pre_lag <- names(df)
  resolved_mundlak <- resolve_transformed_vector(
    MUNDLAK_VARS,
    df_cols_pre_lag,
    allow_lag = FALSE,
    strict = TRUE,
    context = "Mundlak variable"
  )
  resolved_mundlak <- unique(resolved_mundlak)
  message(sprintf("Creating Mundlak terms for variables (%d): %s", length(resolved_mundlak), paste(resolved_mundlak, collapse=", ")))
  df <- add_mundlak_means(df, controls = resolved_mundlak)
  mundlak_terms <- paste0(resolved_mundlak, "_firm_mean")
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

# Build interaction terms (supports 2-way and 3-way with automatic expansion)
interaction_terms_str <- character(0)
df_columns <- names(df)

# Helper to append interaction safely
append_interaction <- function(vars_vec) {
  vars_vec <- stats::na.omit(vars_vec)
  if (length(vars_vec) < 2) {
    warning("Interaction term skipped: fewer than 2 variables provided")
    return(NULL)
  }
  paste(vars_vec, collapse = ":")
}

# Two-way interactions
if (length(INTERACTION_TERMS) > 0) {
  for (int_pair in INTERACTION_TERMS) {
    if (length(int_pair) == 2) {
      resolved <- resolve_transformed_vector(
        int_pair,
        df_columns,
        allow_lag = TRUE,
        strict = TRUE,
        context = "Interaction variable"
      )
      interaction_terms_str <- c(interaction_terms_str, append_interaction(resolved))
    } else {
      warning(sprintf(
        "Skipping invalid 2-way interaction (must have 2 variables): %s",
        paste(int_pair, collapse = ", ")
      ))
    }
  }
}

# Three-way interactions (expands to pairwise + triple terms)
if (length(INTERACTION_TERMS_3WAY) > 0) {
  for (int_triplet in INTERACTION_TERMS_3WAY) {
    if (length(int_triplet) == 3) {
      resolved_triplet <- resolve_transformed_vector(
        int_triplet,
        df_columns,
        allow_lag = TRUE,
        strict = TRUE,
        context = "Interaction variable"
      )
      # Pairwise combinations
      pair_terms <- utils::combn(resolved_triplet, 2, simplify = FALSE)
      for (pair in pair_terms) {
        interaction_terms_str <- c(interaction_terms_str, append_interaction(pair))
      }
      # Full 3-way term
      interaction_terms_str <- c(interaction_terms_str, append_interaction(resolved_triplet))
    } else {
      warning(sprintf(
        "Skipping invalid 3-way interaction (must have 3 variables): %s",
        paste(int_triplet, collapse = ", ")
      ))
    }
  }
}

interaction_terms_str <- unique(stats::na.omit(interaction_terms_str))

if (length(interaction_terms_str) > 0) {
  message(sprintf("Interaction terms (%d): %s", length(interaction_terms_str), paste(interaction_terms_str, collapse=", ")))
} else {
  message("No interaction terms specified (2-way or 3-way)")
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
  message("Note: Using lagged time-varying covariates (X_{t-1} predicts y_t) and any specified interactions")
  m_zinb <- run_main_zinb_for_dv(df, dv = DV, init_vars = all_ivs, 
                                 controls = controls_for_model, 
                                 mundlak_terms = mundlak_terms,
                                 interaction_terms = interaction_terms_str,
                                 out_dir = OUT_DIR,
                                 year_fe_type = YEAR_FE_TYPE_MAIN)
  fitted_models[["ZINB_main"]] <- m_zinb
}

if (MODEL == "gaussian_glm") {
  message("Fitting Gaussian GLM (identity link)...")
  glm_gaussian <- fit_glm_model(
    df = df,
    dv = DV,
    init_vars = all_ivs,
    controls = controls_for_model,
    mundlak_terms = mundlak_terms,
    interaction_terms = interaction_terms_str,
    family = stats::gaussian(link = "identity"),
    model_tag = "gaussian_glm",
    out_dir = OUT_DIR
  )
  fitted_models[["Gaussian_GLM"]] <- glm_gaussian
}

if (MODEL == "logistic_glm") {
  message("Fitting Logistic GLM (binomial logit)...")
  dv_unique <- unique(na.omit(df[[DV]]))
  if (!all(dv_unique %in% c(0, 1))) {
    stop(sprintf("DV '%s' must be binary (0/1) for logistic regression. Found values: %s",
                 DV, paste(head(dv_unique, 5), collapse = ", ")))
  }
  glm_logistic <- fit_glm_model(
    df = df,
    dv = DV,
    init_vars = all_ivs,
    controls = controls_for_model,
    mundlak_terms = mundlak_terms,
    interaction_terms = interaction_terms_str,
    family = stats::binomial(link = "logit"),
    model_tag = "logistic_glm",
    out_dir = OUT_DIR
  )
  fitted_models[["Logistic_GLM"]] <- glm_logistic
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
if (length(fitted_models) == 0) {
  message("No models fitted (check MODEL).")
} else if (MODEL %in% c("zinb","poisson_fe","nb_nozi_re","all")) {
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
  message("No visualization export for GLM-only runs (combine_models_for_plot expects glmmTMB objects).")
}

message("Done.")


