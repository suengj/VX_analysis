# 원본 데이터 구조 확인
library(tidyverse)
setwd("/Users/suengj/Documents/Code/Python/Research/VC/raw/extract")

# 데이터 로딩
comdta <- readRDS('company_data.rds') %>% as_tibble()
firmdta <- readRDS('firm_data.rds') %>% as_tibble()
round <- readRDS("round_data_US.rds")

cat("=== ORIGINAL DATA STRUCTURE ANALYSIS ===\n")

# Company data 구조
cat("\n1. COMPANY DATA STRUCTURE:\n")
cat("Columns:", colnames(comdta), "\n")
cat("Dimensions:", dim(comdta), "\n")
cat("Sample data:\n")
print(head(comdta[, 1:5], 3))

# Exit 관련 컬럼 확인
cat("\nExit-related columns:\n")
exit_cols <- grep("exit|Exit|IPO|ipo|M&A|MnA", colnames(comdta), ignore.case = TRUE, value = TRUE)
print(exit_cols)

# Industry 관련 컬럼 확인
cat("\nIndustry-related columns:\n")
industry_cols <- grep("ind|Ind|industry|Industry", colnames(comdta), ignore.case = TRUE, value = TRUE)
print(industry_cols)

# Firm data 구조
cat("\n2. FIRM DATA STRUCTURE:\n")
cat("Columns:", colnames(firmdta), "\n")
cat("Dimensions:", dim(firmdta), "\n")

# Round data 구조
cat("\n3. ROUND DATA STRUCTURE:\n")
cat("Columns:", colnames(round), "\n")
cat("Dimensions:", dim(round), "\n")

# 특정 컬럼의 값 분포 확인
if ("comsitu" %in% colnames(comdta)) {
  cat("\n4. COMPANY SITUATION DISTRIBUTION:\n")
  situ_summary <- comdta %>%
    group_by(comsitu) %>%
    summarise(count = n(), .groups = "drop") %>%
    arrange(desc(count))
  print(situ_summary)
}

if ("comindmnr" %in% colnames(comdta)) {
  cat("\n5. INDUSTRY DISTRIBUTION:\n")
  industry_summary <- comdta %>%
    filter(!is.na(comindmnr) & comindmnr != "") %>%
    group_by(comindmnr) %>%
    summarise(count = n(), .groups = "drop") %>%
    arrange(desc(count))
  print(head(industry_summary, 10))
}

# 날짜 관련 컬럼 확인
cat("\n6. DATE-RELATED COLUMNS:\n")
date_cols <- grep("date|Date|year|Year", colnames(comdta), ignore.case = TRUE, value = TRUE)
print(date_cols)

# 샘플 데이터에서 실제 값 확인
cat("\n7. SAMPLE DATA VALUES:\n")
sample_companies <- comdta %>% slice(1:3)
print(sample_companies) 