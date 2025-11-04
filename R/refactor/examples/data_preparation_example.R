# Data Preparation Example Script
# Converts raw Excel files to .rds format for R analysis

# Set working directory to data location
setwd("/Users/suengj/Documents/Code/Python/Research/VC/raw/extract")

# Load data preparation functions
source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/R/data_preparation.R")

# =============================================================================
# DATA PREPARATION PIPELINE
# =============================================================================

cat("=== VC Data Preparation Pipeline ===\n")
cat("This script converts raw Excel files to .rds format\n\n")

# Check if raw data directories exist
raw_dirs <- c(
  "/Users/suengj/Documents/Code/Python/Research/VC/raw/round/US",
  "/Users/suengj/Documents/Code/Python/Research/VC/raw/comp", 
  "/Users/suengj/Documents/Code/Python/Research/VC/raw/firm"
)

cat("Checking raw data directories...\n")
for (dir in raw_dirs) {
  if (dir.exists(dir)) {
    cat("✓", dir, "\n")
  } else {
    cat("❌", dir, "(not found)\n")
  }
}
cat("\n")

# Process all data
cat("Starting data processing...\n")
processed_data <- process_all_data()

# =============================================================================
# VERIFICATION
# =============================================================================

cat("\n=== Verification ===\n")

# Check if .rds files were created
rds_files <- c("round_data_US.rds", "company_data.rds", "firm_data.rds")
created_files <- list.files(pattern = "\\.rds$")

cat("Created .rds files:\n")
for (file in rds_files) {
  if (file %in% created_files) {
    file_size <- file.size(file)
    cat("✓", file, sprintf("(%.1f MB)\n", file_size / 1024^2))
  } else {
    cat("❌", file, "(not found)\n")
  }
}

# Test loading the created files
cat("\nTesting file loading...\n")
tryCatch({
  test_round <- readRDS("round_data_US.rds")
  cat("✓ round_data_US.rds loaded successfully (", nrow(test_round), "rows,", ncol(test_round), "columns)\n")
}, error = function(e) {
  cat("❌ Error loading round_data_US.rds:", e$message, "\n")
})

tryCatch({
  test_company <- readRDS("company_data.rds")
  cat("✓ company_data.rds loaded successfully (", nrow(test_company), "rows,", ncol(test_company), "columns)\n")
}, error = function(e) {
  cat("❌ Error loading company_data.rds:", e$message, "\n")
})

tryCatch({
  test_firm <- readRDS("firm_data.rds")
  cat("✓ firm_data.rds loaded successfully (", nrow(test_firm), "rows,", ncol(test_firm), "columns)\n")
}, error = function(e) {
  cat("❌ Error loading firm_data.rds:", e$message, "\n")
})

# =============================================================================
# SUMMARY
# =============================================================================

cat("\n=== Summary ===\n")
cat("Data preparation completed!\n")
cat("The following .rds files are now available for analysis:\n")
cat("- round_data_US.rds: Investment round data\n")
cat("- company_data.rds: Company information data\n") 
cat("- firm_data.rds: VC firm information data\n\n")

cat("You can now run the analysis example scripts:\n")
cat("- imprinting_analysis_example.R\n")
cat("- cvc_analysis_example.R\n")
cat("- regression_analysis_example.R\n")
cat("- performance_analysis_example.R\n")

cat("\n✓ Data preparation pipeline completed successfully!\n") 