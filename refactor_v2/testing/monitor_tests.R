# Test Monitoring Script
# Created: 2025-10-11
# Purpose: Real-time monitoring of CVC and Imprinting test execution

# ================================
# SETUP
# ================================

# Define directories
testing_dir <- "/Users/suengj/Documents/Code/Python/Research/VC/testing_results"
cvc_dir <- file.path(testing_dir, "cvc_flow")
imprinting_dir <- file.path(testing_dir, "imprinting_flow")

# ================================
# MONITORING FUNCTIONS
# ================================

#' Read Last N Lines from Log File
#'
#' @param log_file Path to log file
#' @param n Number of lines to read
#' @return Character vector of last n lines
read_last_lines <- function(log_file, n = 20) {
  
  if (!file.exists(log_file)) {
    return(NULL)
  }
  
  # Read entire file
  all_lines <- readLines(log_file, warn = FALSE)
  
  if (length(all_lines) == 0) {
    return(NULL)
  }
  
  # Get last n lines
  start_idx <- max(1, length(all_lines) - n + 1)
  last_lines <- all_lines[start_idx:length(all_lines)]
  
  return(last_lines)
}


#' Get Test Status from Log
#'
#' @param log_file Path to log file
#' @return Character status
get_test_status <- function(log_file) {
  
  if (!file.exists(log_file)) {
    return("NOT STARTED")
  }
  
  # Read last 50 lines
  lines <- read_last_lines(log_file, 50)
  
  if (is.null(lines) || length(lines) == 0) {
    return("EMPTY LOG")
  }
  
  # Check for completion
  if (any(grepl("Analysis completed successfully", lines, ignore.case = TRUE))) {
    return("COMPLETED")
  }
  
  # Check for error
  if (any(grepl("Error|error", lines))) {
    return("ERROR")
  }
  
  # Check current step
  step_patterns <- c(
    "STEP 1" = "LOADING DATA",
    "STEP 2" = "PREPROCESSING",
    "STEP 3" = "IDENTIFYING",
    "STEP 4" = "SAMPLING|CENTRALITY",
    "STEP 5" = "CENTRALITY|PARTNER",
    "STEP 6" = "MERGING|CREATING VARIABLES|FINAL DATASET",
    "STEP 7" = "STATISTICAL ANALYSIS"
  )
  
  for (i in seq_along(step_patterns)) {
    pattern <- step_patterns[i]
    if (any(grepl(pattern, lines, ignore.case = TRUE))) {
      return(names(step_patterns)[i])
    }
  }
  
  return("RUNNING")
}


#' Get File Statistics
#'
#' @param directory Directory path
#' @return List with file statistics
get_file_stats <- function(directory) {
  
  if (!dir.exists(directory)) {
    return(list(n_files = 0, total_size_mb = 0, files = character(0)))
  }
  
  files <- list.files(directory, pattern = "\\.csv$", full.names = TRUE)
  
  if (length(files) == 0) {
    return(list(n_files = 0, total_size_mb = 0, files = character(0)))
  }
  
  file_sizes <- file.size(files)
  total_size_mb <- sum(file_sizes) / 1024^2
  
  # Get file info
  file_info <- data.frame(
    file = basename(files),
    size_mb = file_sizes / 1024^2,
    modified = file.mtime(files),
    stringsAsFactors = FALSE
  )
  
  file_info <- file_info[order(file_info$modified, decreasing = TRUE), ]
  
  return(list(
    n_files = length(files),
    total_size_mb = total_size_mb,
    files = file_info
  ))
}


#' Display Monitor Dashboard
#'
#' @param refresh_interval Refresh interval in seconds
#' @param max_iterations Maximum number of iterations (0 = infinite)
display_monitor <- function(refresh_interval = 10, max_iterations = 0) {
  
  iteration <- 0
  
  while (TRUE) {
    
    iteration <- iteration + 1
    
    # Clear screen (works on Unix-like systems)
    cat("\014")  # Form feed character (clears console in RStudio)
    
    # Header
    cat("\n")
    cat("=", rep("=", 70), "\n", sep = "")
    cat("VC ANALYSIS - TEST MONITORING DASHBOARD\n")
    cat("=", rep("=", 70), "\n\n", sep = "")
    
    cat("📅 Current Time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
    cat("🔄 Refresh Interval:", refresh_interval, "seconds\n")
    cat("🔢 Iteration:", iteration, "\n\n")
    
    # Monitor CVC Flow
    cat("─", rep("─", 68), "\n", sep = "")
    cat("1. CVC FLOW\n")
    cat("─", rep("─", 68), "\n\n", sep = "")
    
    cvc_log <- file.path(cvc_dir, "logs", "full_execution.log")
    cvc_status <- get_test_status(cvc_log)
    
    cat("Status:", cvc_status, "\n\n")
    
    # CVC data files
    cvc_data_stats <- get_file_stats(file.path(cvc_dir, "data"))
    cat(sprintf("Data Files: %d (%.2f MB)\n", 
               cvc_data_stats$n_files, 
               cvc_data_stats$total_size_mb))
    
    if (cvc_data_stats$n_files > 0) {
      cat("  Recent files:\n")
      for (i in 1:min(3, nrow(cvc_data_stats$files))) {
        f <- cvc_data_stats$files[i, ]
        cat(sprintf("    - %s (%.2f MB) at %s\n", 
                   f$file, f$size_mb, 
                   format(f$modified, "%H:%M:%S")))
      }
    }
    cat("\n")
    
    # CVC results files
    cvc_results_stats <- get_file_stats(file.path(cvc_dir, "results"))
    cat(sprintf("Results Files: %d (%.2f MB)\n", 
               cvc_results_stats$n_files, 
               cvc_results_stats$total_size_mb))
    
    if (cvc_results_stats$n_files > 0) {
      cat("  Files:\n")
      for (i in 1:nrow(cvc_results_stats$files)) {
        f <- cvc_results_stats$files[i, ]
        cat(sprintf("    - %s (%.2f MB)\n", f$file, f$size_mb))
      }
    }
    cat("\n")
    
    # CVC log excerpt
    if (file.exists(cvc_log)) {
      cat("Recent Log:\n")
      last_lines <- read_last_lines(cvc_log, 5)
      if (!is.null(last_lines)) {
        for (line in last_lines) {
          cat("  ", line, "\n")
        }
      }
    } else {
      cat("⚠️ Log file not found\n")
    }
    cat("\n")
    
    # Monitor Imprinting Flow
    cat("─", rep("─", 68), "\n", sep = "")
    cat("2. IMPRINTING FLOW\n")
    cat("─", rep("─", 68), "\n\n", sep = "")
    
    imprinting_log <- file.path(imprinting_dir, "logs", "full_execution.log")
    imprinting_status <- get_test_status(imprinting_log)
    
    cat("Status:", imprinting_status, "\n\n")
    
    # Imprinting data files
    imprinting_data_stats <- get_file_stats(file.path(imprinting_dir, "data"))
    cat(sprintf("Data Files: %d (%.2f MB)\n", 
               imprinting_data_stats$n_files, 
               imprinting_data_stats$total_size_mb))
    
    if (imprinting_data_stats$n_files > 0) {
      cat("  Recent files:\n")
      for (i in 1:min(3, nrow(imprinting_data_stats$files))) {
        f <- imprinting_data_stats$files[i, ]
        cat(sprintf("    - %s (%.2f MB) at %s\n", 
                   f$file, f$size_mb, 
                   format(f$modified, "%H:%M:%S")))
      }
    }
    cat("\n")
    
    # Imprinting results files
    imprinting_results_stats <- get_file_stats(file.path(imprinting_dir, "results"))
    cat(sprintf("Results Files: %d (%.2f MB)\n", 
               imprinting_results_stats$n_files, 
               imprinting_results_stats$total_size_mb))
    
    if (imprinting_results_stats$n_files > 0) {
      cat("  Files:\n")
      for (i in 1:nrow(imprinting_results_stats$files)) {
        f <- imprinting_results_stats$files[i, ]
        cat(sprintf("    - %s (%.2f MB)\n", f$file, f$size_mb))
      }
    }
    cat("\n")
    
    # Imprinting log excerpt
    if (file.exists(imprinting_log)) {
      cat("Recent Log:\n")
      last_lines <- read_last_lines(imprinting_log, 5)
      if (!is.null(last_lines)) {
        for (line in last_lines) {
          cat("  ", line, "\n")
        }
      }
    } else {
      cat("⚠️ Log file not found or not started yet\n")
    }
    cat("\n")
    
    # Footer
    cat("=", rep("=", 70), "\n", sep = "")
    cat("Press Ctrl+C to stop monitoring\n")
    cat("=", rep("=", 70), "\n\n", sep = "")
    
    # Check if both tests are complete
    if (cvc_status == "COMPLETED" && imprinting_status == "COMPLETED") {
      cat("🎉 ALL TESTS COMPLETED!\n\n")
      break
    }
    
    # Check max iterations
    if (max_iterations > 0 && iteration >= max_iterations) {
      cat("⚠️ Maximum iterations reached\n\n")
      break
    }
    
    # Wait before next refresh
    Sys.sleep(refresh_interval)
  }
}


# ================================
# MAIN
# ================================

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)

refresh_interval <- 10  # Default: 10 seconds
max_iterations <- 0     # Default: infinite

if (length(args) > 0) {
  refresh_interval <- as.numeric(args[1])
}

if (length(args) > 1) {
  max_iterations <- as.numeric(args[2])
}

# Run monitor
cat("Starting test monitor...\n")
cat("Refresh interval:", refresh_interval, "seconds\n")

if (max_iterations > 0) {
  cat("Max iterations:", max_iterations, "\n")
}

cat("\n")

display_monitor(refresh_interval, max_iterations)

