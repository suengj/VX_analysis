# 디버깅: VC_initial_ties 함수 반환값 확인
library(dplyr)
library(igraph)

cat("=== VC_initial_ties 함수 디버깅 ===\n\n")

# 데이터 로드
cat("1. 데이터 로드\n")
round <- readRDS("round_data_US.rds") %>% as_tibble()
round <- round %>%
  filter(firmname != "Undisclosed Firm", comname != "Undisclosed Company") %>%
  mutate(year = year(rnddate), month = month(rnddate), day = day(rnddate)) %>%
  filter(year > 1979)

cat("Round 데이터 크기:", nrow(round), "x", ncol(round), "\n")
cat("연도 범위:", min(round$year), "-", max(round$year), "\n")

# VC_initial_ties 함수 테스트
cat("\n2. VC_initial_ties 함수 테스트\n")
cat("================================\n")

# 첫 번째 연도로 테스트
test_year <- min(round$year)
cat("테스트 연도:", test_year, "\n")

tryCatch({
  ties <- VC_initial_ties(round, test_year, 3)
  
  cat("반환된 데이터 크기:", nrow(ties), "x", ncol(ties), "\n")
  cat("컬럼명:", colnames(ties), "\n")
  
  if (nrow(ties) > 0) {
    cat("첫 5개 행:\n")
    print(head(ties, 5))
  } else {
    cat("빈 데이터프레임 반환됨\n")
  }
  
}, error = function(e) {
  cat("에러 발생:", e$message, "\n")
})

# 여러 연도로 테스트
cat("\n3. 여러 연도 테스트\n")
cat("===================\n")

test_years <- unique(round$year)[1:5]  # 처음 5개 연도
initial_ties_list <- list()

for (year in test_years) {
  cat("연도:", year, "\n")
  
  tryCatch({
    ties <- VC_initial_ties(round, year, 3)
    
    if (nrow(ties) > 0) {
      cat("  - 데이터 크기:", nrow(ties), "x", ncol(ties), "\n")
      cat("  - 컬럼명:", colnames(ties), "\n")
      initial_ties_list[[as.character(year)]] <- ties
    } else {
      cat("  - 빈 데이터\n")
    }
    
  }, error = function(e) {
    cat("  - 에러:", e$message, "\n")
  })
}

# 결합 테스트
cat("\n4. 결합 테스트\n")
cat("==============\n")

if (length(initial_ties_list) > 0) {
  initial_ties <- do.call("rbind", initial_ties_list)
  initial_ties <- initial_ties %>% as_tibble()
  
  cat("결합 후 데이터 크기:", nrow(initial_ties), "x", ncol(initial_ties), "\n")
  cat("컬럼명:", colnames(initial_ties), "\n")
  
  if (nrow(initial_ties) > 0) {
    cat("첫 5개 행:\n")
    print(head(initial_ties, 5))
  }
} else {
  cat("결합할 데이터가 없음\n")
}

cat("\n=== 디버깅 완료 ===\n") 