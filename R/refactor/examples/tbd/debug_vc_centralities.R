# Debug VC_centralities Function
# Test the function directly to see what it returns

# Set working directory
setwd("/Users/suengj/Documents/Code/Python/Research/VC/raw/extract")

# Load data
round <- readRDS("round_data_US.rds")

# Load modules
source("/Users/suengj/Documents/Code/Python/Research/VC/R/refactor/load_all_modules.R")
modules <- quick_setup()

# Define constants if not loaded properly
if (!exists("EXIT_TYPES")) {
  EXIT_TYPES <- c("Went Public", "Merger", "Acquisition")
}

# Process round data
round <- round %>%
  filter(firmname != "Undisclosed Firm", comname != "Undisclosed Company") %>%
  mutate(year = year(rnddate), month = month(rnddate), day = day(rnddate)) %>%
  filter(year > 1979) %>%
  mutate(event = paste(comname, rnddate, sep = "-"))

cat("Round data processed. Dimensions:", dim(round), "\n")
cat("Round data columns:", colnames(round), "\n")

# Test VC_centralities function directly
cat("\nTesting VC_centralities function...\n")

# Test with a specific year and time window
test_year <- 1985
test_time_window <- 1
test_edge_cutpoint <- 1

cat("Testing with year:", test_year, "time_window:", test_time_window, "\n")

tryCatch({
  result <- VC_centralities(round, test_year, test_time_window, test_edge_cutpoint)
  cat("VC_centralities result:\n")
  cat("Dimensions:", dim(result), "\n")
  cat("Columns:", colnames(result), "\n")
  if (nrow(result) > 0) {
    cat("First few rows:\n")
    print(head(result))
  } else {
    cat("Result is empty data.frame\n")
  }
}, error = function(e) {
  cat("Error in VC_centralities:", e$message, "\n")
})

# Test VC_matrix function directly
cat("\nTesting VC_matrix function...\n")

tryCatch({
  network <- VC_matrix(round, test_year, test_time_window, test_edge_cutpoint)
  cat("VC_matrix result:\n")
  cat("Network type:", class(network), "\n")
  if (inherits(network, "igraph")) {
    cat("Number of vertices:", vcount(network), "\n")
    cat("Number of edges:", ecount(network), "\n")
    if (vcount(network) > 0) {
      cat("Vertex names (first 10):", head(V(network)$name, 10), "\n")
    }
  }
}, error = function(e) {
  cat("Error in VC_matrix:", e$message, "\n")
}) 