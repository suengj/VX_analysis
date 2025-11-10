# VC Analysis Pipeline: Complete Usage Guide

## R Analysis Quick Start (separate from Python workflow)

This section documents the R-only pipeline for imprinting analysis. It is independent from the Python notebooks to avoid confusion.

### Entry point
- Main runner: `R/regression/run_imprinting_main.R`
- Outputs: `notebooks/analysis_outputs/`

### How to run
1) Start a fresh R session.
2) Ensure required packages are installed: `glmmTMB`, `psych`, `Hmisc`, `performance`, `broom`, `broom.mixed`, `arrow`, `dplyr`, `tidyr`, `readr`, `plm`.
3) Option A (edit in file):
   - Open `R/regression/run_imprinting_main.R`
   - Set:
     - `DV`: `"perf_IPO"` | `"perf_all"` | `"perf_MnA"`
     - `INIT_SET`: `"p75"` | `"p0"` | `"p99"`
     - `MODEL`: `"zinb"` | `"poisson_fe"` | `"nb_nozi_re"` | `"all"`
   - Run the script.
4) Option B (command line):
   ```
   DV=perf_IPO INIT_SET=p75 MODEL=zinb Rscript R/regression/run_imprinting_main.R
   ```

### What it does
- Loads latest dataset from `notebooks/analysis_outputs/final_analysis_*.parquet` (fallback: Feather).
- Prepares panel keys and derived variables (e.g., `years_since_init`, `firmage_log`, Mundlak means).
- Runs diagnostics: description, correlation, VIF (CSV outputs).
- Fits models:
  - Main: ZINB (firm random intercept + year fixed effects, zero-inflation intercept-only).
  - Robustness: Poisson FE (firm FE + year FE) and NB (no ZI) with firm RE + year FE.
- Exports tidy results and coefficient tables for plotting.

### File map (R modules)
- `R/regression/data_loader.R`: load dataset, base columns.
- `R/regression/panel_setup_and_vars.R`: panel keys, derived vars, initial-power selectors.
- `R/regression/diagnostics.R`: description, correlation, VIF.
- `R/regression/models_zinb_glmmTMB.R`: main ZINB.
- `R/regression/models_robustness.R`: Poisson FE, NB (no-ZI).
- `R/regression/results_export.R`: generic model exporters.
- `R/regression/visualization_prep.R`: tidy coefficient tables for plots.
- `R/regression/run_imprinting_main.R`: orchestrator (edit-only DV/INIT_SET/MODEL).

### Notes
- Initial-condition variables default to power centrality p75 set. Switch via `INIT_SET`.
- ZINB retains cross-firm initial-condition effects via random intercept + Mundlak means; use `poisson_fe` only for robustness since firm FE would absorb firm-level constants.
- All outputs are written to `notebooks/analysis_outputs/` with informative filenames.

## Table of Contents
1. [Installation](#installation)
2. [Quick Start](#quick-start)
3. [Python Preprocessing](#python-preprocessing)
4. [R Regression Analysis](#r-regression-analysis)
5. [Complete Workflows](#complete-workflows)
6. [Troubleshooting](#troubleshooting)

---

## Installation

### Prerequisites
- Python 3.9+ 
- R 4.0+
- 8GB+ RAM (16GB recommended)
- 4+ CPU cores (8+ recommended for parallel processing)

### Python Environment Setup

```bash
# Create and activate virtual environment
python -m venv finenv
source finenv/bin/activate  # On Windows: finenv\Scripts\activate

# Install package
cd python_preprocessing
pip install -e .

# Or with development tools
pip install -e ".[dev]"
```

### R Package Installation

```r
# Required R packages
install.packages(c(
  "arrow",      # Parquet files
  "survival",   # clogit
  "plm",        # Panel data models
  "car",        # VIF diagnostics
  "dplyr",      # Data manipulation
  "tidyr",      # Data tidying
  "broom"       # Model tidying
))
```

---

## Quick Start

### 1. Python: Data Loading and Preprocessing

```python
from vc_analysis.data import loader, filter as data_filter
from vc_analysis.config import parameters

# Configure
params = parameters.QUICK_TEST_PARAMS  # For testing

# Load data
data = loader.load_data_with_cache()

# Filter
filtered_df = data_filter.apply_standard_filters(
    data['round'], 
    params.filter
)

print(f"Loaded {len(filtered_df)} investment records")
```

### 2. Python: Network Construction and Centrality

```python
from vc_analysis.network import construction, centrality

# Construct networks (parallel)
years = list(range(1980, 2023))
networks = construction.construct_networks_for_years(
    round_df=filtered_df,
    years=years,
    use_parallel=True,
    n_jobs=-1
)

# Compute centralities (parallel)
centrality_df = centrality.compute_centralities_for_networks(
    networks=networks,
    use_parallel=True
)

print(f"Computed centralities for {len(centrality_df)} firm-years")
```

### 3. R: Load and Analyze

```r
# Load R scripts
source("R/regression/data_loader.R")
source("R/regression/cvc_regression.R")

# Load preprocessed data
cvc_data <- load_cvc_data("processed_data/cvc_analysis")

# Run regression
models <- run_full_cvc_analysis(cvc_data)

# Check diagnostics
check_vif(models$full)

# Save results
save_cvc_results(models)
```

---

## Python Preprocessing

### Module Structure

```
vc_analysis/
├── config/        # Configuration (paths, constants, parameters)
├── data/          # Loading, merging, filtering
├── network/       # Network construction & centrality
├── distance/      # Geographic & industry distance
├── sampling/      # LeadVC & case-control sampling
├── variables/     # Performance, investment, diversity
└── utils/         # Parallel processing, I/O, validation
```

### Configuration

#### Edit Paths

```python
# vc_analysis/config/paths.py
BASE_DIR = Path("/path/to/your/VC/data")
```

#### Adjust Parameters

```python
from vc_analysis.config import parameters

# Create custom parameters
custom_params = parameters.PipelineParameters(
    filter=parameters.FilterParameters(
        us_only=True,
        min_year=1980,
        max_year=2022,
        exclude_vc_types=['Angel', 'Individual']
    ),
    network=parameters.NetworkParameters(
        time_window=5,
        edge_cutpoint=1
    ),
    sampling=parameters.SamplingParameters(
        ratio=10
    ),
    parallel=parameters.ParallelParameters(
        n_jobs=-1  # Use all cores
    )
)
```

### Data Pipeline

#### Step 1: Load Raw Data

```python
from vc_analysis.data import loader

# Load with caching (fast subsequent runs)
data = loader.load_data_with_cache(
    use_cache=True,
    force_reload=False,  # Set True to reload from Excel
    parallel=True,
    n_jobs=4
)

# Returns dict with keys: 'round', 'company', 'firm', 'fund'
round_df = data['round']
company_df = data['company']
firm_df = data['firm']
```

#### Step 2: Filter and Clean

```python
from vc_analysis.data import filter as data_filter

# Apply standard filters
filtered_df = data_filter.apply_standard_filters(
    round_df, 
    custom_params.filter
)

# Or apply individual filters
us_only = data_filter.filter_by_country(round_df, 'United States')
year_range = data_filter.filter_by_year_range(us_only, 1980, 2022)
no_angels = data_filter.filter_by_vc_type(year_range, ['Angel', 'Individual'])
```

#### Step 3: Merge Datasets

```python
from vc_analysis.data import merger

# Create integrated dataset
integrated_df = merger.create_analysis_dataset(data)
# Includes round + company + firm data merged
```

### Network Analysis

#### Network Construction

```python
from vc_analysis.network import construction

# Single network
network_2020 = construction.construct_vc_network(
    round_df=filtered_df,
    year=2020,
    time_window=5,  # Use 2015-2019 data
    edge_cutpoint=1  # Minimum co-investment count
)

print(f"2020 network: {network_2020.number_of_nodes()} VCs, "
      f"{network_2020.number_of_edges()} partnerships")

# Multiple networks (parallel)
years = list(range(1980, 2023))
networks = construction.construct_networks_for_years(
    round_df=filtered_df,
    years=years,
    time_window=5,
    edge_cutpoint=1,
    use_parallel=True,
    n_jobs=-1  # Use all available cores
)
```

#### Centrality Calculation

```python
from vc_analysis.network import centrality

# Single network centrality
cent_2020 = centrality.compute_all_centralities(
    G=network_2020,
    year=2020,
    compute_degree=True,
    compute_betweenness=True,
    compute_power=True,
    compute_constraint_measure=True,
    power_beta_values=[0.0, 0.75, 0.99],
    use_approximate_betweenness=True
)

# Multiple networks (parallel)
centrality_df = centrality.compute_centralities_for_networks(
    networks=networks,
    use_parallel=True,
    n_jobs=-1
)

print(centrality_df.head())
# Columns: firmname, year, dgr_cent, btw_cent, pwr_p0, pwr_p75, pwr_p99, constraint
```

### Distance Calculations

#### Network Distance

```python
from vc_analysis.network import distance

# Compute pairwise network distances
network_dist_df = distance.compute_network_distances(
    G=network_2020,
    max_distance=10
)

# Columns: vc1, vc2, distance, dist1, dist2, dist3plus
```

#### Geographic Distance

```python
from vc_analysis.distance import geographic

# Requires zipcode coordinates in data
geo_dist_df = geographic.compute_geographic_distances(
    df=vc_pairs_df,  # DataFrame with VC pairs
    firm1_col='vc1',
    firm2_col='vc2'
)
```

#### Industry Diversity (Blau Index)

```python
from vc_analysis.distance import industry

# Compute Blau index for portfolio diversity
blau_df = industry.compute_blau_index(
    df=investment_counts_df,  # Industry investment counts
    firm_col='firmname',
    industry_cols=['ind_IT', 'ind_Healthcare', 'ind_Energy', ...]
)
```

### Sampling

#### LeadVC Identification

```python
from vc_analysis.sampling import leadvc

# Identify lead VCs
leadvc_df = leadvc.identify_lead_vcs(
    round_df=filtered_df,
    first_round_weight=3.0,
    investment_ratio_weight=2.0,
    total_amount_weight=1.0,
    random_state=123
)

# Columns: comname, leadVC
```

#### Case-Control Sampling

```python
from vc_analysis.sampling import case_control

# 1:10 sampling
sampled_df = case_control.case_control_sampling(
    round_df=filtered_df,
    leadvc_df=leadvc_df,
    ratio=10,
    replacement=True,
    random_state=123
)

# Columns: quarter, leadVC, coVC, comname, realized (1=case, 0=control)
```

### Variable Creation

#### Performance Variables

```python
from vc_analysis.variables import performance

# Calculate exit numbers
exit_df = performance.calculate_exit_numbers(
    round_df=filtered_df,
    company_df=company_df,
    exit_window=5
)

# Columns: firmname, year, exitNum, ipoNum, MnANum
```

#### Investment Metrics

```python
from vc_analysis.variables import investment

# Calculate investment metrics
inv_df = investment.calculate_investment_metrics(
    round_df=filtered_df
)

# Columns: firmname, year, numInvestments, totalInvested
```

### Saving Results

```python
from vc_analysis.utils import io
from vc_analysis.config import paths

# Save to Parquet (recommended)
output_path = paths.get_output_path('cvc', 'final_data', 'parquet')
io.save_parquet(final_df, output_path, compression='snappy')

# File is compressed and ready for R
print(f"Saved {len(final_df)} rows to {output_path}")
```

---

## R Regression Analysis

### Loading Data

```r
# Load R scripts
source("R/regression/data_loader.R")

# Load CVC analysis data
cvc_data <- load_cvc_data("processed_data/cvc_analysis")

# Or load imprinting data
imprinting_data <- load_imprinting_data("processed_data/imprinting_analysis")

# Check data
print_summary_stats(cvc_data, c("dgr_cent", "btw_cent", "realized"))
```

### CVC Analysis

```r
source("R/regression/cvc_regression.R")

# Run full analysis (all model specifications)
models <- run_full_cvc_analysis(cvc_data)
# Returns list: models$h0, models$h1, models$h2, models$h3, models$full

# Run custom model
formula_custom <- realized ~ coVC_dgr + coVC_btw + 
                            coVC_age + leadVC_dgr + 
                            strata(strata_id)
model_custom <- run_cvc_clogit(cvc_data, formula_custom)

# Compare models
comparison <- compare_models(models)

# Save results
save_cvc_results(models, output_dir = "results")
```

### Imprinting Analysis

```r
source("R/regression/imprinting_regression.R")

# Run full analysis
models <- run_full_imprinting_analysis(imprinting_data)
# Returns list: models$h0, models$h1, models$h2, models$full

# Run custom model
formula_custom <- exitNum ~ timesince + I(timesince^2) +
                           p_dgr_1y + f_dgr_1y +
                           dgr_1y + firmage
model_custom <- run_panel_glm(imprinting_data, formula_custom)

# Save results
save_imprinting_results(models, output_dir = "results")
```

### Diagnostics

```r
source("R/regression/diagnostics.R")

# Check VIF (multicollinearity)
vif_values <- check_vif(model, threshold = 10)

# Check condition index
condition_idx <- check_condition_index(
  cvc_data, 
  var_names = c("dgr_cent", "btw_cent", "pwr_p75")
)

# Model fit statistics
fit_stats <- get_fit_statistics(model)

# Robust standard errors (clustered)
robust_results <- check_clustered_se(model, cluster_var = "leadVC")

# Subsample analysis
subsamples <- list(
  "early_years" = "year >= 1980 & year <= 2000",
  "recent_years" = "year >= 2001"
)
subsample_models <- run_subsample_analysis(
  cvc_data, 
  formula, 
  subsamples
)

# Compare coefficients across models
coef_comparison <- compare_coefficients(
  models, 
  coef_names = c("coVC_dgr", "coVC_btw", "geo_distance")
)
```

---

## Complete Workflows

### CVC Partnership Analysis (End-to-End)

```python
# ========== Python Preprocessing ==========
from vc_analysis.data import loader, filter as data_filter, merger
from vc_analysis.network import construction, centrality, distance as net_dist
from vc_analysis.distance import geographic, industry
from vc_analysis.sampling import leadvc, case_control
from vc_analysis.variables import performance, investment
from vc_analysis.utils import io
from vc_analysis.config import parameters, paths

# 1. Load data
data = loader.load_data_with_cache()

# 2. Filter
params = parameters.FULL_ANALYSIS_PARAMS
filtered_df = data_filter.apply_standard_filters(data['round'], params.filter)

# 3. Identify lead VCs
leadvc_df = leadvc.identify_lead_vcs(filtered_df)

# 4. Construct networks
networks = construction.construct_networks_for_years(
    filtered_df, years=range(1980, 2023), use_parallel=True
)

# 5. Compute centralities
centrality_df = centrality.compute_centralities_for_networks(
    networks, use_parallel=True
)

# 6. Calculate distances
# ... (network distance, geographic distance, industry distance)

# 7. Calculate performance variables
exit_df = performance.calculate_exit_numbers(filtered_df, data['company'])

# 8. Case-control sampling
sampled_df = case_control.case_control_sampling(
    filtered_df, leadvc_df, ratio=10
)

# 9. Merge all variables
final_df = (
    sampled_df
    .merge(centrality_df, left_on=['leadVC', 'year'], right_on=['firmname', 'year'])
    .merge(centrality_df, left_on=['coVC', 'year'], right_on=['firmname', 'year'], suffixes=('_lead', '_co'))
    # ... merge distances, performance, etc.
)

# 10. Save
output_path = paths.get_output_path('cvc', 'final_data', 'parquet')
io.save_parquet(final_df, output_path)
```

```r
# ========== R Regression Analysis ==========
source("R/regression/data_loader.R")
source("R/regression/cvc_regression.R")
source("R/regression/diagnostics.R")

# 1. Load preprocessed data
cvc_data <- load_cvc_data()

# 2. Run full analysis
models <- run_full_cvc_analysis(cvc_data)

# 3. Diagnostics
check_vif(models$full)
get_fit_statistics(models$full)

# 4. Save results
save_cvc_results(models, output_dir = "results/cvc")
```

---

## Troubleshooting

### Python Issues

#### Memory Errors

```python
# Use conservative parallel settings
params.parallel.n_jobs = 4  # Instead of -1

# Enable chunking for large datasets
# (already implemented in data loader)
```

#### Slow Performance

```python
# Use quick test parameters first
params = parameters.QUICK_TEST_PARAMS

# Enable caching
data = loader.load_data_with_cache(use_cache=True)

# Use approximate betweenness for large networks
centrality_df = centrality.compute_centralities_for_networks(
    networks,
    use_approximate_betweenness=True
)
```

### R Issues

#### Missing Packages

```r
# Install all required packages
install.packages(c("arrow", "survival", "plm", "car", "dplyr", "tidyr", "broom"))
```

#### Parquet Loading Errors

```r
# Make sure arrow package is installed
if (!requireNamespace("arrow", quietly = TRUE)) {
  install.packages("arrow")
}

library(arrow)
df <- read_parquet("path/to/file.parquet")
```

#### Model Convergence Issues

```r
# Check for perfect collinearity
check_vif(model)

# Try different model specifications
# Remove highly correlated variables
```

---

## Support

For questions or issues:
1. Check this guide
2. Review documentation in `docs/`
3. Examine example scripts in `notebooks/`
4. Contact research team

Happy analyzing! 🚀

