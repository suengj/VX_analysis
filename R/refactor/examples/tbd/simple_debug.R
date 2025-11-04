# 간단한 디버깅: 실제 Excel 파일 컬럼명 확인
library(readxl)

# 경로 설정
RAW_BASE_PATH <- "/Users/suengj/Documents/Code/Python/Research/VC/raw"
ROUND_PATH <- file.path(RAW_BASE_PATH, "round", "US")
COMPANY_PATH <- file.path(RAW_BASE_PATH, "comp")

# 첫 번째 round 파일 확인
round_files <- list.files(ROUND_PATH, pattern = "\\.xlsx$", full.names = TRUE)
if (length(round_files) > 0) {
  cat("🔍 첫 번째 Round 파일:", basename(round_files[1]), "\n")
  
  tryCatch({
    df <- read_excel(round_files[1], n_max = 3)
    cat("📋 실제 컬럼명:\n")
    for (i in 1:length(colnames(df))) {
      cat(sprintf("%2d. %s\n", i, colnames(df)[i]))
    }
  }, error = function(e) {
    cat("❌ 에러:", e$message, "\n")
  })
}

# 첫 번째 company 파일 확인
company_files <- list.files(COMPANY_PATH, pattern = "\\.xlsx$", full.names = TRUE)
if (length(company_files) > 0) {
  cat("\n🔍 첫 번째 Company 파일:", basename(company_files[1]), "\n")
  
  tryCatch({
    df <- read_excel(company_files[1], n_max = 3)
    cat("📋 실제 컬럼명:\n")
    for (i in 1:length(colnames(df))) {
      cat(sprintf("%2d. %s\n", i, colnames(df)[i]))
    }
  }, error = function(e) {
    cat("❌ 에러:", e$message, "\n")
  })
} 