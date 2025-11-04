# VC Network Analysis Parameters Configuration
# Extracted from CVC_preprcs_v4.R and imprinting_Dec18.R

# Network construction parameters
NETWORK_PARAMS <- list(
  default_time_window = 5,
  default_edge_cutpoint = 5,
  projection_types = c("vc_vc", "event_event"),
  centrality_beta_values = c(0.75, 1.0, 0.0)
)

# Sampling parameters
SAMPLING_PARAMS <- list(
  default_ratio = 10,
  available_ratios = c(1, 5, 10, 15),
  random_seed = 123
)

# Analysis parameters
ANALYSIS_PARAMS <- list(
  min_year = 1980,
  max_year = 2022,
  imprinting_periods = c(1, 3, 5),
  performance_windows = c(1, 3, 5)
)

# Example data filtering (for faster testing)
EXAMPLE_PARAMS <- list(
  use_limited_data = TRUE,  # Set to FALSE for full analysis
  example_min_year = 1990,
  example_max_year = 2000,
  example_years = 1990:2000
)

# Data filtering parameters
DATA_FILTERS <- list(
  min_year = 1980,
  max_year = 2022,
  us_only = TRUE,
  exclude_angel = TRUE,
  min_firm_age = 0
)

# Parallel processing parameters
PARALLEL_PARAMS <- list(
  capacity = 0.8,
  cores = round(parallel::detectCores() * 0.8, digits = 0)
)

# File output parameters
OUTPUT_PARAMS <- list(
  compression_level = 100,
  date_format = "%y%b%d",
  load_date = "23Mar25"
) 