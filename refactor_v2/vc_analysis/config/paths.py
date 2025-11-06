"""
File paths configuration for VC analysis

This module defines all file paths used in the analysis pipeline.
Modify these paths according to your local environment.
"""

import os
from pathlib import Path

# Base directory (adjust to your environment)
BASE_DIR = Path("/Users/suengj/Documents/Code/Python/Research/VC")

# Raw data directories
DATA_DIR = BASE_DIR / "data"

# Processed data directories
PROCESSED_DATA_DIR = BASE_DIR / "refactor_v2" / "processed_data"
PROCESSED_DATA_DIR.mkdir(parents=True, exist_ok=True)

# Analysis-specific directories
CVC_ANALYSIS_DIR = PROCESSED_DATA_DIR / "cvc_analysis"
IMPRINTING_ANALYSIS_DIR = PROCESSED_DATA_DIR / "imprinting_analysis"

# Create output directories if they don't exist
for dir_path in [CVC_ANALYSIS_DIR, IMPRINTING_ANALYSIS_DIR]:
    dir_path.mkdir(parents=True, exist_ok=True)

# Results directories
RESULTS_DIR = BASE_DIR / "refactor_v2" / "results"
RESULTS_DIR.mkdir(parents=True, exist_ok=True)

# Cache directories
CACHE_DIR = BASE_DIR / "refactor_v2" / "cache"
CACHE_DIR.mkdir(parents=True, exist_ok=True)

# Log directories
LOG_DIR = BASE_DIR / "refactor_v2" / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)

# Specific file paths
COMDTA_FILE = DATA_DIR / "comdta_new.csv"
FIRMDTA_FILE = DATA_DIR / "firmdta_all.xlsx"
ROUND_FILE = DATA_DIR / "round_Mar25.csv"
FUND_FILE = DATA_DIR / "fund_all.xlsx"
FIRM_CHECK_FILE = DATA_DIR / "firm_check.csv"


def get_round_files():
    """Get list of all round data files"""
    if ROUND_FILE.exists():
        return [ROUND_FILE]
        return []


def get_company_files():
    """Get list of all company data files"""
    if COMDTA_FILE.exists():
        return [COMDTA_FILE]
        return []


def get_cache_path(name, extension='parquet'):
    """Get cache file path"""
    return CACHE_DIR / f"{name}.{extension}"


def get_output_path(analysis_type, name, extension='parquet'):
    """Get output file path for specific analysis"""
    if analysis_type == 'cvc':
        output_dir = CVC_ANALYSIS_DIR
    elif analysis_type == 'imprinting':
        output_dir = IMPRINTING_ANALYSIS_DIR
    else:
        output_dir = PROCESSED_DATA_DIR
    
    return output_dir / f"{name}.{extension}"


# Print configuration on import (for debugging)
if __name__ == "__main__":
    print(f"Base directory: {BASE_DIR}")
    print(f"Data directory: {DATA_DIR}")
    print(f"Processed data directory: {PROCESSED_DATA_DIR}")
    print(f"Round files found: {len(get_round_files())}")
    print(f"Company files found: {len(get_company_files())}")

