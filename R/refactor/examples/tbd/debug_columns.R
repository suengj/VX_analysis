# 디버깅: 실제 Excel 파일 컬럼명 확인
# 실제 Excel 파일을 직접 읽어서 정확한 컬럼명을 확인

# 필요한 패키지 설치 및 로드
required_packages <- c("readxl", "dplyr", "tidyr", "lubridate", "purrr")
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

# 경로 설정
RAW_BASE_PATH <- "/Users/suengj/Documents/Code/Python/Research/VC/raw"
ROUND_PATH <- file.path(RAW_BASE_PATH, "round", "US")
COMPANY_PATH <- file.path(RAW_BASE_PATH, "comp")
FIRM_PATH <- file.path(RAW_BASE_PATH, "firm")

# 실제 Excel 파일 컬럼명 확인 함수
check_real_columns <- function(file_path, max_rows = 5) {
  cat("\n=== 파일:", basename(file_path), "===\n")
  
  tryCatch({
    # 첫 몇 행만 읽어서 컬럼명 확인
    df <- read_excel(file_path, n_max = max_rows)
    
    cat("📋 실제 컬럼명:\n")
    for (i in 1:length(colnames(df))) {
      cat(sprintf("%2d. %s\n", i, colnames(df)[i]))
    }
    
    cat("📊 데이터 크기:", nrow(df), "x", ncol(df), "\n")
    
    # 첫 몇 행 데이터도 확인
    cat("📄 첫 3행 데이터:\n")
    print(head(df, 3))
    
    return(colnames(df))
    
  }, error = function(e) {
    cat("❌ 에러:", e$message, "\n")
    return(NULL)
  })
}

# Round 데이터 파일들 확인
cat("🔍 ROUND 데이터 파일 컬럼명 확인\n")
round_files <- list.files(ROUND_PATH, pattern = "\\.xlsx$", full.names = TRUE)
round_files <- round_files[1:3]  # 처음 3개 파일만 확인

for (file in round_files) {
  check_real_columns(file)
}

# Company 데이터 파일들 확인  
cat("\n🔍 COMPANY 데이터 파일 컬럼명 확인\n")
company_files <- list.files(COMPANY_PATH, pattern = "\\.xlsx$", full.names = TRUE)
company_files <- company_files[1:2]  # 처음 2개 파일만 확인

for (file in company_files) {
  check_real_columns(file)
}

# Firm 데이터 파일 확인
cat("\n🔍 FIRM 데이터 파일 컬럼명 확인\n")
firm_files <- list.files(FIRM_PATH, pattern = "\\.xlsx$", full.names = TRUE)
firm_files <- firm_files[1:1]  # 첫 번째 파일만 확인

for (file in firm_files) {
  check_real_columns(file)
}

cat("\n✅ 디버깅 완료! 실제 컬럼명을 확인했습니다.\n") 