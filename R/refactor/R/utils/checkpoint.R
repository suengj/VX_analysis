# Checkpoint System for VC Analysis
# Created: 2025-10-11
# Purpose: Save and restore analysis progress for long-running tasks

#' Save Checkpoint
#'
#' @param step_name Name of the step
#' @param data Data to save (can be list, data.frame, or any R object)
#' @param checkpoint_dir Directory for checkpoint files
#' @param metadata Additional metadata to save
#' @export
checkpoint_save <- function(step_name, 
                           data, 
                           checkpoint_dir = "checkpoints",
                           metadata = NULL) {
  
  # Create checkpoint directory if it doesn't exist
  if(!dir.exists(checkpoint_dir)) {
    dir.create(checkpoint_dir, recursive = TRUE)
  }
  
  # Generate checkpoint file path
  checkpoint_file <- file.path(checkpoint_dir, sprintf("%s.rds", step_name))
  
  # Prepare checkpoint object
  checkpoint_obj <- list(
    step_name = step_name,
    data = data,
    timestamp = Sys.time(),
    metadata = metadata,
    session_info = sessionInfo()
  )
  
  # Save checkpoint
  tryCatch({
    saveRDS(checkpoint_obj, file = checkpoint_file, compress = TRUE)
    
    cat(sprintf("✅ Checkpoint saved: %s\n", step_name))
    cat(sprintf("   File: %s\n", checkpoint_file))
    cat(sprintf("   Size: %.2f MB\n", file.size(checkpoint_file) / 1024^2))
    cat(sprintf("   Time: %s\n\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
    
    return(TRUE)
  }, error = function(e) {
    cat(sprintf("❌ Failed to save checkpoint: %s\n", e$message))
    return(FALSE)
  })
}


#' Load Checkpoint
#'
#' @param step_name Name of the step
#' @param checkpoint_dir Directory for checkpoint files
#' @return Checkpoint data or NULL if not found
#' @export
checkpoint_load <- function(step_name, 
                           checkpoint_dir = "checkpoints") {
  
  # Generate checkpoint file path
  checkpoint_file <- file.path(checkpoint_dir, sprintf("%s.rds", step_name))
  
  # Check if checkpoint exists
  if(!file.exists(checkpoint_file)) {
    cat(sprintf("⚠️ No checkpoint found for: %s\n", step_name))
    return(NULL)
  }
  
  # Load checkpoint
  tryCatch({
    checkpoint_obj <- readRDS(checkpoint_file)
    
    cat(sprintf("✅ Checkpoint loaded: %s\n", step_name))
    cat(sprintf("   Saved at: %s\n", format(checkpoint_obj$timestamp, "%Y-%m-%d %H:%M:%S")))
    cat(sprintf("   Time elapsed: %.2f hours\n\n", 
               difftime(Sys.time(), checkpoint_obj$timestamp, units = "hours")))
    
    return(checkpoint_obj$data)
  }, error = function(e) {
    cat(sprintf("❌ Failed to load checkpoint: %s\n", e$message))
    return(NULL)
  })
}


#' Check if Checkpoint Exists
#'
#' @param step_name Name of the step
#' @param checkpoint_dir Directory for checkpoint files
#' @return TRUE if checkpoint exists, FALSE otherwise
#' @export
checkpoint_exists <- function(step_name, 
                             checkpoint_dir = "checkpoints") {
  
  checkpoint_file <- file.path(checkpoint_dir, sprintf("%s.rds", step_name))
  return(file.exists(checkpoint_file))
}


#' List All Checkpoints
#'
#' @param checkpoint_dir Directory for checkpoint files
#' @return Data frame with checkpoint information
#' @export
checkpoint_list <- function(checkpoint_dir = "checkpoints") {
  
  if(!dir.exists(checkpoint_dir)) {
    cat("⚠️ No checkpoint directory found\n")
    return(NULL)
  }
  
  # Get all .rds files
  checkpoint_files <- list.files(checkpoint_dir, pattern = "\\.rds$", full.names = TRUE)
  
  if(length(checkpoint_files) == 0) {
    cat("⚠️ No checkpoints found\n")
    return(NULL)
  }
  
  # Get file info
  checkpoint_info <- data.frame(
    step_name = gsub("\\.rds$", "", basename(checkpoint_files)),
    file_path = checkpoint_files,
    size_mb = file.size(checkpoint_files) / 1024^2,
    modified = file.mtime(checkpoint_files),
    stringsAsFactors = FALSE
  )
  
  # Sort by modification time
  checkpoint_info <- checkpoint_info[order(checkpoint_info$modified, decreasing = TRUE), ]
  
  # Print summary
  cat(sprintf("📋 Found %d checkpoint(s):\n\n", nrow(checkpoint_info)))
  for(i in 1:nrow(checkpoint_info)) {
    cat(sprintf("%d. %s (%.2f MB) - %s\n", 
               i,
               checkpoint_info$step_name[i],
               checkpoint_info$size_mb[i],
               format(checkpoint_info$modified[i], "%Y-%m-%d %H:%M:%S")))
  }
  cat("\n")
  
  return(checkpoint_info)
}


#' Delete Checkpoint
#'
#' @param step_name Name of the step (or "all" to delete all)
#' @param checkpoint_dir Directory for checkpoint files
#' @export
checkpoint_delete <- function(step_name, 
                             checkpoint_dir = "checkpoints") {
  
  if(step_name == "all") {
    # Delete all checkpoints
    checkpoint_files <- list.files(checkpoint_dir, pattern = "\\.rds$", full.names = TRUE)
    
    if(length(checkpoint_files) == 0) {
      cat("⚠️ No checkpoints to delete\n")
      return(invisible(FALSE))
    }
    
    cat(sprintf("⚠️ Deleting %d checkpoint(s)...\n", length(checkpoint_files)))
    unlink(checkpoint_files)
    cat("✅ All checkpoints deleted\n\n")
    
    return(invisible(TRUE))
  } else {
    # Delete specific checkpoint
    checkpoint_file <- file.path(checkpoint_dir, sprintf("%s.rds", step_name))
    
    if(!file.exists(checkpoint_file)) {
      cat(sprintf("⚠️ Checkpoint not found: %s\n", step_name))
      return(invisible(FALSE))
    }
    
    unlink(checkpoint_file)
    cat(sprintf("✅ Checkpoint deleted: %s\n\n", step_name))
    
    return(invisible(TRUE))
  }
}


#' Execute with Checkpoint Support
#'
#' @param step_name Name of the step
#' @param expr Expression to execute
#' @param force_rerun If TRUE, ignore existing checkpoint
#' @param checkpoint_dir Directory for checkpoint files
#' @param save_checkpoint If TRUE, save checkpoint after execution
#' @return Result of expression
#' @export
checkpoint_execute <- function(step_name,
                              expr,
                              force_rerun = FALSE,
                              checkpoint_dir = "checkpoints",
                              save_checkpoint = TRUE) {
  
  # Check if checkpoint exists
  if(!force_rerun && checkpoint_exists(step_name, checkpoint_dir)) {
    cat(sprintf("📦 Loading existing checkpoint: %s\n\n", step_name))
    return(checkpoint_load(step_name, checkpoint_dir))
  }
  
  # Execute expression
  cat(sprintf("⚙️ Executing: %s\n\n", step_name))
  start_time <- Sys.time()
  
  result <- eval(expr, envir = parent.frame())
  
  end_time <- Sys.time()
  elapsed <- difftime(end_time, start_time, units = "mins")
  
  cat(sprintf("\n✅ Completed in %.2f minutes\n", elapsed))
  
  # Save checkpoint
  if(save_checkpoint) {
    checkpoint_save(
      step_name = step_name,
      data = result,
      checkpoint_dir = checkpoint_dir,
      metadata = list(
        execution_time = elapsed,
        start_time = start_time,
        end_time = end_time
      )
    )
  }
  
  return(result)
}


#' Create Checkpoint Summary
#'
#' @param checkpoint_dir Directory for checkpoint files
#' @export
checkpoint_summary <- function(checkpoint_dir = "checkpoints") {
  
  if(!dir.exists(checkpoint_dir)) {
    cat("⚠️ No checkpoint directory found\n")
    return(invisible(NULL))
  }
  
  checkpoint_info <- checkpoint_list(checkpoint_dir)
  
  if(is.null(checkpoint_info)) {
    return(invisible(NULL))
  }
  
  # Calculate statistics
  total_size <- sum(checkpoint_info$size_mb)
  oldest <- min(checkpoint_info$modified)
  newest <- max(checkpoint_info$modified)
  
  cat("📊 Checkpoint Summary:\n")
  cat(sprintf("   Total checkpoints: %d\n", nrow(checkpoint_info)))
  cat(sprintf("   Total size: %.2f MB\n", total_size))
  cat(sprintf("   Oldest: %s\n", format(oldest, "%Y-%m-%d %H:%M:%S")))
  cat(sprintf("   Newest: %s\n\n", format(newest, "%Y-%m-%d %H:%M:%S")))
  
  return(invisible(checkpoint_info))
}






