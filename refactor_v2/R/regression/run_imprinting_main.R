## run_imprinting_main.R
## Main entry to run imprinting analysis in R with minimal edits
## 1) Set DV/INIT_SET/MODEL below
## 2) source() this file or run via Rscript

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

# Model: one of "zinb" (main), "poisson_fe", "nb_nozi_re", or "all"
MODEL <- Sys.getenv("MODEL", unset = "zinb")

# Output directory (results will be written here)
OUT_DIR <- file.path(
  "/Users","suengj","Documents","Code","Python","Research","VC",
  "refactor_v2","notebooks","analysis_outputs"
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

## -----------------------------------------------------------------------------
## Build modeling frame
## -----------------------------------------------------------------------------
message(sprintf("Preparing modeling frame: DV=%s, INIT_SET=%s", DV, INIT_SET))
mf <- make_model_frame(df, dv = DV, init_set = INIT_SET, include_mundlak = TRUE)

## -----------------------------------------------------------------------------
## Diagnostics (Description / Correlation / VIF)
## -----------------------------------------------------------------------------
controls <- c("years_since_init","after7","firmage_log","early_stage_ratio","industry_blau","inv_amt_log","dgr_cent")
mundlak  <- c("early_stage_ratio_firm_mean","industry_blau_firm_mean","inv_amt_log_firm_mean","dgr_cent_firm_mean")
initvars <- initial_vars(INIT_SET)
predictors <- c(initvars, controls, mundlak)

message("Running diagnostics...")
run_diagnostics(mf, dv = DV, predictors = predictors, out_dir = OUT_DIR)

## -----------------------------------------------------------------------------
## Modeling
## -----------------------------------------------------------------------------
fitted_models <- list()

if (MODEL %in% c("zinb","all")) {
  message("Fitting main ZINB (firm RE + year FE + Mundlak, zi ~ 1)...")
  m_zinb <- run_main_zinb_for_dv(mf, dv = DV, init_set = INIT_SET, out_dir = OUT_DIR)
  fitted_models[["ZINB_main"]] <- m_zinb
}

if (MODEL %in% c("poisson_fe","all")) {
  message("Fitting Poisson FE (firm FE + year FE)...")
  rob_poiss <- run_robustness_for_dv(mf, dv = DV, init_vars = NULL, out_dir = OUT_DIR)
  fitted_models[["Poisson_FE"]] <- rob_poiss$poisson_fe
}

if (MODEL %in% c("nb_nozi_re","all")) {
  message("Fitting NB (no ZI), firm RE + year FE...")
  # Reuse helper: pass init vars to include initial-condition effects
  rob_nb <- run_robustness_for_dv(mf, dv = DV, init_vars = initvars, out_dir = OUT_DIR)
  fitted_models[["NB_noZI_RE"]] <- rob_nb$nb_nozi_re
}

## -----------------------------------------------------------------------------
## Visualization prep (optional CSV for plotting)
## -----------------------------------------------------------------------------
if (length(fitted_models) > 0) {
  plot_tbl <- combine_models_for_plot(
    fitted_models,
    out_csv = file.path(OUT_DIR, paste0("viz_coefs_", DV, "_", INIT_SET, "_", MODEL, ".csv")),
    include_zi = TRUE
  )
  message(sprintf("Exported coefficients for plotting: %s", nrow(plot_tbl)))
} else {
  message("No models fitted (check MODEL).")
}

message("Done.")


