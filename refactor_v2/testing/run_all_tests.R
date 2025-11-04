# Master Test Script for VC Analysis
# Created: 2025-10-11
# Purpose: Run CVC and Imprinting tests sequentially with monitoring and error handling

# ================================
# SETUP
# ================================

rm(list = ls())
gc()

cat("\n")
cat("="repeat=70), "\n", sep = "")
cat("MASTER TEST SCRIPT - VC ANALYSIS\n")
cat("CVC Flow → Imprinting Flow\n")
cat("=", rep("=", 70), "\n\n", sep = "")

# Record start time
master_start_time <- Sys.time()

# Setup directories
testing_dir <- "/Users/suengj/Documents/Code/Python/Research/VC/testing_results"
cvc_dir <- file.path(testing_dir, "cvc_flow")
imprinting_dir <- file.path(testing_dir, "imprinting_flow")
reports_dir <- file.path(testing_dir, "reports")

# Create reports directory
if (!dir.exists(reports_dir)) {
  dir.create(reports_dir, recursive = TRUE)
}

# Initialize test results
test_results <- list(
  cvc = list(status = "pending", start_time = NULL, end_time = NULL, duration = NULL, error = NULL),
  imprinting = list(status = "pending", start_time = NULL, end_time = NULL, duration = NULL, error = NULL)
)

# ================================
# UTILITY FUNCTIONS
# ================================

#' Run Test Script
#'
#' @param script_path Path to R script
#' @param test_name Name of the test
#' @return List with status, duration, and error (if any)
run_test_script <- function(script_path, test_name) {
  
  cat("\n")
  cat("=", rep("=", 70), "\n", sep = "")
  cat("RUNNING:", test_name, "\n")
  cat("=", rep("=", 70), "\n\n", sep = "")
  
  start_time <- Sys.time()
  
  result <- tryCatch({
    # Run script in separate R session
    cmd <- sprintf("Rscript %s", script_path)
    exit_code <- system(cmd, intern = FALSE)
    
    if (exit_code == 0) {
      list(status = "success", error = NULL)
    } else {
      list(status = "failed", error = sprintf("Exit code: %d", exit_code))
    }
  }, error = function(e) {
    list(status = "error", error = e$message)
  })
  
  end_time <- Sys.time()
  duration <- difftime(end_time, start_time, units = "mins")
  
  result$start_time <- start_time
  result$end_time <- end_time
  result$duration <- as.numeric(duration)
  
  # Print result
  if (result$status == "success") {
    cat("\n✅", test_name, "COMPLETED\n")
    cat(sprintf("   Duration: %.2f minutes\n\n", result$duration))
  } else {
    cat("\n❌", test_name, "FAILED\n")
    cat(sprintf("   Error: %s\n", result$error))
    cat(sprintf("   Duration: %.2f minutes\n\n", result$duration))
  }
  
  return(result)
}


#' Validate Test Results
#'
#' @param test_dir Test directory
#' @return List with validation results
validate_test_results <- function(test_dir) {
  
  data_dir <- file.path(test_dir, "data")
  results_dir <- file.path(test_dir, "results")
  
  # Check data files
  data_files <- list.files(data_dir, pattern = "\\.csv$")
  
  # Check results files
  results_files <- list.files(results_dir, pattern = "\\.csv$")
  
  # Calculate total size
  all_files <- c(
    list.files(data_dir, pattern = "\\.csv$", full.names = TRUE),
    list.files(results_dir, pattern = "\\.csv$", full.names = TRUE)
  )
  
  total_size_mb <- sum(file.size(all_files)) / 1024^2
  
  validation <- list(
    n_data_files = length(data_files),
    n_results_files = length(results_files),
    total_size_mb = total_size_mb,
    data_files = data_files,
    results_files = results_files
  )
  
  return(validation)
}


# ================================
# TEST 1: CVC FLOW
# ================================

cat("📋 Test 1/2: CVC Flow\n")
cat("   Script: test_cvc_full_flow.R\n")
cat("   Expected duration: ~30-60 minutes\n\n")

cvc_script <- file.path(cvc_dir, "test_cvc_full_flow.R")

if (!file.exists(cvc_script)) {
  cat("❌ CVC script not found:", cvc_script, "\n")
  test_results$cvc$status <- "error"
  test_results$cvc$error <- "Script file not found"
} else {
  test_results$cvc <- run_test_script(cvc_script, "CVC FLOW")
}

# Validate CVC results
if (test_results$cvc$status == "success") {
  cat("Validating CVC results...\n")
  cvc_validation <- validate_test_results(cvc_dir)
  
  cat(sprintf("  ✅ Data files: %d\n", cvc_validation$n_data_files))
  cat(sprintf("  ✅ Results files: %d\n", cvc_validation$n_results_files))
  cat(sprintf("  ✅ Total size: %.2f MB\n\n", cvc_validation$total_size_mb))
  
  test_results$cvc$validation <- cvc_validation
} else {
  cat("⚠️ Skipping CVC validation due to test failure\n\n")
}

# ================================
# TEST 2: IMPRINTING FLOW
# ================================

# Only run Imprinting if CVC succeeded
if (test_results$cvc$status == "success") {
  
  cat("\n")
  cat("📋 Test 2/2: Imprinting Flow\n")
  cat("   Script: test_imprinting_full_flow.R\n")
  cat("   Expected duration: ~45-90 minutes\n\n")
  
  imprinting_script <- file.path(imprinting_dir, "test_imprinting_full_flow.R")
  
  if (!file.exists(imprinting_script)) {
    cat("❌ Imprinting script not found:", imprinting_script, "\n")
    test_results$imprinting$status <- "error"
    test_results$imprinting$error <- "Script file not found"
  } else {
    test_results$imprinting <- run_test_script(imprinting_script, "IMPRINTING FLOW")
  }
  
  # Validate Imprinting results
  if (test_results$imprinting$status == "success") {
    cat("Validating Imprinting results...\n")
    imprinting_validation <- validate_test_results(imprinting_dir)
    
    cat(sprintf("  ✅ Data files: %d\n", imprinting_validation$n_data_files))
    cat(sprintf("  ✅ Results files: %d\n", imprinting_validation$n_results_files))
    cat(sprintf("  ✅ Total size: %.2f MB\n\n", imprinting_validation$total_size_mb))
    
    test_results$imprinting$validation <- imprinting_validation
  } else {
    cat("⚠️ Skipping Imprinting validation due to test failure\n\n")
  }
  
} else {
  cat("\n⚠️ SKIPPING IMPRINTING FLOW\n")
  cat("   Reason: CVC flow did not complete successfully\n\n")
  test_results$imprinting$status <- "skipped"
  test_results$imprinting$error <- "CVC test failed"
}

# ================================
# FINAL REPORT
# ================================

master_end_time <- Sys.time()
total_duration <- difftime(master_end_time, master_start_time, units = "hours")

cat("\n")
cat("=", rep("=", 70), "\n", sep = "")
cat("FINAL TEST REPORT\n")
cat("=", rep("=", 70), "\n\n", sep = "")

cat("⏱️  Total Execution Time:", round(total_duration, 2), "hours\n\n")

cat("📊 Test Results:\n\n")

# CVC results
cat("1. CVC Flow:\n")
cat(sprintf("   Status: %s\n", toupper(test_results$cvc$status)))
if (!is.null(test_results$cvc$duration)) {
  cat(sprintf("   Duration: %.2f minutes\n", test_results$cvc$duration))
}
if (!is.null(test_results$cvc$error)) {
  cat(sprintf("   Error: %s\n", test_results$cvc$error))
}
if (!is.null(test_results$cvc$validation)) {
  cat(sprintf("   Data files: %d\n", test_results$cvc$validation$n_data_files))
  cat(sprintf("   Results files: %d\n", test_results$cvc$validation$n_results_files))
}
cat("\n")

# Imprinting results
cat("2. Imprinting Flow:\n")
cat(sprintf("   Status: %s\n", toupper(test_results$imprinting$status)))
if (!is.null(test_results$imprinting$duration)) {
  cat(sprintf("   Duration: %.2f minutes\n", test_results$imprinting$duration))
}
if (!is.null(test_results$imprinting$error)) {
  cat(sprintf("   Error: %s\n", test_results$imprinting$error))
}
if (!is.null(test_results$imprinting$validation)) {
  cat(sprintf("   Data files: %d\n", test_results$imprinting$validation$n_data_files))
  cat(sprintf("   Results files: %d\n", test_results$imprinting$validation$n_results_files))
}
cat("\n")

# Overall status
all_success <- test_results$cvc$status == "success" && 
               test_results$imprinting$status == "success"

if (all_success) {
  cat("🎉 ALL TESTS PASSED!\n\n")
} else {
  cat("⚠️ SOME TESTS FAILED OR WERE SKIPPED\n\n")
}

# Save report
report_file <- file.path(reports_dir, sprintf("test_report_%s.txt", 
                                              format(Sys.time(), "%Y%m%d_%H%M%S")))

sink(report_file)
cat("VC ANALYSIS - TEST REPORT\n")
cat("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")
cat("Total Duration:", round(total_duration, 2), "hours\n\n")
cat("CVC Flow:\n")
cat("  Status:", test_results$cvc$status, "\n")
if (!is.null(test_results$cvc$duration)) {
  cat("  Duration:", round(test_results$cvc$duration, 2), "minutes\n")
}
cat("\nImprinting Flow:\n")
cat("  Status:", test_results$imprinting$status, "\n")
if (!is.null(test_results$imprinting$duration)) {
  cat("  Duration:", round(test_results$imprinting$duration, 2), "minutes\n")
}
sink()

cat("📄 Report saved:", report_file, "\n\n")

cat("="repeat=70), "\n", sep = "")
cat("TESTING COMPLETE\n")
cat("=", rep("=", 70), "\n\n", sep = "")

