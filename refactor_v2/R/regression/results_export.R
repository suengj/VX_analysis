## results_export.R
## Generic exporters for glm and glmmTMB (and placeholders for others)

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

#' Export model results with automatic detection
#' @param model fitted object (glm, glmmTMB)
#' @param dv dependent variable tag
#' @param tag short model label
#' @param out_dir output directory
#' @param exponentiate exponentiate estimates (IRR for count models)
export_model_results <- function(model, dv, tag,
                                 out_dir = file.path(
                                   "/Users","suengj","Documents","Code","Python","Research","VC",
                                   "refactor_v2","notebooks","analysis_outputs"),
                                 exponentiate = TRUE) {
  ensure_outdir(out_dir)
  cls <- class(model)
  if ("glmmTMB" %in% cls) {
    cond <- broom.mixed::tidy(model, effects = "fixed", component = "cond", conf.int = TRUE, exponentiate = exponentiate)
    zi   <- try(broom.mixed::tidy(model, effects = "fixed", component = "zi", conf.int = TRUE, exponentiate = exponentiate), silent = TRUE)
    gl   <- broom.mixed::glance(model)
    readr::write_csv(cond, file.path(out_dir, paste0("export_", dv, "_", tag, "_cond.csv")))
    if (!inherits(zi, "try-error")) {
      readr::write_csv(zi,   file.path(out_dir, paste0("export_", dv, "_", tag, "_zi.csv")))
    }
    readr::write_csv(gl, file.path(out_dir, paste0("export_", dv, "_", tag, "_glance.csv")))
    return(invisible(TRUE))
  }
  if ("glm" %in% cls) {
    td <- broom::tidy(model, conf.int = TRUE, exponentiate = exponentiate)
    gl <- broom::glance(model)
    readr::write_csv(td, file.path(out_dir, paste0("export_", dv, "_", tag, "_coef.csv")))
    readr::write_csv(gl, file.path(out_dir, paste0("export_", dv, "_", tag, "_glance.csv")))
    return(invisible(TRUE))
  }
  # Fallback
  readr::write_csv(tibble::tibble(note = paste("No exporter implemented for class:", paste(cls, collapse = ","))),
                   file.path(out_dir, paste0("export_", dv, "_", tag, "_UNSUPPORTED.csv")))
  invisible(FALSE)
}


