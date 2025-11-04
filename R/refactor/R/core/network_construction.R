# Network Construction Functions
# Extracted from CVC_preprcs_v4.R and imprinting_Dec18.R
# Original logic preserved, only unified for consistency

# Load required packages
if (!require('igraph')) install.packages('igraph'); library('igraph')

#' Create VC network matrix from investment data
#' Original function from CVC_preprcs_v4.R and imprinting_Dec18.R
#' @param round Investment round data (firmname, event, year, timewave)
#' @param year Target year for network construction
#' @param time_window Time window for network (default: 5)
#' @param edge_cutpoint Minimum edge weight threshold (optional)
#' @param timewave_unit Timewave unit: "year" or "quarter" (default: "year")
#' @return igraph network object
VC_matrix <- function(round, year, time_window = NULL, edge_cutpoint = NULL, timewave_unit = "year") {
  
  # Debug: Check input data
  cat("Debug: VC_matrix called with year =", year, ", time_window =", time_window, "\n")
  cat("Debug: round data dimensions:", dim(round), "\n")
  cat("Debug: round years range:", range(round$year, na.rm = TRUE), "\n")
  
  # Original logic from CVC_preprcs_v4.R
  if(!is.null(time_window)) {
    edgelist <- round[round$year <= year-1 & round$year >= year-time_window, # t-5 ~ t-1
                      c("firmname", "event")]
    cat("Debug: Filtered edgelist dimensions:", dim(edgelist), "\n")
    cat("Debug: Edgelist columns:", colnames(edgelist), "\n")
  } else {
    edgelist <- round[round$year == year-1, c("firmname", "event")] # t-1
    cat("Debug: Single year edgelist dimensions:", dim(edgelist), "\n")
  }
  
  # Ensure bipartite structure by checking for unique values
  # Convert to data.frame if it's a tibble
  if (inherits(edgelist, "tbl_df")) {
    edgelist <- as.data.frame(edgelist)
  }
  
  firmnames <- unique(edgelist[,1])
  events <- unique(edgelist[,2])
  
  # Convert to character for safe comparison
  firmnames <- as.character(firmnames)
  events <- as.character(events)
  
  # Check if there are overlapping names between firms and events
  overlap <- intersect(firmnames, events)
  if (length(overlap) > 0) {
    cat("Warning: Found overlapping names between firms and events:", overlap[1:min(5, length(overlap))], "\n")
    # Add prefix to events to make them unique
    edgelist[,2] <- paste0("event_", edgelist[,2])
  }
  
  twomode <- graph_from_edgelist(as.matrix(edgelist), directed = FALSE)
  
  # Set bipartite type: TRUE for events (second column), FALSE for firms (first column)
  V(twomode)$type <- V(twomode)$name %in% edgelist[,2]
  
  onemode <- bipartite_projection(twomode)$proj1
  
  # Original logic from imprinting_Dec18.R for edge cutpoint
  if(!is.null(edge_cutpoint)) {
    onemode <- delete_edges(onemode, which(E(onemode)$weight < edge_cutpoint))
  } else {}
  
  return(onemode)
}

#' Create bipartite network from VC-Company relationships
#' @param edge_data Investment edge data
#' @param year Target year
#' @param time_window Time window
#' @return igraph bipartite network
create_bipartite_network <- function(edge_data, year, time_window = 5) {
  
  if(!is.null(time_window)) {
    edgelist <- edge_data[edge_data$year <= year & edge_data$year >= year-time_window+1, 
                         c("firmname", "event")]
  } else {
    edgelist <- edge_data[edge_data$year == year, c("firmname", "event")]
  }
  
  twomode <- graph_from_edgelist(as.matrix(edgelist), directed = FALSE)
  V(twomode)$type <- V(twomode)$name %in% edgelist[,2]
  
  return(twomode)
}

#' Project bipartite network to one-mode network
#' @param bipartite_net Bipartite network
#' @param projection_type "vc_vc" or "event_event"
#' @return igraph one-mode network
project_network <- function(bipartite_net, projection_type = "vc_vc") {
  
  if(projection_type == "vc_vc") {
    return(bipartite_projection(bipartite_net)$proj1)
  } else if(projection_type == "event_event") {
    return(bipartite_projection(bipartite_net)$proj2)
  } else {
    stop("projection_type must be 'vc_vc' or 'event_event'")
  }
}

#' Identify initial network ties for a specific year
#' @param round Round data
#' @param year Target year
#' @param imprinting_period Imprinting period length
#' @return Initial ties data
VC_initial_ties <- function(round, year, imprinting_period = 3) {
  
  # Original logic from imprinting_Dec18.R
  # Get all ties in the imprinting period
  ties <- round %>%
    filter(year >= year - imprinting_period & year <= year) %>%
    group_by(firmname, comname) %>%
    summarise(tied_year = year, .groups = "drop")
  
  # Add initial partner information
  ties <- ties %>%
    group_by(firmname) %>%
    mutate(initial_partner = first(comname)) %>%
    ungroup()
  
  return(ties)
} 