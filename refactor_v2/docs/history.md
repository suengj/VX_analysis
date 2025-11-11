*** Add File: docs/history.md
# Change History

## 2025-01-XX (Recent Updates)
- **Decade Fixed Effects**: Added decade-based year fixed effects option (`YEAR_FE_TYPE_MAIN` and `YEAR_FE_TYPE_ROBUST`) to address NA issues with full year fixed effects. Decade variable automatically created (80s, 90s, 00s, 10s, 20s) when `"decade"` is selected.
- **Data Loader Enhancement**: Removed hardcoded column filtering from `data_loader.R`; now loads all columns from Parquet/Feather files to allow flexible variable selection.
- **Year FE Configuration**: Changed from boolean toggles (`INCLUDE_YEAR_FE_MAIN`, `INCLUDE_YEAR_FE_ROBUST`) to type selection (`YEAR_FE_TYPE_MAIN`, `YEAR_FE_TYPE_ROBUST`) with options: `"none"`, `"year"`, `"decade"`.
- **Panel Setup Cleanup**: Removed hardcoded variable creation from `derive_panel_vars()`; log transformations now handled exclusively via `VARS_TO_LOG` configuration.

## 2025-11-11
- Added structural holes (`sh`, Burt effective size) to centrality pipeline and initial-partner status outputs.
- Enhanced `run_imprinting_main.R` configuration with sample-period filters, after-threshold dummy list, log transforms, and year FE toggles.
- Safeguarded R diagnostics by auto-creating missing columns referenced in DV/CV/IV configurations.
- Introduced calendar-year filtering and years-since-initial cutoffs prior to modeling.
