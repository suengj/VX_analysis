# Merge Issues Debugging Script
# 모든 merge 과정의 문제를 체계적으로 진단

source("load_all_modules.R")
modules <- quick_setup()

cat("=== MERGE ISSUES DEBUGGING START ===\n")

# 1. 데이터 로딩 및 기본 상태 확인
setwd("/Users/suengj/Documents/Code/Python/Research/VC/raw/extract")
comdta <- readRDS('company_data.rds') %>% as_tibble()
firmdta <- readRDS('firm_data.rds') %>% as_tibble()
round <- readRDS("round_data_US.rds")

cat("✓ Data loaded successfully\n")

# 2. 기본 데이터 전처리
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

cat("✓ Data preprocessing completed\n")

# 3. Initial year 계산 검증
cat("\n=== INITIAL YEAR VALIDATION ===\n")

initial_year_data <- round %>%
  group_by(firmname) %>%
  summarise(initial_year = min(year), .groups = "drop") %>%
  filter(initial_year >= 1970 & initial_year <= 2010)

cat("Initial year summary:\n")
print(summary(initial_year_data$initial_year))

# 4. Network centrality 계산 (간단한 버전)
cat("\n=== NETWORK CENTRALITY CALCULATION ===\n")

analysis_years <- 1990:2000
time_windows <- c(1, 3, 5)
edge_cutpoint <- 1

centrality_list <- list()
for (tw in time_windows) {
  for (year in analysis_years) {
    tryCatch({
      centrality_data <- VC_centralities(round, year, tw, edge_cutpoint)
      centrality_data$time_window <- tw
      centrality_data$year <- year
      centrality_list[[paste0(year, "_", tw)]] <- centrality_data
    }, error = function(e) {
      # Skip errors
    })
  }
}

centrality_df <- do.call("rbind", centrality_list)
centrality_df <- centrality_df %>% as_tibble()

cat("Centrality data created:\n")
cat("Dimensions:", dim(centrality_df), "\n")
cat("Non-zero centrality values:", sum(centrality_df$dgr_cent > 0, na.rm = TRUE), "\n")
cat("Sample centrality data:\n")
print(head(centrality_df[, c("firmname", "year", "time_window", "dgr_cent", "pwr_max")], 5))

# 5. Initial ties 계산 검증
cat("\n=== INITIAL TIES VALIDATION ===\n")

# 간단한 initial ties 계산
initial_ties <- round %>%
  group_by(firmname, comname, year) %>%
  summarise(.groups = "drop") %>%
  left_join(initial_year_data, by = "firmname") %>%
  filter(year >= initial_year & year <= initial_year + 5) %>%
  mutate(tied_year = year) %>%
  select(firmname, comname, tied_year, initial_year)

cat("Initial ties summary:\n")
cat("Total ties:", nrow(initial_ties), "\n")
cat("Initial year vs tied year comparison:\n")
print(table(initial_ties$initial_year <= initial_ties$tied_year))

# 6. Partner centrality 계산 검증
cat("\n=== PARTNER CENTRALITY VALIDATION ===\n")

# 간단한 partner centrality 계산
partner_centrality <- initial_ties %>%
  left_join(centrality_df %>% filter(time_window == 3), 
            by = c("firmname" = "firmname", "tied_year" = "year"))

cat("Partner centrality merge result:\n")
cat("Dimensions:", dim(partner_centrality), "\n")
cat("Non-zero centrality values:", sum(partner_centrality$dgr_cent > 0, na.rm = TRUE), "\n")
cat("Sample partner centrality data:\n")
print(head(partner_centrality[, c("firmname", "tied_year", "initial_year", "dgr_cent", "pwr_max")], 5))

# 7. Column naming 검증
cat("\n=== COLUMN NAMING VALIDATION ===\n")

# Test column renaming
test_df <- data.frame(
  dgr_cent = c(1, 2, 3),
  pwr_max = c(0.1, 0.2, 0.3),
  constraint_value = c(0.5, 0.6, 0.7)
)

cat("Original columns:", colnames(test_df), "\n")

# Test renaming logic
colnames_to_rename <- grep("^(dgr_cent|btw_cent|pwr_|constraint_value|ego_density)", colnames(test_df), value = TRUE)
for (col in colnames_to_rename) {
  new_name <- paste0("p_", col)
  colnames(test_df)[colnames(test_df) == col] <- new_name
}

cat("After renaming:", colnames(test_df), "\n")

# 8. Performance data 검증
cat("\n=== PERFORMANCE DATA VALIDATION ===\n")

# Create exit data
exit_data <- comdta %>%
  mutate(
    exit = ifelse(comsitu %in% c("Went Public", "Acquisition", "Merger") & 
                 (!is.na(date_ipo) | !is.na(date_sit)), 1, 0),
    ipoExit = ifelse(comsitu %in% c("Went Public") & 
                    (!is.na(date_ipo) | !is.na(date_sit)), 1, 0),
    MnAExit = ifelse(comsitu %in% c("Acquisition", "Merger") & 
                    !is.na(date_sit), 1, 0)
  ) %>%
  mutate(situ_yr = case_when(
    !is.na(date_sit) ~ year(date_sit),
    !is.na(date_ipo) ~ year(date_ipo),
    TRUE ~ NA_integer_
  ))

cat("Exit data summary:\n")
cat("Total companies with exit:", sum(exit_data$exit == 1, na.rm = TRUE), "\n")
cat("Exit years range:", range(exit_data$situ_yr, na.rm = TRUE), "\n")

# 9. Final merge test
cat("\n=== FINAL MERGE TEST ===\n")

# Create comprehensive dataset
final_dataset <- initial_ties %>%
  left_join(centrality_df %>% filter(time_window == 3), 
            by = c("firmname" = "firmname", "tied_year" = "year")) %>%
  left_join(exit_data %>% select(comname, exit, situ_yr), 
            by = "comname")

cat("Final dataset summary:\n")
cat("Dimensions:", dim(final_dataset), "\n")
cat("Non-zero centrality values:", sum(final_dataset$dgr_cent > 0, na.rm = TRUE), "\n")
cat("Non-zero exit values:", sum(final_dataset$exit > 0, na.rm = TRUE), "\n")

cat("\n=== DEBUGGING COMPLETED ===\n") 