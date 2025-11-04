# Validation Functions
# Basic validation utilities for the refactored VC network analysis

#' Validate network parameters
#' @param edge_data Edge data
#' @param year Target year
#' @param time_window Time window
#' @return Validation result
validate_network_params <- function(edge_data, year, time_window) {
  
  if (is.null(edge_data) || nrow(edge_data) == 0) {
    stop("Edge data is empty or NULL")
  }
  
  if (!"year" %in% colnames(edge_data)) {
    stop("Edge data must contain 'year' column")
  }
  
  if (!"firmname" %in% colnames(edge_data)) {
    stop("Edge data must contain 'firmname' column")
  }
  
  if (!"event" %in% colnames(edge_data)) {
    stop("Edge data must contain 'event' column")
  }
  
  if (year < min(edge_data$year, na.rm = TRUE) || year > max(edge_data$year, na.rm = TRUE)) {
    warning("Year is outside the range of available data")
  }
  
  if (time_window <= 0) {
    stop("Time window must be positive")
  }
  
  return(TRUE)
}

#' Validate centrality calculation parameters
#' @param network Network object
#' @param beta_values Beta values for power centrality
#' @return Validation result
validate_centrality_params <- function(network, beta_values) {
  
  if (!inherits(network, "igraph")) {
    stop("Network must be an igraph object")
  }
  
  if (vcount(network) == 0) {
    stop("Network has no vertices")
  }
  
  if (!is.numeric(beta_values)) {
    stop("Beta values must be numeric")
  }
  
  return(TRUE)
}

#' Check data completeness
#' @param data Input data
#' @param required_columns Required column names
#' @return Completeness check result
check_data_completeness <- function(data, required_columns) {
  
  missing_columns <- setdiff(required_columns, colnames(data))
  
  if (length(missing_columns) > 0) {
    stop(paste("Missing required columns:", paste(missing_columns, collapse = ", ")))
  }
  
  return(TRUE)
}

#' Validate sampling parameters
#' @param data Input data
#' @param ratio Sampling ratio
#' @param time_period Time period
#' @return Validation result
validate_sampling_params <- function(data, ratio, time_period) {
  
  if (is.null(data) || nrow(data) == 0) {
    stop("Data is empty or NULL")
  }
  
  if (ratio <= 0) {
    stop("Sampling ratio must be positive")
  }
  
  if (!is.character(time_period) || length(time_period) != 1) {
    stop("Time period must be a single character string")
  }
  
  return(TRUE)
} 

# Performance Monitoring and Optimization Utilities
# Added for speed optimization and progress tracking

#' Time execution of a function
#' @param expr Expression to time
#' @param message Optional message to display
#' @return Execution time in seconds
time_execution <- function(expr, message = NULL) {
  if (!is.null(message)) {
    cat(message, "... ")
  }
  
  start_time <- Sys.time()
  result <- eval(expr)
  end_time <- Sys.time()
  
  execution_time <- as.numeric(difftime(end_time, start_time, units = "secs"))
  
  if (!is.null(message)) {
    cat("✓ Completed in", round(execution_time, 2), "seconds\n")
  }
  
  return(list(result = result, time = execution_time))
}

#' Create progress bar for year-based operations
#' @param years Vector of years
#' @param description Description for progress bar
#' @return Progress bar object
create_year_progress <- function(years, description = "Processing years") {
  pb <- progress_bar$new(
    format = paste0(description, " [:bar] :percent (:current/:total) ETA: :eta"),
    total = length(years),
    clear = FALSE,
    width = 80
  )
  return(pb)
}

#' Vectorized centrality calculation for multiple years
#' @param round_data Investment round data
#' @param years Vector of years to process
#' @param time_window Time window for network construction
#' @param edge_cutpoint Minimum edge weight threshold
#' @param use_parallel Whether to use parallel processing
#' @return Combined centrality data
vectorized_centrality_calculation <- function(round_data, years, time_window = 5, 
                                            edge_cutpoint = 1, use_parallel = TRUE) {
  
  cat("Starting vectorized centrality calculation for", length(years), "years\n")
  
  if (use_parallel) {
    # Load required packages for parallel processing
    if (!require("parallel", quietly = TRUE)) install.packages("parallel")
    if (!require("foreach", quietly = TRUE)) install.packages("foreach")
    if (!require("doParallel", quietly = TRUE)) install.packages("doParallel")
    
    library("parallel")
    library("foreach")
    library("doParallel")
    
    # Setup parallel processing with CPU usage limit from PARALLEL_PARAMS
    if (exists("PARALLEL_PARAMS")) {
      capacity <- PARALLEL_PARAMS$capacity
    } else {
      capacity <- 0.8  # Default to 80% if PARALLEL_PARAMS not available
    }
    
    total_cores <- parallel::detectCores()
    num_cores <- min(floor(total_cores * capacity), length(years))
    cat("Using", num_cores, "cores out of", total_cores, "available cores (", round(capacity * 100), "% limit)\n")
    cl <- makeCluster(num_cores)
    registerDoParallel(cl)
    
    cat("Using", num_cores, "cores for parallel processing\n")
    
    # Export required functions to cluster
    clusterExport(cl, c("VC_centralities", "VC_matrix"), envir = environment())
    
    # Create progress bar
    pb <- create_year_progress(years, "Calculating centrality")
    
    # Parallel processing with progress tracking
    centrality_list <- foreach(y = years, .packages = c("igraph", "data.table")) %dopar% {
      tryCatch({
        result <- VC_centralities(round_data, y, time_window, edge_cutpoint)
        if (nrow(result) > 0) {
          result$year <- y
          return(result)
        } else {
          return(NULL)
        }
      }, error = function(e) {
        return(NULL)
      })
    }
    
    stopCluster(cl)
    
  } else {
    # Sequential processing with progress bar
    pb <- create_year_progress(years, "Calculating centrality")
    centrality_list <- list()
    
    for (i in seq_along(years)) {
      y <- years[i]
      pb$tick()
      
      tryCatch({
        result <- VC_centralities(round_data, y, time_window, edge_cutpoint)
        if (nrow(result) > 0) {
          result$year <- y
          centrality_list[[i]] <- result
        }
      }, error = function(e) {
        # Skip years with insufficient data
      })
    }
  }
  
  # Combine results
  valid_results <- Filter(Negate(is.null), centrality_list)
  
  if (length(valid_results) > 0) {
    combined_result <- do.call("rbind", valid_results)
    cat("✓ Centrality calculation completed for", length(valid_results), "years\n")
    return(combined_result)
  } else {
    cat("Warning: No centrality data generated\n")
    return(data.frame())
  }
}

#' Optimized network construction with caching
#' @param round_data Investment round data
#' @param year Target year
#' @param time_window Time window
#' @param edge_cutpoint Minimum edge weight threshold
#' @param cache_dir Directory for caching networks
#' @return Network object
optimized_network_construction <- function(round_data, year, time_window = 5, 
                                         edge_cutpoint = 1, cache_dir = NULL) {
  
  # Create cache filename
  if (!is.null(cache_dir)) {
    cache_file <- file.path(cache_dir, paste0("network_", year, "_", time_window, ".rds"))
    
    # Check if cached network exists
    if (file.exists(cache_file)) {
      cat("Loading cached network for year", year, "\n")
      return(readRDS(cache_file))
    }
  }
  
  # Construct network
  network <- VC_matrix(round_data, year, time_window, edge_cutpoint)
  
  # Cache network if cache directory provided
  if (!is.null(cache_dir)) {
    if (!dir.exists(cache_dir)) {
      dir.create(cache_dir, recursive = TRUE)
    }
    saveRDS(network, cache_file)
  }
  
  return(network)
}

#' Memory-efficient data processing
#' @param data Input data
#' @param chunk_size Size of chunks to process
#' @param process_function Function to apply to each chunk
#' @param use_parallel Whether to use parallel processing
#' @return Processed data
chunked_processing <- function(data, chunk_size = 1000, process_function, use_parallel = FALSE) {
  
  total_rows <- nrow(data)
  num_chunks <- ceiling(total_rows / chunk_size)
  
  cat("Processing", total_rows, "rows in", num_chunks, "chunks\n")
  
  if (use_parallel) {
    # Load required packages for parallel processing
    if (!require("parallel", quietly = TRUE)) install.packages("parallel")
    if (!require("foreach", quietly = TRUE)) install.packages("foreach")
    if (!require("doParallel", quietly = TRUE)) install.packages("doParallel")
    
    library("parallel")
    library("foreach")
    library("doParallel")
    
    # Setup parallel processing with CPU usage limit
    if (exists("PARALLEL_PARAMS")) {
      capacity <- PARALLEL_PARAMS$capacity
    } else {
      capacity <- 0.8  # Default to 80%
    }
    
    total_cores <- parallel::detectCores()
    num_cores <- min(floor(total_cores * capacity), num_chunks)
    cat("Using", num_cores, "cores for parallel chunk processing (", round(capacity * 100), "% limit)\n")
    
    cl <- makeCluster(num_cores)
    registerDoParallel(cl)
    
    # Parallel processing
    results <- foreach(i = 1:num_chunks, .packages = c("dplyr", "data.table")) %dopar% {
      start_idx <- (i - 1) * chunk_size + 1
      end_idx <- min(i * chunk_size, total_rows)
      
      chunk <- data[start_idx:end_idx, ]
      process_function(chunk)
    }
    
    stopCluster(cl)
    
  } else {
    # Sequential processing with progress bar
    pb <- progress_bar$new(
      format = "Processing chunks [:bar] :percent (:current/:total) ETA: :eta",
      total = num_chunks,
      clear = FALSE,
      width = 80
    )
    
    results <- list()
    
    for (i in 1:num_chunks) {
      pb$tick()
      
      start_idx <- (i - 1) * chunk_size + 1
      end_idx <- min(i * chunk_size, total_rows)
      
      chunk <- data[start_idx:end_idx, ]
      results[[i]] <- process_function(chunk)
      
      # Force garbage collection to free memory
      if (i %% 10 == 0) {
        gc()
      }
    }
  }
  
  # Combine results
  combined_result <- do.call("rbind", results)
  cat("✓ Chunked processing completed\n")
  
  return(combined_result)
}

#' Benchmark function performance
#' @param func Function to benchmark
#' @param args List of arguments for the function
#' @param iterations Number of iterations for benchmarking
#' @return Benchmark results
benchmark_function <- function(func, args, iterations = 5) {
  
  cat("Benchmarking function:", deparse(substitute(func)), "\n")
  
  times <- numeric(iterations)
  results <- list()
  
  for (i in 1:iterations) {
    start_time <- Sys.time()
    results[[i]] <- do.call(func, args)
    end_time <- Sys.time()
    times[i] <- as.numeric(difftime(end_time, start_time, units = "secs"))
  }
  
  benchmark_summary <- list(
    mean_time = mean(times),
    median_time = median(times),
    min_time = min(times),
    max_time = max(times),
    sd_time = sd(times),
    iterations = iterations
  )
  
  cat("Benchmark results:\n")
  cat("- Mean time:", round(benchmark_summary$mean_time, 3), "seconds\n")
  cat("- Median time:", round(benchmark_summary$median_time, 3), "seconds\n")
  cat("- Min time:", round(benchmark_summary$min_time, 3), "seconds\n")
  cat("- Max time:", round(benchmark_summary$max_time, 3), "seconds\n")
  
  return(benchmark_summary)
} 