# 간단한 날짜 테스트
library(dplyr)

cat("=== 간단한 날짜 테스트 ===\n\n")

# Company 데이터 로드
cat("1. Company 데이터 로드\n")
comdta <- readRDS('company_data.rds') %>% as_tibble()

cat("데이터 크기:", nrow(comdta), "x", ncol(comdta), "\n")

# date_sit 컬럼 확인
cat("\n--- date_sit 컬럼 ---\n")
cat("클래스:", class(comdta$date_sit), "\n")
cat("첫 5개 값:\n")
print(head(comdta$date_sit, 5))

# date_ipo 컬럼 확인
cat("\n--- date_ipo 컬럼 ---\n")
cat("클래스:", class(comdta$date_ipo), "\n")
cat("첫 5개 값:\n")
print(head(comdta$date_ipo, 5))

# 실제 값들 확인
cat("\n--- 실제 값들 ---\n")
cat("date_sit 고유값들:\n")
print(unique(comdta$date_sit)[1:10])

cat("\ndate_ipo 고유값들:\n")
print(unique(comdta$date_ipo)[1:10])

cat("\n=== 테스트 완료 ===\n") 