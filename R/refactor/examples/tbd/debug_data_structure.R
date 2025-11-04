# Debug Data Structure Script
# Check the structure of loaded data

# Set working directory
setwd("/Users/suengj/Documents/Code/Python/Research/VC/raw/extract")

# Load data
comdta <- readRDS('company_data.rds') %>% as_tibble()
firmdta <- readRDS('firm_data.rds') %>% as_tibble()
round <- readRDS("round_data_US.rds")

# Check round data structure
cat("Round data structure:\n")
cat("Dimensions:", dim(round), "\n")
cat("Columns:", colnames(round), "\n")
cat("First few rows:\n")
print(head(round))

# Check if event column exists
if ("event" %in% colnames(round)) {
  cat("\n✓ Event column exists\n")
} else {
  cat("\n✗ Event column does not exist\n")
  cat("Available columns:", colnames(round), "\n")
}

# Check if comname column exists
if ("comname" %in% colnames(round)) {
  cat("\n✓ Comname column exists\n")
} else {
  cat("\n✗ Comname column does not exist\n")
}

# Check data types
cat("\nData types:\n")
str(round) 