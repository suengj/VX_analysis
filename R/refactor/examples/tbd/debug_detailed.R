# Detailed Debug Script
# Check each step of the process

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
  mutate(
    quarter = ceiling(month / 3),
    timewave = year,
    event = paste(comname, timewave, sep = "-")
  )

cat("Round data processed. Dimensions:", dim(round), "\n")

# Test year and time window
test_year <- 1985
test_time_window <- 1
test_edge_cutpoint <- 1

cat("\nTesting with year:", test_year, "time_window:", test_time_window, "\n")

# Step 1: Test VC_matrix
cat("\n=== Step 1: Testing VC_matrix ===\n")

tryCatch({
  # Check filtered data
  filtered_data <- round[round$year <= test_year-1 & round$year >= test_year-test_time_window, 
                         c("firmname", "event")]
  cat("Filtered data dimensions:", dim(filtered_data), "\n")
  cat("Unique firms:", length(unique(filtered_data$firmname)), "\n")
  cat("Unique events:", length(unique(filtered_data$event)), "\n")
  
  # Check for overlapping names
  firmnames <- unique(filtered_data$firmname)
  events <- unique(filtered_data$event)
  overlap <- intersect(firmnames, events)
  cat("Overlapping names:", length(overlap), "\n")
  if (length(overlap) > 0) {
    cat("First few overlaps:", head(overlap, 3), "\n")
  }
  
  # Create edgelist
  edgelist <- as.matrix(filtered_data)
  cat("Edgelist dimensions:", dim(edgelist), "\n")
  
  # Create graph
  twomode <- graph_from_edgelist(edgelist, directed = FALSE)
  cat("Two-mode graph created. Vertices:", vcount(twomode), "Edges:", ecount(twomode), "\n")
  
  # Set bipartite type
  V(twomode)$type <- V(twomode)$name %in% edgelist[,2]
  cat("Bipartite types set. TRUE count:", sum(V(twomode)$type), "FALSE count:", sum(!V(twomode)$type), "\n")
  
  # Check if bipartite
  cat("Is bipartite:", is_bipartite(twomode), "\n")
  
  # Create projection
  onemode <- bipartite_projection(twomode)$proj1
  cat("One-mode projection created. Vertices:", vcount(onemode), "Edges:", ecount(onemode), "\n")
  
}, error = function(e) {
  cat("Error in VC_matrix step:", e$message, "\n")
  cat("Error location:", e$call, "\n")
})

# Step 2: Test centrality calculations
cat("\n=== Step 2: Testing centrality calculations ===\n")

tryCatch({
  network <- VC_matrix(round, test_year, test_time_window, test_edge_cutpoint)
  
  cat("Network created successfully\n")
  cat("Vertices:", vcount(network), "Edges:", ecount(network), "\n")
  
  # Test each centrality measure
  dgr_cent <- degree(network)
  cat("Degree centrality length:", length(dgr_cent), "\n")
  
  btw_cent <- betweenness(network)
  cat("Betweenness centrality length:", length(btw_cent), "\n")
  
  # Test eigen calculation
  adj_matrix <- as_adjacency_matrix(network)
  eigen_vals <- eigen(adj_matrix)$values
  upsilon <- max(eigen_vals)
  cat("Upsilon (max eigenvalue):", upsilon, "\n")
  
  pwr_p75 <- power_centrality(network, exponent = (1/upsilon)*0.75)
  cat("Power centrality (0.75) length:", length(pwr_p75), "\n")
  
  constraint_value <- constraint(network)
  cat("Constraint length:", length(constraint_value), "\n")
  
  # Test cbind
  test_cbind <- cbind(test_year, dgr_cent, btw_cent, pwr_p75)
  cat("cbind test dimensions:", dim(test_cbind), "\n")
  
}, error = function(e) {
  cat("Error in centrality calculations:", e$message, "\n")
  cat("Error location:", e$call, "\n")
}) 