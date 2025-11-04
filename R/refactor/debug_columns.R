# Debug script to check round data columns
source("load_all_modules.R")
modules <- quick_setup()

# Load data
setwd("/Users/suengj/Documents/Code/Python/Research/VC/raw/extract")
round <- readRDS("round_data_US.rds")

cat("Round data dimensions:", dim(round), "\n")
cat("Round data columns:\n")
print(colnames(round))

cat("\nFirst few rows:\n")
print(head(round, 3))

# Check for amount-related columns
amount_cols <- grep("amt|amount|rnd", colnames(round), ignore.case = TRUE, value = TRUE)
cat("\nAmount-related columns:", amount_cols, "\n") 