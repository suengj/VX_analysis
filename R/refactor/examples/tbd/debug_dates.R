# 디버깅: RDS 파일의 날짜 컬럼 구조 파악
library(dplyr)
library(lubridate)

cat("=== RDS 파일 날짜 컬럼 디버깅 ===\n\n")

# 1. Company 데이터 확인
cat("1. Company 데이터 날짜 컬럼 확인\n")
cat("================================\n")

comdta <- readRDS('company_data.rds') %>% as_tibble()

cat("데이터 크기:", nrow(comdta), "x", ncol(comdta), "\n")
cat("날짜 관련 컬럼들:\n")

# date_sit 컬럼 확인
cat("\n--- date_sit 컬럼 ---\n")
cat("클래스:", class(comdta$date_sit), "\n")
cat("고유값 개수:", length(unique(comdta$date_sit)), "\n")
cat("NA 개수:", sum(is.na(comdta$date_sit)), "\n")
cat("빈 문자열 개수:", sum(comdta$date_sit == "", na.rm = TRUE), "\n")
cat("'NA' 문자열 개수:", sum(comdta$date_sit == "NA", na.rm = TRUE), "\n")

cat("\n첫 10개 값:\n")
print(head(comdta$date_sit, 10))

# date_ipo 컬럼 확인
cat("\n--- date_ipo 컬럼 ---\n")
cat("클래스:", class(comdta$date_ipo), "\n")
cat("고유값 개수:", length(unique(comdta$date_ipo)), "\n")
cat("NA 개수:", sum(is.na(comdta$date_ipo)), "\n")
cat("빈 문자열 개수:", sum(comdta$date_ipo == "", na.rm = TRUE), "\n")
cat("'NA' 문자열 개수:", sum(comdta$date_ipo == "NA", na.rm = TRUE), "\n")

cat("\n첫 10개 값:\n")
print(head(comdta$date_ipo, 10))

# 2. Firm 데이터 확인
cat("\n\n2. Firm 데이터 날짜 컬럼 확인\n")
cat("==============================\n")

firmdta <- readRDS('firm_data.rds') %>% as_tibble()

cat("데이터 크기:", nrow(firmdta), "x", ncol(firmdta), "\n")

# firmfounding 컬럼 확인
cat("\n--- firmfounding 컬럼 ---\n")
cat("클래스:", class(firmdta$firmfounding), "\n")
cat("고유값 개수:", length(unique(firmdta$firmfounding)), "\n")
cat("NA 개수:", sum(is.na(firmdta$firmfounding)), "\n")
cat("빈 문자열 개수:", sum(firmdta$firmfounding == "", na.rm = TRUE), "\n")
cat("'NA' 문자열 개수:", sum(firmdta$firmfounding == "NA", na.rm = TRUE), "\n")

cat("\n첫 10개 값:\n")
print(head(firmdta$firmfounding, 10))

# 3. Round 데이터 확인
cat("\n\n3. Round 데이터 날짜 컬럼 확인\n")
cat("===============================\n")

round <- readRDS("round_data_US.rds") %>% as_tibble()

cat("데이터 크기:", nrow(round), "x", ncol(round), "\n")

# rnddate 컬럼 확인
cat("\n--- rnddate 컬럼 ---\n")
cat("클래스:", class(round$rnddate), "\n")
cat("고유값 개수:", length(unique(round$rnddate)), "\n")
cat("NA 개수:", sum(is.na(round$rnddate)), "\n")
cat("빈 문자열 개수:", sum(round$rnddate == "", na.rm = TRUE), "\n")
cat("'NA' 문자열 개수:", sum(round$rnddate == "NA", na.rm = TRUE), "\n")

cat("\n첫 10개 값:\n")
print(head(round$rnddate, 10))

# 4. 날짜 변환 테스트
cat("\n\n4. 날짜 변환 테스트\n")
cat("===================\n")

# Company 데이터 테스트
cat("\n--- Company 데이터 날짜 변환 테스트 ---\n")

# date_sit 테스트
test_date_sit <- comdta$date_sit[!is.na(comdta$date_sit) & comdta$date_sit != "" & comdta$date_sit != "NA"][1:5]
cat("date_sit 테스트 값들:\n")
print(test_date_sit)

cat("\nas.Date 변환 시도:\n")
for (i in 1:length(test_date_sit)) {
  tryCatch({
    result <- as.Date(test_date_sit[i], origin="1899-12-30")
    cat("성공:", test_date_sit[i], "→", result, "\n")
  }, error = function(e) {
    cat("실패:", test_date_sit[i], "-", e$message, "\n")
  })
}

# date_ipo 테스트
test_date_ipo <- comdta$date_ipo[!is.na(comdta$date_ipo) & comdta$date_ipo != "" & comdta$date_ipo != "NA"][1:5]
cat("\ndate_ipo 테스트 값들:\n")
print(test_date_ipo)

cat("\nas.Date 변환 시도:\n")
for (i in 1:length(test_date_ipo)) {
  tryCatch({
    result <- as.Date(test_date_ipo[i], origin="1899-12-30")
    cat("성공:", test_date_ipo[i], "→", result, "\n")
  }, error = function(e) {
    cat("실패:", test_date_ipo[i], "-", e$message, "\n")
  })
}

cat("\n=== 디버깅 완료 ===\n") 