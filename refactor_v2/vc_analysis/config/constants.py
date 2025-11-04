"""
Constants used in VC analysis

This module defines all constants including industry codes, exit types,
VC types, and other categorical variables.
"""

# Required columns for different data types
REQUIRED_ROUND_COLUMNS = [
    'firmname',
    'comname',
    'rnddate',
    'year',
    'RoundNumber',
    'RoundAmountDisclosedThou',
    'RoundAmountEstimatedThou',
    'CompanyStageLevel1'
]

REQUIRED_COMPANY_COLUMNS = [
    'comname',
    'comsitu',
    'date_sit',
    'date_ipo',
    'comindmnr',
    'comnation',
    'comzip'
]

REQUIRED_FIRM_COLUMNS = [
    'firmname',
    'firmfounding',
    'firmtype',
    'firmnation',
    'firmzip'
]

# Industry codes (simplified)
INDUSTRY_CODES = {
    'IT': ['Software', 'Internet', 'Computer Hardware', 'Semiconductors'],
    'Healthcare': ['Biotechnology', 'Medical Devices', 'Healthcare Services'],
    'Energy': ['Energy', 'CleanTech'],
    'Consumer': ['Consumer Products', 'Retail'],
    'Financial': ['Financial Services', 'Insurance'],
    'Industrial': ['Industrial/Energy', 'Manufacturing'],
    'Other': ['Other']
}

# Exit types
EXIT_TYPES = {
    'IPO': ['Went Public', 'Public'],
    'MA': ['Merger', 'Acquisition', 'Acquired'],
    'OTHER': ['Closed', 'Operating']
}

# VC types
VC_TYPES = {
    'CVC': 'Corporate VC',
    'IVC': 'Independent VC',
    'Angel': 'Angel',
    'PE': 'Private Equity',
    'HF': 'Hedge Fund',
    'Other': 'Other'
}

# Geographic constants
GEOGRAPHIC_CONSTANTS = {
    'US_ONLY': True,
    'EARTH_RADIUS_KM': 6371,  # For Haversine distance
    'EARTH_RADIUS_MILES': 3959
}

# Network constants
NETWORK_CONSTANTS = {
    'MIN_NODES': 2,
    'MIN_EDGES': 1,
    'DEFAULT_TIME_WINDOW': 5,
    'DEFAULT_EDGE_CUTPOINT': 1
}

# Analysis constants
ANALYSIS_CONSTANTS = {
    'MIN_YEAR': 1970,
    'MAX_YEAR': 2023,
    'MIN_FIRM_AGE': 0,
    'DEFAULT_SAMPLING_RATIO': 10,
    'DEFAULT_IMPRINTING_PERIOD': 3,
    'DEFAULT_EXIT_WINDOW': 5
}

# Data type optimization
DTYPE_OPTIMIZATION = {
    'firmname': 'category',
    'comname': 'category',
    'firmtype': 'category',
    'comsitu': 'category',
    'comindmnr': 'category',
    'CompanyStageLevel1': 'category',
    'firmnation': 'category',
    'comnation': 'category',
    'year': 'int16',
    'RoundNumber': 'int16',
    'RoundAmountDisclosedThou': 'float32',
    'RoundAmountEstimatedThou': 'float32'
}

# Random seed for reproducibility
RANDOM_SEED = 123

# Parallel processing
N_JOBS_DEFAULT = -1  # Use all available cores
N_JOBS_CONSERVATIVE = 4  # Conservative for memory-intensive tasks

# File formats
PARQUET_COMPRESSION = 'snappy'
PICKLE_COMPRESSION = 'gzip'

# Validation thresholds
VALIDATION_THRESHOLDS = {
    'max_missing_rate': 0.5,  # Maximum missing data rate
    'min_sample_size': 100,  # Minimum sample size
    'max_vif': 10,  # Maximum VIF for collinearity check
}

# ============================================================================
# Firm-level Variable Calculation Constants
# ============================================================================

# Early stage definitions
# Source: Original R code (CVC_preprcs_v4.R)
# Column priority: comstage1 > comstage2 > comstage3
EARLY_STAGE_DEFINITIONS = {
    'stage_columns': ['comstage1', 'comstage2', 'comstage3'],  # Try in order
    'early_stage_values': ['Startup/Seed', 'Early Stage', 'Seed', 'Series A', 'Series B']
}

# Firm HQ high-value states (CA, MA)
# Rationale: Silicon Valley (CA) and Boston (MA) are major VC hubs
FIRM_HQ_HIGH_VALUE_STATES = {
    'state_codes': ['CA', 'MA'],
    'state_names': ['California', 'Massachusetts']
}

# Undisclosed filtering (CRITICAL PREPROCESSING)
# Source: Original R code (CVC_preprcs_v4.R, lines 653-654)
UNDISCLOSED_FILTERS = {
    'firmname': 'Undisclosed Firm',
    'comname': 'Undisclosed Company'
}

# Performance metric calculation settings
# Based on original R code: VC_exit_num, VC_IPO_num, VC_MnA_num functions
PERFORMANCE_SETTINGS = {
    'situation_column': 'comsitu',  # Company situation column
    'situation_date_column': 'date_sit',  # Situation date column
    'ipo_date_column': 'date_ipo',  # IPO date column
    'ipo_values': ['Went Public'],  # comsitu values for IPO
    'mna_values': ['Merger', 'Acquisition'],  # comsitu values for M&A
    'all_exit_values': ['Went Public', 'Merger', 'Acquisition'],  # All exit types
    'lookback_years': 0  # Default: 당해 연도만 (yr_cut parameter, 0 = current year only)
}

# Investment amount columns (in order of preference)
# Try first column, if not available, try next
INVESTMENT_AMOUNT_COLUMNS = [
    'RoundAmountDisclosedThou',  # Primary (disclosed amount)
    'RoundAmountEstimatedThou',  # Secondary (estimated if disclosed not available)
    'RoundAmount'  # Fallback
]

# Diversity calculation settings
DIVERSITY_SETTINGS = {
    'min_categories': 2,  # Minimum categories for meaningful diversity
    'industry_column': 'comindmnr',  # Primary industry column (사용: comindmnr)
    'industry_minor_column': 'comindmnr',  # Detailed industry column
    'state_column': 'comstate',  # Company state for geographic diversity
    'stage_column': 'CompanyStageLevel1'  # Stage for stage diversity
}

