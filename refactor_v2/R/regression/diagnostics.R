## diagnostics.R
## Description, correlation, and VIF diagnostics; export CSVs

# Auto-install missing packages
required_packages <- c("dplyr", "tidyr", "readr", "psych", "Hmisc", "performance", "car", "broom")
missing_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]
if(length(missing_packages) > 0) {
  message("Installing missing packages: ", paste(missing_packages, collapse = ", "))
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(psych)
  library(Hmisc)
  library(performance)
  library(car)
  library(broom)
})

#' Ensure output directory
ensure_outdir <- function(path) {
  if (!dir.exists(path)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
}

#' Prepare numeric-only matrix for correlation
safe_numeric <- function(df) {
  df %>%
    mutate(across(everything(), ~ suppressWarnings(as.numeric(.x)))) %>%
    select(where(is.numeric))
}

#' Run diagnostics (describe, correlation, VIF)
#' @param df modeling data
#' @param dv dependent variable name
#' @param predictors character vector of predictor names
#' @param out_dir output directory for CSVs
run_diagnostics <- function(df, dv, predictors, out_dir) {
  ensure_outdir(out_dir)
  
  # Generate timestamp for file naming
  timestamp <- format(Sys.time(), "%y%m%d_%H%M")
  
  # 1) Description
  desc_df <- psych::describe(df %>% select(all_of(c(dv, predictors))) %>% safe_numeric())
  desc_out <- file.path(out_dir, paste0("diagnostics_description_", dv, "_", timestamp, ".csv"))
  readr::write_csv(tibble::rownames_to_column(as.data.frame(desc_df), var = "variable"), desc_out)
  
  # 2) Correlation (numeric only)
  corr_input <- df %>% select(all_of(c(dv, predictors))) %>% safe_numeric() %>% as.data.frame()
  rc <- Hmisc::rcorr(as.matrix(corr_input))
  corr_r <- as.data.frame(rc$r) %>% tibble::rownames_to_column("var1")
  corr_p <- as.data.frame(rc$P) %>% tibble::rownames_to_column("var1")
  readr::write_csv(corr_r, file.path(out_dir, paste0("diagnostics_corr_r_", dv, "_", timestamp, ".csv")))
  readr::write_csv(corr_p, file.path(out_dir, paste0("diagnostics_corr_p_", dv, "_", timestamp, ".csv")))
  
  # 3) VIF
  # Primary attempt: performance::check_collinearity on Gaussian proxy GLM
  f_str <- paste0("log1p(", dv, ") ~ ", paste(predictors, collapse = " + "))
  glm_proxy <- try(stats::lm(stats::as.formula(f_str), data = df), silent = TRUE)
  
  vif_out_path <- file.path(out_dir, paste0("diagnostics_vif_", dv, "_", timestamp, ".csv"))
  if (!inherits(glm_proxy, "try-error")) {
    # Try performance first
    cc <- try(performance::check_collinearity(glm_proxy), silent = TRUE)
    if (!inherits(cc, "try-error")) {
      cc_df <- as.data.frame(cc)
      readr::write_csv(cc_df, vif_out_path)
      return(invisible(TRUE))
    }
    # Fallback to car::vif
    cv <- try(car::vif(glm_proxy), silent = TRUE)
    if (!inherits(cv, "try-error")) {
      cv_df <- tibble::tibble(term = names(cv), VIF = as.numeric(cv))
      readr::write_csv(cv_df, vif_out_path)
      return(invisible(TRUE))
    }
  }
  
  # If both methods fail
  readr::write_csv(tibble::tibble(note = "VIF not computed (model fit failed)"), vif_out_path)
  invisible(FALSE)
}

# Regression Diagnostics
#
# This script provides diagnostic tools for regression models including:
# - VIF (Variance Inflation Factor)
# - Condition Index
# - Model fit statistics
# - Robustness checks

#' Calculate VIF (Variance Inflation Factor)
#'
#' @param model Model object
#' @param threshold VIF threshold (default: 10)
#' @return VIF values
check_vif <- function(model, threshold = 10) {
  
  cat("\n========== VIF Analysis ==========\n\n")
  
  tryCatch({
    vif_values <- vif(model)
    
    print(vif_values)
    
    # Check for high VIF
    high_vif <- vif_values[vif_values > threshold]
    
    if (length(high_vif) > 0) {
      cat("\n⚠️  Warning: High VIF detected (>", threshold, "):\n")
      print(high_vif)
      cat("\nConsider removing or combining these variables.\n")
    } else {
      cat("\n✓ All VIF values below threshold\n")
    }
    
    return(vif_values)
    
  }, error = function(e) {
    cat("Error calculating VIF:", e$message, "\n")
    return(NULL)
  })
}


#' Calculate Condition Index
#'
#' @param df Data frame with predictor variables
#' @param var_names Variable names to check
#' @return Condition indices
check_condition_index <- function(df, var_names) {
  
  cat("\n========== Condition Index Analysis ==========\n\n")
  
  # Select numeric variables
  X <- df[, var_names, drop = FALSE]
  X <- X[, sapply(X, is.numeric), drop = FALSE]
  
  # Standardize
  X_std <- scale(X)
  
  # Calculate correlation matrix
  cor_matrix <- cor(X_std, use = "pairwise.complete.obs")
  
  # Eigenvalues
  eigenvalues <- eigen(cor_matrix)$values
  
  # Condition indices
  condition_index <- sqrt(max(eigenvalues) / eigenvalues)
  
  cat("Condition Indices:\n")
  print(condition_index)
  
  # Check for multicollinearity
  max_ci <- max(condition_index)
  if (max_ci > 30) {
    cat("\n⚠️  Warning: High condition index detected (", max_ci, ")\n")
    cat("Strong multicollinearity present.\n")
  } else if (max_ci > 15) {
    cat("\n⚠️  Warning: Moderate condition index (", max_ci, ")\n")
    cat("Moderate multicollinearity present.\n")
  } else {
    cat("\n✓ Condition indices acceptable\n")
  }
  
  return(condition_index)
}


#' Model Fit Statistics
#'
#' @param model Model object
#' @return Fit statistics
get_fit_statistics <- function(model) {
  
  cat("\n========== Model Fit Statistics ==========\n\n")
  
  fit_stats <- list(
    aic = AIC(model),
    bic = BIC(model),
    log_likelihood = logLik(model)[1]
  )
  
  # Additional statistics depending on model type
  if ("clogit" %in% class(model)) {
    fit_stats$concordance <- model$concordance[1]
    fit_stats$n_events <- model$nevent
  }
  
  if ("plm" %in% class(model)) {
    fit_stats$r_squared <- summary(model)$r.squared[1]
    fit_stats$adj_r_squared <- summary(model)$r.squared[2]
  }
  
  print(fit_stats)
  
  return(fit_stats)
}


#' Robustness Check: Clustered Standard Errors
#'
#' @param model Model object
#' @param cluster_var Cluster variable name
#' @return Model with clustered SEs
check_clustered_se <- function(model, cluster_var) {
  
  cat("\n========== Clustered Standard Errors ==========\n\n")
  cat("Clustering by:", cluster_var, "\n\n")
  
  tryCatch({
    # Use coeftest with cluster-robust SEs
    robust_se <- coeftest(model, vcov = vcovHC(model, cluster = cluster_var))
    
    print(robust_se)
    
    return(robust_se)
    
  }, error = function(e) {
    cat("Error calculating clustered SEs:", e$message, "\n")
    return(NULL)
  })
}


#' Robustness Check: Subsample Analysis
#'
#' @param df Data frame
#' @param formula Model formula
#' @param subsamples List of subsample conditions
#' @return List of subsample models
run_subsample_analysis <- function(df, formula, subsamples) {
  
  cat("\n========== Subsample Analysis ==========\n\n")
  
  results <- list()
  
  for (name in names(subsamples)) {
    cat("\nSubsample:", name, "\n")
    
    condition <- subsamples[[name]]
    df_sub <- df %>% filter(eval(parse(text = condition)))
    
    cat("N observations:", nrow(df_sub), "\n")
    
    # Run model on subsample
    model_sub <- run_cvc_clogit(df_sub, formula)
    
    results[[name]] <- model_sub
  }
  
  return(results)
}


#' Compare Coefficients Across Models
#'
#' @param models List of models
#' @param coef_names Coefficient names to compare
#' @return Comparison table
compare_coefficients <- function(models, coef_names = NULL) {
  
  cat("\n========== Coefficient Comparison ==========\n\n")
  
  # Extract coefficients from each model
  coef_list <- lapply(names(models), function(name) {
    model <- models[[name]]
    coef_df <- tidy(model)
    coef_df$model <- name
    return(coef_df)
  })
  
  coef_table <- bind_rows(coef_list)
  
  # Filter to specific coefficients if provided
  if (!is.null(coef_names)) {
    coef_table <- coef_table %>% filter(term %in% coef_names)
  }
  
  # Reshape for comparison
  comparison <- coef_table %>%
    select(model, term, estimate, std.error, p.value) %>%
    pivot_wider(
      names_from = model,
      values_from = c(estimate, std.error, p.value),
      names_sep = "_"
    )
  
  print(comparison)
  
  return(comparison)
}


# Example usage:
# check_vif(model)
# check_condition_index(data, var_names = c("dgr_cent", "btw_cent", "pwr_p75"))
# get_fit_statistics(model)
# robust_results <- check_clustered_se(model, "firmname")

