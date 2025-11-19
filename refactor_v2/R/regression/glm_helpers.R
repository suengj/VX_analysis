# glm_helpers.R
# Shared helpers for Gaussian / Logistic GLM runs in imprinting pipeline

# Build formula from DV, IV, controls, Mundlak means, and interaction terms
build_glm_formula <- function(dv, init_vars, controls, mundlak_terms, interaction_terms) {
  rhs <- c(init_vars, controls, mundlak_terms, interaction_terms)
  rhs <- rhs[!is.na(rhs) & nzchar(rhs)]
  rhs <- rhs[!duplicated(rhs)]
  rhs_str <- if (length(rhs) > 0) paste(rhs, collapse = " + ") else "1"
  stats::as.formula(paste0(dv, " ~ ", rhs_str))
}

# Export glm coefficients to CSV with significance stars
export_glm_results <- function(model, dv, model_tag, out_dir) {
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  timestamp <- format(Sys.time(), "%y%m%d_%H%M")
  coef_mat <- summary(model)$coefficients
  coef_df <- tibble::as_tibble(coef_mat, rownames = "term")
  names(coef_df) <- c("term", "estimate", "std.error", "statistic", "p.value")
  coef_df <- dplyr::mutate(
    coef_df,
    stars = dplyr::case_when(
      p.value < 0.001 ~ "***",
      p.value < 0.01  ~ "**",
      p.value < 0.05  ~ "*",
      TRUE             ~ ""
    )
  )
  readr::write_csv(
    coef_df,
    file.path(out_dir, paste0("model_", dv, "_", model_tag, "_coef_", timestamp, ".csv"))
  )
}

# Fit generic GLM and export results
fit_glm_model <- function(df, dv, init_vars, controls, mundlak_terms, interaction_terms,
                          family, model_tag, out_dir) {
  fml <- build_glm_formula(dv, init_vars, controls, mundlak_terms, interaction_terms)
  message(sprintf("GLM formula: %s", deparse(fml)))
  glm_fit <- stats::glm(fml, data = df, family = family)
  export_glm_results(glm_fit, dv, model_tag, out_dir)
  glm_fit
}


