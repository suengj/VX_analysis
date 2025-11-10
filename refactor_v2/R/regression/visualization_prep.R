## visualization_prep.R
## Prepare tidy coefficient tables for plotting (coef and intervals)

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(broom)
  library(broom.mixed)
  library(purrr)
  library(readr)
})

#' Tidy a single model into a plotting-friendly table
#' @param model fitted object (glm/glmmTMB)
#' @param model_label short label for facet/legend
#' @param component 'cond' or 'zi' for glmmTMB; ignored for glm
#' @param exponentiate exponentiate estimates for count models (IRR)
tidy_for_plot <- function(model, model_label, component = "cond", exponentiate = TRUE) {
  cls <- class(model)
  if ("glmmTMB" %in% cls) {
    td <- broom.mixed::tidy(model, effects = "fixed", component = component, conf.int = TRUE, exponentiate = exponentiate)
    td$component <- component
  } else if ("glm" %in% cls) {
    td <- broom::tidy(model, conf.int = TRUE, exponentiate = exponentiate)
    td$component <- "cond"
  } else {
    td <- tibble::tibble(term = character(), estimate = numeric(), conf.low = numeric(), conf.high = numeric(), component = character())
  }
  td$model <- model_label
  td %>%
    select(model, component, term, estimate, conf.low, conf.high, p.value = any_of("p.value"))
}

#' Combine multiple models into one table and optionally write to CSV
#' @param models named list of models (names used as labels)
#' @param out_csv optional output path
#' @param include_zi include zero-inflation component for glmmTMB
combine_models_for_plot <- function(models, out_csv = NULL, include_zi = FALSE) {
  tables <- purrr::imap(models, function(m, lbl) {
    res <- tidy_for_plot(m, lbl, component = "cond", exponentiate = TRUE)
    if (include_zi && inherits(m, "glmmTMB")) {
      res_zi <- tidy_for_plot(m, lbl, component = "zi", exponentiate = TRUE)
      res <- dplyr::bind_rows(res, res_zi)
    }
    res
  })
  out <- dplyr::bind_rows(tables)
  if (!is.null(out_csv)) {
    readr::write_csv(out, out_csv)
  }
  out
}


