# Check Column Names Example Script
# Checks actual column names in raw Excel files

# Set working directory to data location
setwd("/Users/suengj/Documents/Code/Python/Research/VC/raw/extract")

# Load data preparation functions
source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/data_preparation.R")

# =============================================================================
# CHECK ACTUAL COLUMN NAMES
# =============================================================================

cat("=== VC Data Column Name Check ===\n")
cat("This script checks actual column names in raw Excel files\n\n")

# Check all column names
column_info <- check_all_columns()

# =============================================================================
# SUMMARY
# =============================================================================

cat("=== Summary ===\n")
cat("Column name check completed!\n")
cat("Use this information to update column mappings in data_preparation.R\n\n")

cat("Next steps:\n")
cat("1. Review the actual column names above\n")
cat("2. Update ROUND_COLUMN_MAPPING, COMPANY_COLUMN_MAPPING, FIRM_COLUMN_MAPPING\n")
cat("3. Run data_preparation_example.R again\n")

cat("\n✓ Column name check completed successfully!\n") 