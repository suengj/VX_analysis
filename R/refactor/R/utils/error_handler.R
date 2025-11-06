# Error Handling Utilities for VC Analysis
# Created: 2025-10-11
# Purpose: Provide robust error handling, logging, and retry mechanisms

#' Safe Execute with Retry Logic
#'
#' @param expr Expression to execute
#' @param max_retries Maximum number of retry attempts (default: 3)
#' @param on_error Callback function to execute on final error
#' @param context_msg Additional context message for logging
#' @param log_file Path to log file
#' @return Result of expression or error object
#' @export
safe_execute <- function(expr, 
                        max_retries = 3, 
                        on_error = NULL,
                        context_msg = "",
                        log_file = NULL) {
  
  expr_text <- deparse(substitute(expr))
  
  for(i in 1:max_retries) {
    result <- tryCatch({
      eval(expr, envir = parent.frame())
    }, error = function(e) {
      # Log error
      log_error(
        error = e, 
        context = ifelse(context_msg != "", context_msg, expr_text),
        attempt = i,
        max_attempts = max_retries,
        log_file = log_file
      )
      
      # Retry logic
      if(i < max_retries) {
        cat(sprintf("  ⚠️ Retry %d of %d...\n", i, max_retries - 1))
        Sys.sleep(2)  # Wait before retry
      }
      
      return(list(error = TRUE, message = e$message, call = e$call))
    }, warning = function(w) {
      log_warning(
        warning = w,
        context = ifelse(context_msg != "", context_msg, expr_text),
        log_file = log_file
      )
      suppressWarnings(eval(expr, envir = parent.frame()))
    })
    
    # Check if result is error
    if(is.list(result) && !is.null(result$error) && result$error == TRUE) {
      if(i == max_retries && !is.null(on_error)) {
        on_error(result)
      }
    } else {
      # Success
      if(i > 1) {
        cat(sprintf("  ✅ Success on attempt %d\n", i))
      }
      return(result)
    }
  }
  
  # All retries failed
  cat("  ❌ All retries exhausted\n")
  return(result)
}


#' Log Error with Detailed Information
#'
#' @param error Error object
#' @param context Context description
#' @param attempt Current attempt number
#' @param max_attempts Maximum attempts
#' @param log_file Path to log file
#' @export
log_error <- function(error, 
                      context = "", 
                      attempt = 1,
                      max_attempts = 1,
                      log_file = NULL) {
  
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  
  error_msg <- sprintf(
    "[%s] ERROR (Attempt %d/%d)\n  Context: %s\n  Message: %s\n  Call: %s\n",
    timestamp,
    attempt,
    max_attempts,
    context,
    error$message,
    paste(deparse(error$call), collapse = " ")
  )
  
  # Print to console
  cat("\n", error_msg, "\n", sep = "")
  
  # Write to log file
  if(!is.null(log_file)) {
    write(error_msg, file = log_file, append = TRUE)
  }
  
  invisible(error_msg)
}


#' Log Warning with Details
#'
#' @param warning Warning object
#' @param context Context description
#' @param log_file Path to log file
#' @export
log_warning <- function(warning, 
                        context = "",
                        log_file = NULL) {
  
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  
  warning_msg <- sprintf(
    "[%s] WARNING\n  Context: %s\n  Message: %s\n",
    timestamp,
    context,
    warning$message
  )
  
  # Print to console
  cat("\n", warning_msg, "\n", sep = "")
  
  # Write to log file
  if(!is.null(log_file)) {
    write(warning_msg, file = log_file, append = TRUE)
  }
  
  invisible(warning_msg)
}


#' Send Notification (Console Output)
#'
#' @param message Notification message
#' @param type Type of notification ("info", "success", "warning", "error")
#' @param log_file Path to log file
#' @export
send_notification <- function(message, 
                              type = "info",
                              log_file = NULL) {
  
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  
  # Icon based on type
  icon <- switch(type,
                 "info" = "ℹ️",
                 "success" = "✅",
                 "warning" = "⚠️",
                 "error" = "❌",
                 "📢")
  
  notification_msg <- sprintf("[%s] %s %s\n", timestamp, icon, message)
  
  # Print to console
  cat(notification_msg)
  
  # Write to log file
  if(!is.null(log_file)) {
    write(notification_msg, file = log_file, append = TRUE)
  }
  
  invisible(notification_msg)
}


#' Create Error Log File
#'
#' @param log_dir Directory for log files
#' @param prefix Log file prefix
#' @return Path to log file
#' @export
create_error_log <- function(log_dir = "logs", prefix = "error") {
  
  # Create log directory if it doesn't exist
  if(!dir.exists(log_dir)) {
    dir.create(log_dir, recursive = TRUE)
  }
  
  # Create log file with timestamp
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  log_file <- file.path(log_dir, sprintf("%s_%s.log", prefix, timestamp))
  
  # Write header
  header <- sprintf(
    "=================================================\n%s - Log File Created\n=================================================\n\n",
    format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  )
  
  write(header, file = log_file)
  
  return(log_file)
}


#' Wrap Function with Error Handling
#'
#' @param func Function to wrap
#' @param log_file Path to log file
#' @return Wrapped function
#' @export
wrap_with_error_handling <- function(func, log_file = NULL) {
  
  function(...) {
    func_name <- deparse(substitute(func))
    
    safe_execute(
      func(...),
      context_msg = sprintf("Executing %s", func_name),
      log_file = log_file
    )
  }
}







