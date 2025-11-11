## test_pwr_p0.R
## Quick test script to check if pwr_p0 and other CV variables exist in data

# Source data loader
REG_DIR <- file.path(
  "/Users","suengj","Documents","Code","Python","Research","VC",
  "refactor_v2","R","regression"
)
source(file.path(REG_DIR, "data_loader.R"))

# Load data
message(paste(rep("=", 50), collapse=""))
message("Loading data...")
df_raw <- load_and_prepare()

message("\n", paste(rep("=", 50), collapse=""))
message("1. Checking CV_LIST variables in data:")
message(paste(rep("=", 50), collapse=""))

CV_LIST <- c(
  "years_since_init",
  "after7",
  "firmage",
  "firm_hq_CA",
  "firm_hq_MA",
  "firm_hq_NY",
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

for (var in CV_LIST) {
  exists <- var %in% names(df_raw)
  if (exists) {
    n_na <- sum(is.na(df_raw[[var]]))
    n_total <- nrow(df_raw)
    n_valid <- n_total - n_na
    pct_valid <- round(100 * n_valid / n_total, 1)
    message(sprintf("  ✓ %-25s EXISTS | Valid: %7d / %7d (%5.1f%%) | NA: %7d", 
                    var, n_valid, n_total, pct_valid, n_na))
    if (n_valid > 0) {
      # Show summary stats for numeric variables
      if (is.numeric(df_raw[[var]])) {
        vals <- df_raw[[var]][!is.na(df_raw[[var]])]
        message(sprintf("      Range: [%.4f, %.4f] | Mean: %.4f", 
                       min(vals), max(vals), mean(vals)))
      }
    }
  } else {
    message(sprintf("  ✗ %-25s MISSING", var))
  }
}

message("\n", paste(rep("=", 50), collapse=""))
message("2. Checking pwr_p0 specifically:")
message(paste(rep("=", 50), collapse=""))

if ("pwr_p0" %in% names(df_raw)) {
  message("  ✓ pwr_p0 column exists")
  message(sprintf("  - Total rows: %d", nrow(df_raw)))
  message(sprintf("  - Non-NA rows: %d", sum(!is.na(df_raw$pwr_p0))))
  message(sprintf("  - NA rows: %d", sum(is.na(df_raw$pwr_p0))))
  message(sprintf("  - Unique values: %d", length(unique(df_raw$pwr_p0[!is.na(df_raw$pwr_p0)]))))
  if (sum(!is.na(df_raw$pwr_p0)) > 0) {
    message("\n  Summary statistics:")
    print(summary(df_raw$pwr_p0))
    message("\n  First 10 non-NA values:")
    print(head(df_raw$pwr_p0[!is.na(df_raw$pwr_p0)], 10))
  }
} else {
  message("  ✗ pwr_p0 column does NOT exist")
  message("\n  Searching for similar column names:")
  pwr_cols <- grep("^pwr_", names(df_raw), value = TRUE)
  if (length(pwr_cols) > 0) {
    message("  Found power-related columns:")
    for (col in pwr_cols) {
      message(sprintf("    - %s", col))
    }
  } else {
    message("  No power-related columns found")
  }
}

message("\n", paste(rep("=", 50), collapse=""))
message("3. Checking VARS_TO_LAG and VARS_NO_LAG settings:")
message(paste(rep("=", 50), collapse=""))

VARS_NO_LAG <- c(
  "years_since_init",
  "after7",
  "firmage"
)

VARS_TO_LAG <- c(
  "early_stage_ratio",
  "industry_blau",
  "inv_amt",
  "dgr_cent",
  "constraint",
  "pwr_p75",
  "VC_reputation",
  "market_heat",
  "new_venture_demand"
)

message("\n  Variables in VARS_NO_LAG:")
for (var in VARS_NO_LAG) {
  in_cv <- var %in% CV_LIST
  in_data <- var %in% names(df_raw)
  status <- if (in_data) "✓" else "✗"
  message(sprintf("    %s %-25s | In CV_LIST: %s | In data: %s", 
                  status, var, if (in_cv) "YES" else "NO", if (in_data) "YES" else "NO"))
}

message("\n  Variables in VARS_TO_LAG:")
for (var in VARS_TO_LAG) {
  in_cv <- var %in% CV_LIST
  in_data <- var %in% names(df_raw)
  status <- if (in_data) "✓" else "✗"
  message(sprintf("    %s %-25s | In CV_LIST: %s | In data: %s", 
                  status, var, if (in_cv) "YES" else "NO", if (in_data) "YES" else "NO"))
}

message("\n  pwr_p0 status:")
message(sprintf("    - In CV_LIST: %s", if ("pwr_p0" %in% CV_LIST) "YES" else "NO"))
message(sprintf("    - In VARS_NO_LAG: %s", if ("pwr_p0" %in% VARS_NO_LAG) "YES" else "NO"))
message(sprintf("    - In VARS_TO_LAG: %s", if ("pwr_p0" %in% VARS_TO_LAG) "YES" else "NO"))
message(sprintf("    - In data: %s", if ("pwr_p0" %in% names(df_raw)) "YES" else "NO"))

if ("pwr_p0" %in% CV_LIST && "pwr_p0" %in% names(df_raw)) {
  if (!("pwr_p0" %in% VARS_NO_LAG) && !("pwr_p0" %in% VARS_TO_LAG)) {
    message("\n  ⚠️  WARNING: pwr_p0 is in CV_LIST but NOT in VARS_NO_LAG or VARS_TO_LAG!")
    message("     This means it will be treated as 'not specified' and may be included as-is.")
  }
}

message("\n", paste(rep("=", 50), collapse=""))
message("4. Simulating controls_for_model construction:")
message(paste(rep("=", 50), collapse=""))

# Simulate the logic from run_imprinting_main.R
controls_for_model <- character(0)

# VARS_NO_LAG processing
vars_no_lag_in_cv <- intersect(VARS_NO_LAG, CV_LIST)
message(sprintf("\n  VARS_NO_LAG ∩ CV_LIST (%d): %s", 
                length(vars_no_lag_in_cv), paste(vars_no_lag_in_cv, collapse=", ")))
controls_for_model <- c(controls_for_model, vars_no_lag_in_cv)

# VARS_TO_LAG processing
vars_to_lag_in_cv <- intersect(VARS_TO_LAG, CV_LIST)
message(sprintf("  VARS_TO_LAG ∩ CV_LIST (%d): %s", 
                length(vars_to_lag_in_cv), paste(vars_to_lag_in_cv, collapse=", ")))
# These would become {var}_lag1 in the actual code
lagged_vars <- paste0(vars_to_lag_in_cv, "_lag1")
controls_for_model <- c(controls_for_model, lagged_vars)

# CV_LIST variables not in VARS_NO_LAG or VARS_TO_LAG
cv_not_specified <- setdiff(CV_LIST, c(VARS_NO_LAG, VARS_TO_LAG))
message(sprintf("  CV_LIST \\ (VARS_NO_LAG ∪ VARS_TO_LAG) (%d): %s", 
                length(cv_not_specified), paste(cv_not_specified, collapse=", ")))
controls_for_model <- c(controls_for_model, cv_not_specified)

message(sprintf("\n  Final controls_for_model (%d variables):", length(controls_for_model)))
for (i in seq_along(controls_for_model)) {
  message(sprintf("    %2d. %s", i, controls_for_model[i]))
}

message("\n  Checking if pwr_p0 is in final controls_for_model:")
if ("pwr_p0" %in% controls_for_model) {
  message("    ✓ pwr_p0 is included")
} else {
  message("    ✗ pwr_p0 is NOT included")
  message("    This is the problem! Check why it was excluded.")
}

message("\n", paste(rep("=", 50), collapse=""))
message("Done!")
