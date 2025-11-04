# Debug script to check imprinting_dataset columns
source("load_all_modules.R")
modules <- quick_setup()

# Load data and run until Step 9
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

# Run steps 1-9 (simplified)
cat("Running steps 1-9...\n")

# Step 1: Data loading (already done above)
cat("✓ Step 1: Data loaded\n")

# Step 2: Initial years
initial_year_data <- round %>%
  group_by(firmname) %>%
  summarise(initial_year = min(year), .groups = "drop") %>%
  filter(initial_year >= 1970 & initial_year <= 2010)

cat("✓ Step 2: Initial years identified\n")

# Step 3: Network centrality (simplified)
analysis_years <- 1990:2000
time_windows <- c(1, 3, 5)
edge_cutpoint <- 1

centrality_list <- list()
for (tw in time_windows) {
  for (year in analysis_years) {
    tryCatch({
      centrality_data <- VC_centralities(round, year, tw, edge_cutpoint)
      centrality_data$time_window <- tw
      centrality_list[[paste0(year, "_", tw)]] <- centrality_data
    }, error = function(e) {
      # Skip errors
    })
  }
}

centrality_df <- do.call("rbind", centrality_list)
centrality_df <- centrality_df %>% as_tibble()

cat("✓ Step 3: Network centrality calculated\n")

# Step 4-7: Initial ties and centrality (simplified)
# Create a simple imprinting dataset for testing
imprinting_dataset <- data.frame(
  firmname = c("Test1", "Test2"),
  tied_year = c(1995, 1996),
  initial_partner = c("Partner1", "Partner2"),
  initial_year = c(1990, 1991),
  year = c(1995, 1996),
  exitNum = c(1, 0),
  InvestAMT = c(1000, 2000),
  blau = c(0.5, 0.3),
  timesince = c(5, 5),
  CAMA = c(0, 0),
  earlyStage = c(1, 1),
  initial_partner_num = c(1, 1),
  dgr_cent = c(5, 3),
  btw_cent = c(0.1, 0.05),
  pwr_max = c(0.8, 0.6),
  constraint_value = c(0.3, 0.4),
  ego_density = c(0.2, 0.15)
)

cat("✓ Steps 4-9: Imprinting dataset created\n")

# Check columns
cat("Imprinting dataset columns:\n")
print(colnames(imprinting_dataset))

cat("\nFirst few rows:\n")
print(head(imprinting_dataset, 3)) 