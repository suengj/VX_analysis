# VC Network Analysis Paths Configuration
# Extracted from CVC_preprcs_v4.R and imprinting_Dec18.R

# Base paths (from CVC_preprcs_v4.R)
BASE_PATHS <- list(
  data = "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Yang, Rhee, Ma/data",
  results = "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Yang, Rhee, Ma/results",
  report = "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Yang, Rhee, Ma/report",
  data_new = "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Yang, Rhee, Ma/data/new",
  data_mar25 = "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Yang, Rhee, Ma/data/Mar25",
  refactor = "Research/VC/R/refactor"
)

# Imprinting analysis paths (from imprinting_Dec18.R)
IMPRINTING_PATHS <- list(
  data = "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Network Imprinting/dta",
  results = "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Network Imprinting/rst"
)

# Subdirectories
SUB_DIRS <- list(
  raw_data = "raw",
  processed_data = "processed",
  results = "results",
  logs = "logs",
  temp = "temp",
  configs = "configs"
)

# File patterns
FILE_PATTERNS <- list(
  company_data = "comdta_*.csv",
  firm_data = "firmdta_*.xlsx",
  round_data = "round_*.csv",
  fund_data = "fund_*.xlsx",
  corporate_vc = "corporateVC.csv"
) 