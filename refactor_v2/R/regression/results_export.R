## results_export.R
## Generic exporters for glm and glmmTMB (and placeholders for others)

# Auto-install missing packages
required_packages <- c("dplyr", "tidyr", "broom", "broom.mixed", "readr")
missing_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]
if(length(missing_packages) > 0) {
  message("Installing missing packages: ", paste(missing_packages, collapse = ", "))
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(broom)
  library(broom.mixed)
  library(readr)
})

ensure_outdir <- function(path) {
  if (!dir.exists(path)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
}

#' Add significance stars to tidy output
#' @param df tidy output from broom/broom.mixed
#' @return df with 'stars' column
add_significance_stars <- function(df) {
  if (!"p.value" %in% names(df)) {
    df$stars <- ""
    return(df)
  }
  df$stars <- dplyr::case_when(
    df$p.value < 0.001 ~ "***",
    df$p.value < 0.01  ~ "**",
    df$p.value < 0.05  ~ "*",
    TRUE                ~ ""
  )
  df
}

#' Export model results with automatic detection
#' @param model fitted object (glm, glmmTMB)
#' @param dv dependent variable tag
#' @param tag short model label
#' @param out_dir output directory
#' @param exponentiate exponentiate estimates (IRR for count models)
export_model_results <- function(model, dv, tag,
                                 out_dir = file.path(
                                   "/Users","suengj","Documents","Code","Python","Research","VC",
                                   "refactor_v2","notebooks","output"),
                                 exponentiate = TRUE) {
  ensure_outdir(out_dir)
  
  # Generate timestamp for file naming
  timestamp <- format(Sys.time(), "%y%m%d_%H%M")
  
  cls <- class(model)
  if ("glmmTMB" %in% cls) {
    cond <- broom.mixed::tidy(model, effects = "fixed", component = "cond", conf.int = TRUE, exponentiate = exponentiate)
    cond <- add_significance_stars(cond)
    zi   <- try(broom.mixed::tidy(model, effects = "fixed", component = "zi", conf.int = TRUE, exponentiate = exponentiate), silent = TRUE)
    if (!inherits(zi, "try-error")) {
      zi <- add_significance_stars(zi)
    }
    gl   <- broom.mixed::glance(model)
    readr::write_csv(cond, file.path(out_dir, paste0("export_", dv, "_", tag, "_cond_", timestamp, ".csv")))
    if (!inherits(zi, "try-error")) {
      readr::write_csv(zi,   file.path(out_dir, paste0("export_", dv, "_", tag, "_zi_", timestamp, ".csv")))
    }
    readr::write_csv(gl, file.path(out_dir, paste0("export_", dv, "_", tag, "_glance_", timestamp, ".csv")))
    return(invisible(TRUE))
  }
  if ("glm" %in% cls) {
    td <- broom::tidy(model, conf.int = TRUE, exponentiate = exponentiate)
    td <- add_significance_stars(td)
    gl <- broom::glance(model)
    readr::write_csv(td, file.path(out_dir, paste0("export_", dv, "_", tag, "_coef_", timestamp, ".csv")))
    readr::write_csv(gl, file.path(out_dir, paste0("export_", dv, "_", tag, "_glance_", timestamp, ".csv")))
    return(invisible(TRUE))
  }
  # Fallback
  readr::write_csv(tibble::tibble(note = paste("No exporter implemented for class:", paste(cls, collapse = ","))),
                   file.path(out_dir, paste0("export_", dv, "_", tag, "_UNSUPPORTED_", timestamp, ".csv")))
  invisible(FALSE)
}


