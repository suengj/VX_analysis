# VC Network Analysis Constants
# Extracted from CVC_preprcs_v4.R and imprinting_Dec18.R

# Data validation constants
REQUIRED_COLUMNS <- list(
  company_data = c("comname", "comsitu", "date_ipo", "date_sit"),
  firm_data = c("firmname", "firmfounding", "firmtype"),
  round_data = c("firmname", "comname", "year", "rnddate")
)

# Industry classification (from CVC_preprcs_v4.R)
INDUSTRY_CODES <- list(
  "Internet Specific" = "ind1",
  "Medical/Health" = "ind2",
  "Consumer Related" = "ind3",
  "Semiconductors/Other Elect." = "ind4",
  "Communications and Media" = "ind5",
  "Industrial/Energy" = "ind6",
  "Computer Software and Services" = "ind7",
  "Computer Hardware" = "ind8",
  "Biotechnology" = "ind9",
  "Other Products" = "ind10"
)

# Exit types
EXIT_TYPES <- c("Went Public", "Merger", "Acquisition")

# VC types (from CVC_preprcs_v4.R)
VC_TYPES <- list(
  "Angel Group" = "Angel",
  "Individuals" = "Angel",
  "Corporate PE/Venture" = "CVC",
  "Investment Management Firm" = "Financial",
  "Bank Affiliated" = "Financial",
  "Private Equity Advisor or Fund of Funds" = "Financial",
  "SBIC" = "Financial",
  "Endowment, Foundation or Pension Fund" = "Financial",
  "Insurance Firm Affiliate" = "Financial",
  "Private Equity Firm" = "IVC",
  "Incubator/Development Program" = "Non-Financial",
  "Government Affiliated Program" = "Non-Financial",
  "University Program" = "Non-Financial",
  "Service Provider" = "Other",
  "Other" = "Other",
  "Non-Private Equity" = "Other"
)

# Geographic constants
GEOGRAPHIC_CONSTANTS <- list(
  ca_ma_states = c("MA", "CA"),
  default_zip_distance = 9999
)

# Network constants
NETWORK_CONSTANTS <- list(
  constraint_max = 1.125,
  power_centrality_epsilon = 10^-10
) 