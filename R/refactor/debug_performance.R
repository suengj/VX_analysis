# Debug script to check performance_data columns
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

# Create performance data
performance_years <- 1990:2000
performance_data <- calculate_performance_metrics(round, comdta, performance_years, time_window = 5)

cat("Performance data dimensions:", dim(performance_data), "\n")
cat("Performance data columns:\n")
print(colnames(performance_data))

cat("\nFirst few rows:\n")
print(head(performance_data, 3)) 