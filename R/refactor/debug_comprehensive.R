# Comprehensive Debugging Script
# 모든 문제점을 체계적으로 진단

source("load_all_modules.R")
modules <- quick_setup()

cat("=== COMPREHENSIVE DEBUGGING START ===\n")

# 1. 데이터 로딩 및 기본 상태 확인
setwd("/Users/suengj/Documents/Code/Python/Research/VC/raw/extract")
comdta <- readRDS('company_data.rds') %>% as_tibble()
firmdta <- readRDS('firm_data.rds') %>% as_tibble()
round <- readRDS("round_data_US.rds")

cat("✓ Data loaded successfully\n")
cat("Company data dimensions:", dim(comdta), "\n")
cat("Firm data dimensions:", dim(firmdta), "\n")
cat("Round data dimensions:", dim(round), "\n")

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
cat("Filtered round data dimensions:", dim(round), "\n")

# 3. 네트워크 중심성 계산 테스트
cat("\n=== NETWORK CENTRALITY TEST ===\n")

# 특정 VC의 연도별 중심성 추적
test_vc <- "Sequoia Capital"
test_years <- 1990:1995

cat("Testing network centrality for:", test_vc, "\n")

for (year in test_years) {
  cat("\nYear:", year, "\n")
  
  # 1년 윈도우
  tryCatch({
    cent_1y <- VC_centralities(round, year, 1, 1)
    if (test_vc %in% cent_1y$rn) {
      vc_data <- cent_1y[cent_1y$rn == test_vc, ]
      cat("  1y - Degree:", vc_data$dgr_cent, "Power:", vc_data$pwr_max, "\n")
    } else {
      cat("  1y - No data for", test_vc, "\n")
    }
  }, error = function(e) {
    cat("  1y - Error:", e$message, "\n")
  })
  
  # 3년 윈도우
  tryCatch({
    cent_3y <- VC_centralities(round, year, 3, 1)
    if (test_vc %in% cent_3y$rn) {
      vc_data <- cent_3y[cent_3y$rn == test_vc, ]
      cat("  3y - Degree:", vc_data$dgr_cent, "Power:", vc_data$pwr_max, "\n")
    } else {
      cat("  3y - No data for", test_vc, "\n")
    }
  }, error = function(e) {
    cat("  3y - Error:", e$message, "\n")
  })
  
  # 5년 윈도우
  tryCatch({
    cent_5y <- VC_centralities(round, year, 5, 1)
    if (test_vc %in% cent_5y$rn) {
      vc_data <- cent_5y[cent_5y$rn == test_vc, ]
      cat("  5y - Degree:", vc_data$dgr_cent, "Power:", vc_data$pwr_max, "\n")
    } else {
      cat("  5y - No data for", test_vc, "\n")
    }
  }, error = function(e) {
    cat("  5y - Error:", e$message, "\n")
  })
}

# 4. 네트워크 매트릭스 생성 로직 검증
cat("\n=== NETWORK MATRIX LOGIC VERIFICATION ===\n")

test_year <- 1995
cat("Testing network matrix for year:", test_year, "\n")

# 3년 윈도우: 1993-1995
cat("3-year window (1993-1995):\n")
tryCatch({
  network_3y <- VC_matrix(round, test_year, 3, 1)
  cat("  Network size:", vcount(network_3y), "nodes,", ecount(network_3y), "edges\n")
  
  # 실제 데이터 확인
  edge_data_3y <- round[round$year >= test_year-3 & round$year <= test_year-1, ]
  cat("  Raw edge data period:", min(edge_data_3y$year), "-", max(edge_data_3y$year), "\n")
  cat("  Raw edge count:", nrow(edge_data_3y), "\n")
}, error = function(e) {
  cat("  3y - Error:", e$message, "\n")
})

# 5년 윈도우: 1991-1995
cat("5-year window (1991-1995):\n")
tryCatch({
  network_5y <- VC_matrix(round, test_year, 5, 1)
  cat("  Network size:", vcount(network_5y), "nodes,", ecount(network_5y), "edges\n")
  
  # 실제 데이터 확인
  edge_data_5y <- round[round$year >= test_year-5 & round$year <= test_year-1, ]
  cat("  Raw edge data period:", min(edge_data_5y$year), "-", max(edge_data_5y$year), "\n")
  cat("  Raw edge count:", nrow(edge_data_5y), "\n")
}, error = function(e) {
  cat("  5y - Error:", e$message, "\n")
})

# 5. Performance data 검증
cat("\n=== PERFORMANCE DATA VERIFICATION ===\n")

# 원본 데이터에서 exit 정보 확인
cat("Original company data exit information:\n")
exit_summary <- comdta %>%
  filter(!is.na(exit)) %>%
  group_by(exit) %>%
  summarise(count = n(), .groups = "drop")
print(exit_summary)

# 특정 연도의 exit 데이터 확인
test_exit_year <- 1995
cat("\nExit data for year:", test_exit_year, "\n")

exit_data <- comdta %>%
  filter(exit == 1) %>%
  mutate(situ_yr = as.integer(substr(comsitu, nchar(comsitu) - 3, nchar(comsitu)))) %>%
  filter(situ_yr == test_exit_year)

cat("Companies with exit in", test_exit_year, ":", nrow(exit_data), "\n")
if (nrow(exit_data) > 0) {
  print(head(exit_data[, c("comname", "comsitu", "situ_yr")], 5))
}

# 6. Industry data 검증
cat("\n=== INDUSTRY DATA VERIFICATION ===\n")

# 원본 데이터의 industry 정보 확인
cat("Industry distribution in company data:\n")
industry_summary <- comdta %>%
  filter(!is.na(comindmnr) & comindmnr != "") %>%
  group_by(comindmnr) %>%
  summarise(count = n(), .groups = "drop") %>%
  arrange(desc(count))
print(industry_summary)

# 7. Merge 과정 디버깅
cat("\n=== MERGE PROCESS DEBUGGING ===\n")

# 중심성 데이터 생성
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
cat("Columns:", colnames(centrality_df), "\n")
cat("Time windows:", unique(centrality_df$time_window), "\n")

# 특정 VC의 데이터 추적
if (test_vc %in% centrality_df$rn) {
  vc_track <- centrality_df[centrality_df$rn == test_vc, ]
  cat("\nTracking data for", test_vc, ":\n")
  print(head(vc_track[, c("year", "time_window", "dgr_cent", "pwr_max")], 10))
}

cat("\n=== DEBUGGING COMPLETED ===\n") 