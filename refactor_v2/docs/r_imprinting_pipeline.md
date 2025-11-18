# R Imprinting Regression Pipeline

## 1. Purpose
- Centralizes documentation for `R/regression/run_imprinting_main.R`
- Explains configuration blocks, transformations, interactions, and outputs
- Complements `USAGE_GUIDE.md` with more detail on the R-only workflow

## 2. Entry Point & Dependencies
- Run via `Rscript R/regression/run_imprinting_main.R` or source in an R session
- Auto-installs required packages (`dplyr`, `tidyr`, `glmmTMB`, etc.)
- Reads latest analysis dataset from `notebooks/analysis_outputs/`
- Writes all diagnostics/models to `notebooks/output/`

## 3. Data Flow Summary
1. `load_and_prepare()` loads the complete Parquet/Feather file without filtering columns
2. `derive_panel_vars()` enforces panel keys (`firmname`, `year`) and preserves derived columns (e.g., `years_since_init`)
3. Optional filters:
   - Calendar years (`SAMPLE_YEAR_MIN`, `SAMPLE_YEAR_MAX`)
   - Years-since-initial (`MAX_YEARS_SINCE_INIT`)
4. Transformation order:
   1. After-threshold dummies (`after{X}`)
   2. Factor conversion (`VARS_TO_FACTOR`)
   3. Log transformation (`VARS_TO_LOG` → `{var}_log`)
   4. Mundlak means (`{var}_firm_mean`)
   5. Lagging (`VARS_TO_LAG` → `{var}_lag1` or `{var}_log_lag1`)
   6. Interaction assembly (2-way & 3-way) with automatic name resolution

## 4. Configuration Blocks (Top of the Script)

| Section | Key Variables | Notes |
| --- | --- | --- |
| 1. DV | `DV` | Counts outcome (`perf_IPO`, `perf_all`, `perf_MnA`, …) |
| 2. Filters | `SAMPLE_YEAR_MIN`, `SAMPLE_YEAR_MAX`, `MAX_YEARS_SINCE_INIT` | Set `NULL` or `Inf` to disable |
| 3. After-threshold | `AFTER_THRESHOLD_LIST` | Creates `afterX` dummies |
| 4. Year FE | `YEAR_FE_TYPE_MAIN`, `YEAR_FE_TYPE_ROBUST` | `"none"`, `"year"`, `"decade"` (decade auto-builds `decade` factor) |
| 5. Controls | `CV_LIST` | Variables from data; lag behavior defined later |
| 6. IVs & Interactions | `IV_LIST`, `INTERACTION_TERMS`, `INTERACTION_TERMS_3WAY` | 3-way expands to all pairwise + triple terms |
| 7. Lagging | `VARS_NO_LAG`, `VARS_TO_LAG` | Lagging integrates with log settings |
| 8. Factors | `VARS_TO_FACTOR` | Converted before modeling |
| 9. Log Transform | `VARS_TO_LOG` | Uses `log1p`, before lagging |
| 10. Mundlak | `MUNDLAK_VARS` | Adds `{var}_firm_mean` to controls |
| 11. Model | `MODEL` | `"zinb"`, `"poisson_fe"`, `"nb_nozi_re"`, or `"all"` |

## 5. Interaction Handling (New Logic)
- Users can specify original variable names (`VC_reputation`, `market_heat`, etc.) regardless of log/lag choices
- Helper `resolve_interaction_var()` maps each name to the actual column in `df` following this priority:
  1. If variable is both log & lag: `{var}_log_lag1`
  2. If variable is lag-only: `{var}_lag1`
  3. If variable is log-only: `{var}_log`
  4. Else: original name
- Three-way interactions (e.g., `c("initial_pwr_p0_mean","VC_reputation","after7")`) automatically expand to:
  - All pairwise terms (`var1:var2`, `var1:var3`, `var2:var3`)
  - Triple term (`var1:var2:var3`)
- Final interaction list is de-duplicated and logged for transparency

## 6. Diagnostics
- `run_diagnostics()` produces:
  - Descriptive stats (`diagnostics_description_*`)
  - Correlation (both Pearson `r` and `p`-values)
  - VIF
- Files are timestamped (`yymmdd_hhmm`) to prevent overwriting

## 7. Modeling Suite
### Main Model: `ZINB`
- Firm random intercept + optional year/decade FE
- Zero-inflation intercept-only
- Includes IVs, controls (lagged/log versions), Mundlak means, and interactions

### Robustness Models
1. `Poisson_FE`: Firm FE + optional year/decade FE (initial-condition IVs excluded)
2. `NB_noZI_RE`: Negative Binomial without zero-inflation, firm RE + optional year/decade FE

## 8. Output Files
- Saved to `notebooks/output/` with timestamp suffix
- Examples:
  - `model_perf_IPO_zinb_p0_cond_250118_1030.csv`
  - `model_perf_IPO_zinb_p0_zi_250118_1030.csv`
  - `robust_perf_IPO_nb_nozi_re_cond_250118_1030.csv`
  - `viz_coefs_perf_IPO_initial_pwr_p0_mean_zinb_250118_1030.csv`
- Each coefficient table includes `estimate`, `std.error`, `conf.low`, `conf.high`, and `stars` column (`***`, `**`, `*`)

## 9. Tips & Gotchas
- When changing variable lists, missing columns are auto-created as `NA` to keep pipelines stable
- Year FE defaults to decade-level to avoid sparse-year NA issues; set `YEAR_FE_TYPE_*` to `"year"` only when data coverage is sufficient
- For batch experiments (e.g., different IVs or interaction sets), wrap calls to `run_main_zinb_for_dv()` inside a user-defined loop—CSV timestamps keep results separated
- Always restart R sessions when switching between major configurations to avoid cached objects

## 10. Related Files
- `R/regression/data_loader.R`: Dataset loading & derived columns (`after7`, `years_since_init`)
- `R/regression/panel_setup_and_vars.R`: Lagging, log transforms, after-threshold dummies, Mundlak means
- `R/regression/models_zinb_glmmTMB.R`: ZINB formula builder, model fitting, and export helpers
- `R/regression/models_robustness.R`: Poisson FE and NB (no ZI) runners
- `R/regression/diagnostics.R`: Stats & VIF utilities
- `docs/history.md`: High-level change log for recent R workflow improvements

---
_Last updated: 2025-01 (automatic decade FE, interaction resolving, full-column loader)_ 

