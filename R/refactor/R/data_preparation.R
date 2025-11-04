# VC Data Preparation Script
# Converts raw Excel files to .rds format for R analysis
# Based on VC_merge_v0.py structure

library(readxl)
library(dplyr)
library(tidyr)
library(lubridate)
library(purrr)

# =============================================================================
# CONFIGURATION
# =============================================================================

# Base paths
RAW_BASE_PATH <- "/Users/suengj/Documents/Code/Python/Research/VC/raw"
EXTRACT_PATH <- "/Users/suengj/Documents/Code/Python/Research/VC/raw/extract"

# Raw data paths
ROUND_PATH_US <- file.path(RAW_BASE_PATH, "round/US")
STARTUP_PATH <- file.path(RAW_BASE_PATH, "comp")
VC_PATH <- file.path(RAW_BASE_PATH, "firm")

# 실제 읽어온 컬럼명을 저장할 변수들 (초기값은 NULL)
ACTUAL_ROUND_COLUMNS <- NULL
ACTUAL_COMPANY_COLUMNS <- NULL  
ACTUAL_FIRM_COLUMNS <- NULL

# 표준화된 컬럼명 매핑 (실제 컬럼명을 읽은 후 업데이트됨)
ROUND_COLUMN_MAPPING <- NULL
COMPANY_COLUMN_MAPPING <- NULL
FIRM_COLUMN_MAPPING <- NULL





# =============================================================================
# COLUMN EXTRACTION AND MAPPING FUNCTIONS
# =============================================================================

# 엔터를 띄어쓰기로 변환하는 함수
clean_column_name <- function(col_name) {
  if (is.character(col_name)) {
    # 엔터, 탭, 여러 공백을 단일 공백으로 변환
    cleaned <- gsub("[\r\n\t]+", " ", col_name)
    cleaned <- gsub("\\s+", " ", cleaned)
    cleaned <- trimws(cleaned)
    return(cleaned)
  }
  return(col_name)
}

# 실제 컬럼명을 추출하는 함수
extract_actual_columns <- function(file_paths, data_type = "round") {
  cat("🔍", toupper(data_type), "데이터 컬럼명 추출 중...\n")
  
  all_columns <- list()
  
  for (file in file_paths) {
    tryCatch({
      # 첫 몇 행만 읽어서 컬럼명 확인
      df <- read_excel(file, n_max = 3, skip = 0)
      
      # 컬럼명 정리 (엔터 제거)
      cleaned_cols <- sapply(colnames(df), clean_column_name)
      
      all_columns[[basename(file)]] <- cleaned_cols
      
      cat("✓", basename(file), ":", length(cleaned_cols), "개 컬럼\n")
      
    }, error = function(e) {
      cat("❌", basename(file), "에러:", e$message, "\n")
    })
  }
  
  # 모든 파일에서 공통된 컬럼명 찾기
  if (length(all_columns) > 0) {
    common_columns <- Reduce(intersect, all_columns)
    cat("📋 공통 컬럼 수:", length(common_columns), "\n")
    return(list(all_columns = all_columns, common_columns = common_columns))
  }
  
  return(NULL)
}

# 컬럼명 매핑 생성 함수
create_column_mapping <- function(common_columns, data_type = "round") {
  cat("🔧", toupper(data_type), "컬럼 매핑 생성 중...\n")
  
  mapping <- c()
  
  for (col in common_columns) {
    # 컬럼명을 기반으로 표준화된 이름 생성
    standard_name <- generate_standard_name(col, data_type)
    mapping[col] <- standard_name
    cat("  ", col, " → ", standard_name, "\n")
  }
  
  return(mapping)
}

# 표준화된 컬럼명 생성 함수
generate_standard_name <- function(col_name, data_type) {
  col_lower <- tolower(col_name)
  
  # Round 데이터 매핑
  if (data_type == "round") {
    if (grepl("^round date$", col_lower)) return("rnddate")
    if (grepl("^company name$", col_lower)) return("comname")
    if (grepl("^firm name$", col_lower)) return("firmname")
    if (grepl("^fund name$", col_lower)) return("fundname")
    if (grepl("round amount disclosed", col_lower)) return("rndamt_disclosed")
    if (grepl("round amount estimated", col_lower)) return("rndamt_estimated")
    if (grepl("^round number$", col_lower)) return("rndnum")
    if (grepl("round number of investors", col_lower)) return("investors")
    if (grepl("deal number", col_lower)) return("deal_number")
    if (grepl("disclose company valuation", col_lower)) return("valuation")
    if (grepl("disclosed post.round company val", col_lower)) return("valuation_000")
    if (grepl("standard us venture buyout", col_lower)) return("buyout")
    if (grepl("company stage level 1", col_lower)) return("level1")
    if (grepl("company stage level 2", col_lower)) return("level2")
    if (grepl("company stage level 3", col_lower)) return("level3")
  }
  
  # Company 데이터 매핑
  if (data_type == "company") {
    if (grepl("ipo.*date", col_lower)) return("date_ipo")
    if (grepl("founding.*date|founded", col_lower)) return("date_fnd")
    if (grepl("situation.*date", col_lower)) return("date_sit")
    if (grepl("cusip", col_lower)) return("comcusip")
    if (grepl("public.*status", col_lower)) return("compubstat")
    if (grepl("company.*situation", col_lower)) return("comsitu")
    if (grepl("ipo.*status", col_lower)) return("comipo")
    if (grepl("msa.*code", col_lower)) return("commsa")
    if (grepl("company.*name", col_lower)) return("comname")
    if (grepl("nation.*code", col_lower)) return("comnation")
    if (grepl("state.*code", col_lower)) return("comstacode")
    if (grepl("stock.*exchange", col_lower)) return("comstock")
    if (grepl("ticker", col_lower)) return("comticker")
    if (grepl("industry.*class", col_lower)) return("comind")
    if (grepl("industry.*major", col_lower)) return("comindmjr")
    if (grepl("industry.*minor", col_lower)) return("comindmnr")
    if (grepl("industry.*sub.*1", col_lower)) return("comindsub1")
    if (grepl("industry.*sub.*2", col_lower)) return("comindsub2")
    if (grepl("industry.*sub.*3", col_lower)) return("comindsub3")
    if (grepl("zip.*code", col_lower)) return("comzip")
  }
  
  # Firm 데이터 매핑
  if (data_type == "firm") {
    if (grepl("firm.*name", col_lower)) return("firmname")
    if (grepl("founding.*date|founded", col_lower)) return("firmfounding")
    if (grepl("nation.*code", col_lower)) return("firmnation")
    if (grepl("state.*code", col_lower)) return("firmstate")
    if (grepl("zip.*code", col_lower)) return("firmzip")
    if (grepl("firm.*type", col_lower)) return("firmtype")
    if (grepl("investment.*status", col_lower)) return("firminvstat")
    if (grepl("msa.*code", col_lower)) return("firmmsa")
  }
  
  # 매칭되지 않는 경우 원본 이름을 소문자로 변환
  return(tolower(gsub("[^a-zA-Z0-9]", "_", col_name)))
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

#' Clean column names by removing newlines
#' @param col_names Vector of column names
#' @return Cleaned column names
clean_column_names <- function(col_names) {
  gsub("\\n", " ", col_names)
}

#' Get list of files matching pattern
#' @param file_path Directory path
#' @param file_pattern File pattern (glob)
#' @return Vector of file paths
get_file_list <- function(file_path, file_pattern) {
  pattern <- gsub("\\*", ".*", file_pattern)
  pattern <- paste0("^", pattern, "$")
  
  files <- list.files(file_path, full.names = TRUE, pattern = "\\.xlsx$")
  files[grepl(pattern, basename(files))]
}

#' Check actual column names in Excel files
#' @param file_path Directory path
#' @param file_pattern File pattern
#' @param skiprows Number of rows to skip
#' @return List of column names by file
check_actual_columns <- function(file_path, file_pattern, skiprows = 0) {
  files <- get_file_list(file_path, file_pattern)
  
  if (length(files) == 0) {
    cat("❌ 파일을 찾을 수 없습니다.\n")
    return(NULL)
  }
  
  column_info <- list()
  
  for (file in files[1:min(3, length(files))]) {  # Check first 3 files
    tryCatch({
      df <- read_excel(file, 
                      sheet = 1,
                      skip = ifelse(is.null(skiprows), 0, skiprows),
                      col_names = TRUE,
                      n_max = 0)  # Only read headers
      
      colnames(df) <- clean_column_names(colnames(df))
      column_info[[basename(file)]] <- colnames(df)
      
      cat("📋", basename(file), "컬럼명:\n")
      for (i in seq_along(colnames(df))) {
        cat(sprintf("  %2d. %s\n", i, colnames(df)[i]))
      }
      cat("\n")
      
    }, error = function(e) {
      cat("❌", basename(file), "-", e$message, "\n")
    })
  }
  
  return(column_info)
}

#' Read and merge Excel files
#' @param file_path Directory path
#' @param file_pattern File pattern
#' @param skiprows Number of rows to skip
#' @param header Header row number
#' @param column_mapping Column name mapping
#' @param output_filename Output filename
#' @param verbose Verbose output
#' @return Merged data frame
read_merge_save_rds <- function(file_path, 
                               file_pattern = "*.xlsx",
                               skiprows = NULL,
                               header = 0,
                               column_mapping = NULL,
                               output_filename = "merged_data.rds",
                               verbose = TRUE) {
  
  if (verbose) {
    cat("경로:", file_path, "\n")
    cat("파일 패턴:", file_pattern, "\n")
  }
  
  # Get file list
  files <- get_file_list(file_path, file_pattern)
  
  if (verbose) {
    cat("발견된 파일 수:", length(files), "\n")
  }
  
  if (length(files) == 0) {
    cat("❌ 파일을 찾을 수 없습니다.\n")
    return(NULL)
  }
  
  # Read and merge files
  data_list <- list()
  success_count <- 0
  error_count <- 0
  
  for (file in files) {
    tryCatch({
      # Read Excel file
      df <- read_excel(file, 
                      sheet = 1,
                      skip = ifelse(is.null(skiprows), 0, skiprows),
                      col_names = TRUE)
      
      # Clean column names
      colnames(df) <- clean_column_names(colnames(df))
      
      # Apply column mapping if provided
      if (!is.null(column_mapping)) {
        # Check if all mapped columns exist
        missing_cols <- setdiff(names(column_mapping), colnames(df))
        if (length(missing_cols) > 0) {
          cat("⚠️  경고:", basename(file), "에서 누락된 컬럼:", paste(missing_cols, collapse = ", "), "\n")
        }
        
        # Handle duplicate column names (like "if Applic.ny")
        unique_mapping <- column_mapping
        if (any(duplicated(names(unique_mapping)))) {
          # For duplicates, keep only the first occurrence
          unique_mapping <- unique_mapping[!duplicated(names(unique_mapping))]
          cat("⚠️  경고: 중복된 컬럼명 제거됨\n")
        }
        
        # Select and rename existing columns
        existing_cols <- intersect(names(unique_mapping), colnames(df))
        df <- df %>% select(all_of(existing_cols))
        colnames(df) <- unique_mapping[existing_cols]
      }
      
      data_list[[basename(file)]] <- df
      success_count <- success_count + 1
      
      if (verbose) {
        cat("✓ 성공:", basename(file), "(크기:", paste(dim(df), collapse = ", "), ")\n")
      }
      
    }, error = function(e) {
      error_count <- error_count + 1
      cat("❌ 실패:", basename(file), "-", e$message, "\n")
    })
  }
  
  # Combine all data
  if (length(data_list) == 0) {
    cat("❌ 성공적으로 읽은 파일이 없습니다.\n")
    return(NULL)
  }
  
  merged_data <- bind_rows(data_list, .id = "source_file")
  
  if (verbose) {
    cat("\n=== 병합 완료 ===\n")
    cat("성공한 파일:", success_count, "개\n")
    cat("실패한 파일:", error_count, "개\n")
    cat("병합 후 데이터 크기:", paste(dim(merged_data), collapse = ", "), "\n")
  }
  
  # Save as RDS
  output_file <- file.path(EXTRACT_PATH, output_filename)
  saveRDS(merged_data, output_file)
  
  if (verbose) {
    cat("RDS 파일 저장 완료:", output_file, "\n")
  }
  
  return(merged_data)
}

# =============================================================================
# DATA PROCESSING FUNCTIONS
# =============================================================================

#' Process round data with dynamic column mapping
#' @return Processed round data
process_round_data <- function() {
  cat("=== Round Data Processing ===\n")
  cat("경로:", ROUND_PATH_US, "\n")
  
  # 파일 목록 가져오기
  files <- list.files(ROUND_PATH_US, pattern = "*.xlsx", full.names = TRUE)
  cat("발견된 파일 수:", length(files), "\n")
  
  if (length(files) == 0) {
    cat("❌ 처리할 파일이 없습니다.\n")
    return(NULL)
  }
  
  # 1단계: 실제 컬럼명 추출 및 매핑 생성
  cat("\n🔍 1단계: 컬럼명 추출 및 매핑 생성\n")
  column_info <- extract_actual_columns(files, "round")
  
  if (is.null(column_info)) {
    cat("❌ 컬럼명 추출 실패\n")
    return(NULL)
  }
  
  # 전역 변수에 저장
  ACTUAL_ROUND_COLUMNS <<- column_info$all_columns
  ROUND_COLUMN_MAPPING <<- create_column_mapping(column_info$common_columns, "round")
  
  cat("📋 생성된 매핑:\n")
  for (i in 1:length(ROUND_COLUMN_MAPPING)) {
    cat("  ", names(ROUND_COLUMN_MAPPING)[i], " → ", ROUND_COLUMN_MAPPING[i], "\n")
  }
  
  # 2단계: 데이터 읽기 및 처리
  cat("\n📊 2단계: 데이터 읽기 및 처리\n")
  all_data <- list()
  success_count <- 0
  fail_count <- 0
  
  for (file in files) {
    tryCatch({
      # 데이터 읽기
      df <- read_excel(file, skip = 0)
      
      # 컬럼명 정리 (엔터 제거)
      colnames(df) <- sapply(colnames(df), clean_column_name)
      
      # Apply column mapping
      if (!is.null(ROUND_COLUMN_MAPPING)) {
        # Check if all mapped columns exist
        missing_cols <- setdiff(names(ROUND_COLUMN_MAPPING), colnames(df))
        if (length(missing_cols) > 0) {
          cat("⚠️  경고:", basename(file), "에서 누락된 컬럼:", paste(missing_cols, collapse = ", "), "\n")
        }
        
        # Select and rename existing columns
        existing_cols <- intersect(names(ROUND_COLUMN_MAPPING), colnames(df))
        df <- df %>% select(all_of(existing_cols))
        colnames(df) <- ROUND_COLUMN_MAPPING[existing_cols]
      }
      
      # 파일명 추가
      df$source_file <- basename(file)
      
      all_data[[file]] <- df
      success_count <- success_count + 1
      cat("✓ 성공:", basename(file), "(크기:", nrow(df), ",", ncol(df), ")\n")
      
    }, error = function(e) {
      fail_count <- fail_count + 1
      cat("❌ 실패:", basename(file), "-", e$message, "\n")
    })
  }
  
  # 데이터 병합
  cat("\n=== 병합 완료 ===\n")
  cat("성공한 파일:", success_count, "개\n")
  cat("실패한 파일:", fail_count, "개\n")
  
  if (length(all_data) > 0) {
    merged_data <- bind_rows(all_data)
    cat("병합 후 데이터 크기:", nrow(merged_data), ",", ncol(merged_data), "\n")
    
    # RDS 파일로 저장
    output_file <- file.path(EXTRACT_PATH, "round_data_US.rds")
    saveRDS(merged_data, output_file)
    cat("RDS 파일 저장 완료:", output_file, "\n")
    
    cat("\n=== 최종 결과 ===\n")
    cat("데이터 크기:", nrow(merged_data), ",", ncol(merged_data), "\n")
    cat("컬럼 목록:\n")
    for (i in 1:length(colnames(merged_data))) {
      cat(sprintf("%2d. %s\n", i, colnames(merged_data)[i]))
    }
    
    return(merged_data)
  } else {
    cat("❌ 병합할 데이터가 없습니다.\n")
    return(NULL)
  }
}

#' Process company data with dynamic column mapping
#' @return Processed company data
process_company_data <- function() {
  cat("=== Company Data Processing ===\n")
  cat("경로:", STARTUP_PATH, "\n")
  
  # 파일 목록 가져오기
  files <- list.files(STARTUP_PATH, pattern = "*.xlsx", full.names = TRUE)
  cat("발견된 파일 수:", length(files), "\n")
  
  if (length(files) == 0) {
    cat("❌ 처리할 파일이 없습니다.\n")
    return(NULL)
  }
  
  # 1단계: 실제 컬럼명 추출 및 매핑 생성
  cat("\n🔍 1단계: 컬럼명 추출 및 매핑 생성\n")
  column_info <- extract_actual_columns(files, "company")
  
  if (is.null(column_info)) {
    cat("❌ 컬럼명 추출 실패\n")
    return(NULL)
  }
  
  # 전역 변수에 저장
  ACTUAL_COMPANY_COLUMNS <<- column_info$all_columns
  COMPANY_COLUMN_MAPPING <<- create_column_mapping(column_info$common_columns, "company")
  
  cat("📋 생성된 매핑:\n")
  for (i in 1:length(COMPANY_COLUMN_MAPPING)) {
    cat("  ", names(COMPANY_COLUMN_MAPPING)[i], " → ", COMPANY_COLUMN_MAPPING[i], "\n")
  }
  
  # 2단계: 데이터 읽기 및 처리
  cat("\n📊 2단계: 데이터 읽기 및 처리\n")
  all_data <- list()
  success_count <- 0
  fail_count <- 0
  
  for (file in files) {
    tryCatch({
      # 데이터 읽기
      df <- read_excel(file, skip = 0)
      
      # 컬럼명 정리 (엔터 제거)
      colnames(df) <- sapply(colnames(df), clean_column_name)
      
      # Apply column mapping
      if (!is.null(COMPANY_COLUMN_MAPPING)) {
        # Check if all mapped columns exist
        missing_cols <- setdiff(names(COMPANY_COLUMN_MAPPING), colnames(df))
        if (length(missing_cols) > 0) {
          cat("⚠️  경고:", basename(file), "에서 누락된 컬럼:", paste(missing_cols, collapse = ", "), "\n")
        }
        
        # Select and rename existing columns
        existing_cols <- intersect(names(COMPANY_COLUMN_MAPPING), colnames(df))
        df <- df %>% select(all_of(existing_cols))
        colnames(df) <- COMPANY_COLUMN_MAPPING[existing_cols]
      }
      
      # 파일명 추가
      df$source_file <- basename(file)
      
      all_data[[file]] <- df
      success_count <- success_count + 1
      cat("✓ 성공:", basename(file), "(크기:", nrow(df), ",", ncol(df), ")\n")
      
    }, error = function(e) {
      fail_count <- fail_count + 1
      cat("❌ 실패:", basename(file), "-", e$message, "\n")
    })
  }
  
  # 데이터 병합
  cat("\n=== 병합 완료 ===\n")
  cat("성공한 파일:", success_count, "개\n")
  cat("실패한 파일:", fail_count, "개\n")
  
  if (length(all_data) > 0) {
    merged_data <- bind_rows(all_data)
    cat("병합 후 데이터 크기:", nrow(merged_data), ",", ncol(merged_data), "\n")
    
    # RDS 파일로 저장
    output_file <- file.path(EXTRACT_PATH, "company_data.rds")
    saveRDS(merged_data, output_file)
    cat("RDS 파일 저장 완료:", output_file, "\n")
    
    cat("\n=== 최종 결과 ===\n")
    cat("데이터 크기:", nrow(merged_data), ",", ncol(merged_data), "\n")
    cat("컬럼 목록:\n")
    for (i in 1:length(colnames(merged_data))) {
      cat(sprintf("%2d. %s\n", i, colnames(merged_data)[i]))
    }
    
    return(merged_data)
  } else {
    cat("❌ 병합할 데이터가 없습니다.\n")
    return(NULL)
  }
}

#' Process firm data with dynamic column mapping
#' @return Processed firm data
process_firm_data <- function() {
  cat("=== Firm Data Processing ===\n")
  cat("경로:", VC_PATH, "\n")
  
  # 파일 목록 가져오기
  files <- list.files(VC_PATH, pattern = "*.xlsx", full.names = TRUE)
  cat("발견된 파일 수:", length(files), "\n")
  
  if (length(files) == 0) {
    cat("❌ 처리할 파일이 없습니다.\n")
    return(NULL)
  }
  
  # 1단계: 실제 컬럼명 추출 및 매핑 생성
  cat("\n🔍 1단계: 컬럼명 추출 및 매핑 생성\n")
  column_info <- extract_actual_columns(files, "firm")
  
  if (is.null(column_info)) {
    cat("❌ 컬럼명 추출 실패\n")
    return(NULL)
  }
  
  # 전역 변수에 저장
  ACTUAL_FIRM_COLUMNS <<- column_info$all_columns
  FIRM_COLUMN_MAPPING <<- create_column_mapping(column_info$common_columns, "firm")
  
  cat("📋 생성된 매핑:\n")
  for (i in 1:length(FIRM_COLUMN_MAPPING)) {
    cat("  ", names(FIRM_COLUMN_MAPPING)[i], " → ", FIRM_COLUMN_MAPPING[i], "\n")
  }
  
  # 2단계: 데이터 읽기 및 처리
  cat("\n📊 2단계: 데이터 읽기 및 처리\n")
  all_data <- list()
  success_count <- 0
  fail_count <- 0
  
  for (file in files) {
    tryCatch({
      # 데이터 읽기
      df <- read_excel(file, skip = 0)
      
      # 컬럼명 정리 (엔터 제거)
      colnames(df) <- sapply(colnames(df), clean_column_name)
      
      # Apply column mapping
      if (!is.null(FIRM_COLUMN_MAPPING)) {
        # Check if all mapped columns exist
        missing_cols <- setdiff(names(FIRM_COLUMN_MAPPING), colnames(df))
        if (length(missing_cols) > 0) {
          cat("⚠️  경고:", basename(file), "에서 누락된 컬럼:", paste(missing_cols, collapse = ", "), "\n")
        }
        
        # Select and rename existing columns
        existing_cols <- intersect(names(FIRM_COLUMN_MAPPING), colnames(df))
        df <- df %>% select(all_of(existing_cols))
        colnames(df) <- FIRM_COLUMN_MAPPING[existing_cols]
      }
      
      # 파일명 추가
      df$source_file <- basename(file)
      
      all_data[[file]] <- df
      success_count <- success_count + 1
      cat("✓ 성공:", basename(file), "(크기:", nrow(df), ",", ncol(df), ")\n")
      
    }, error = function(e) {
      fail_count <- fail_count + 1
      cat("❌ 실패:", basename(file), "-", e$message, "\n")
    })
  }
  
  # 데이터 병합
  cat("\n=== 병합 완료 ===\n")
  cat("성공한 파일:", success_count, "개\n")
  cat("실패한 파일:", fail_count, "개\n")
  
  if (length(all_data) > 0) {
    merged_data <- bind_rows(all_data)
    cat("병합 후 데이터 크기:", nrow(merged_data), ",", ncol(merged_data), "\n")
    
    # RDS 파일로 저장
    output_file <- file.path(EXTRACT_PATH, "firm_data.rds")
    saveRDS(merged_data, output_file)
    cat("RDS 파일 저장 완료:", output_file, "\n")
    
    cat("\n=== 최종 결과 ===\n")
    cat("데이터 크기:", nrow(merged_data), ",", ncol(merged_data), "\n")
    cat("컬럼 목록:\n")
    for (i in 1:length(colnames(merged_data))) {
      cat(sprintf("%2d. %s\n", i, colnames(merged_data)[i]))
    }
    
    return(merged_data)
  } else {
    cat("❌ 병합할 데이터가 없습니다.\n")
    return(NULL)
  }
}

#' Process all data
#' @return List of processed data frames
process_all_data <- function() {
  cat("=== VC Data Processing Pipeline ===\n")
  
  # Create extract directory if it doesn't exist
  if (!dir.exists(EXTRACT_PATH)) {
    dir.create(EXTRACT_PATH, recursive = TRUE)
    cat("생성된 디렉토리:", EXTRACT_PATH, "\n")
  }
  
  # Process all data types
  round_data <- process_round_data()
  company_data <- process_company_data()
  firm_data <- process_firm_data()
  
  # Summary
  cat("\n=== 처리 완료 ===\n")
  cat("Round data:", ifelse(!is.null(round_data), paste(dim(round_data), collapse = "x"), "실패"), "\n")
  cat("Company data:", ifelse(!is.null(company_data), paste(dim(company_data), collapse = "x"), "실패"), "\n")
  cat("Firm data:", ifelse(!is.null(firm_data), paste(dim(firm_data), collapse = "x"), "실패"), "\n")
  
  return(list(
    round = round_data,
    company = company_data,
    firm = firm_data
  ))
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

#' Check column names in all data types
#' @return Column information for all data types
check_all_columns <- function() {
  cat("=== Checking Actual Column Names ===\n\n")
  
  cat("1. Round Data Columns:\n")
  round_cols <- check_actual_columns(ROUND_PATH_US, "round_*.xlsx", skiprows = 0)
  
  cat("2. Company Data Columns:\n")
  company_cols <- check_actual_columns(STARTUP_PATH, "*.xlsx", skiprows = 1)
  
  cat("3. Firm Data Columns:\n")
  firm_cols <- check_actual_columns(VC_PATH, "VC_firm_US.xlsx", skiprows = 0)
  
  return(list(
    round = round_cols,
    company = company_cols,
    firm = firm_cols
  ))
}

if (interactive()) {
  cat("VC Data Preparation Script\n")
  cat("Use process_all_data() to process all raw data\n")
  cat("Use process_round_data(), process_company_data(), process_firm_data() for individual processing\n")
  cat("Use check_all_columns() to check actual column names\n")
} 