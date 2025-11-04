# Network Generation Test Script
# Quick test to diagnose network creation issues

# Load modules
source("load_all_modules.R")
modules <- quick_setup()

# Load data
setwd("/Users/suengj/Documents/Code/Python/Research/VC/raw/extract")
comdta <- readRDS('company_data.rds') %>% as_tibble()
firmdta <- readRDS('firm_data.rds') %>% as_tibble()
round <- readRDS("round_data_US.rds")

# Process data (simplified)
comdta <- comdta %>%
  group_by(comname) %>%
  slice(1) %>%
  ungroup()

firmdta <- firmdta %>%
  group_by(firmname) %>%
  slice(1) %>%
  ungroup()

round <- round %>%
  filter(firmname != "Undisclosed Firm", comname != "Undisclosed Company") %>%
  mutate(year = year(rnddate)) %>%
  filter(year >= 1990 & year <= 2000) %>%
  mutate(event = paste(comname, year, sep = "-"))

# Test network creation for specific years
test_years <- c(1995, 1996, 1997)
time_window <- 3

cat("Testing network creation for years:", test_years, "\n")
cat("Time window:", time_window, "\n")
cat("Round data dimensions:", dim(round), "\n")
cat("Round years range:", range(round$year, na.rm = TRUE), "\n")

for (year in test_years) {
  cat("\n=== Testing year", year, "===\n")
  
  tryCatch({
    # Test VC_matrix directly
    network <- VC_matrix(round, year, time_window, edge_cutpoint = 1)
    cat("✓ Network created successfully for year", year, "\n")
    cat("  Vertices:", vcount(network), "Edges:", ecount(network), "\n")
    
    # Test centrality calculation
    centrality <- VC_centralities(round, year, time_window, edge_cutpoint = 1)
    cat("✓ Centrality calculated successfully for year", year, "\n")
    cat("  Centrality data rows:", nrow(centrality), "\n")
    
  }, error = function(e) {
    cat("✗ Error for year", year, ":", e$message, "\n")
  })
} 