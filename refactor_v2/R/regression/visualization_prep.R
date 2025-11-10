## visualization_prep.R
## Prepare tidy coefficient tables for plotting (coef and intervals)

# Auto-install missing packages
required_packages <- c("dplyr", "tidyr", "broom", "broom.mixed", "purrr", "readr")
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
  library(purrr)
  library(readr)
})

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
  td <- add_significance_stars(td)
  td$model <- model_label
  td %>%
    select(model, component, term, estimate, conf.low, conf.high, p.value = any_of("p.value"), stars)
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


