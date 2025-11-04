# Centrality Calculation Functions
# Extracted from CVC_preprcs_v4.R and imprinting_Dec18.R
# Original igraph logic preserved, especially for network centrality calculations

# Load required packages
if (!require('igraph')) install.packages('igraph'); library('igraph')
if (!require('data.table')) install.packages('data.table'); library('data.table')

#' Calculate comprehensive centrality measures
#' Original function from CVC_preprcs_v4.R and imprinting_Dec18.R
#' @param round Investment round data
#' @param year Target year
#' @param time_window Time window for network construction
#' @param edge_cutpoint Minimum edge weight threshold
#' @return data.frame with centrality measures
VC_centralities <- function(round, year, time_window, edge_cutpoint) {
  
  cat("Debug: VC_centralities called with year =", year, ", time_window =", time_window, "\n")
  
  # Original logic: Create network matrix
  adjmatrix <- VC_matrix(round, year, time_window, edge_cutpoint)
  
  cat("Debug: Network created with", vcount(adjmatrix), "vertices and", ecount(adjmatrix), "edges\n")
  
  if (vcount(adjmatrix) == 0) {
    cat("Warning: Empty network created for year", year, "\n")
    return(data.frame())
  }
  
  # Original logic: beta (= 1/max_eigenvalues) range determination
  eigen_vals <- eigen(as_adjacency_matrix(adjmatrix))$values
  upsilon <- max(eigen_vals)
  
  # Original centrality calculations from CVC_preprcs_v4.R
  dgr_cent     <- degree(adjmatrix)
  btw_cent <- betweenness(adjmatrix)
  
  # Power centrality with error handling
  tryCatch({
    pwr_p75  <- power_centrality(adjmatrix, exponent = (1/upsilon)*0.75) # Podolny 1993
  }, error = function(e) {
    pwr_p75 <<- rep(0, vcount(adjmatrix))
  })
  
  tryCatch({
    pwr_max <- power_centrality(adjmatrix, exponent = 1/upsilon*(1 - 10^-10)) # in case of upsilon = 1
  }, error = function(e) {
    pwr_max <<- rep(0, vcount(adjmatrix))
  })
  
  tryCatch({
    pwr_zero  <- power_centrality(adjmatrix, exponent = 0)
  }, error = function(e) {
    pwr_zero <<- rep(0, vcount(adjmatrix))
  })
  
  constraint_value <- constraint(adjmatrix) # added constraint
  
  # Original ego network calculation from imprinting_Dec18.R
  egonet_list <- make_ego_graph(adjmatrix)
  
  ego_dta <- data.frame(
    firmname = names(V(adjmatrix)),
    ego_density = lapply(egonet_list, graph.density) %>% unlist()
  )
  
  # Original centrality merge logic from imprinting_Dec18.R
  # Create data.table with proper vector lengths
  cent_dta <- data.table(
    year = rep(year, length(dgr_cent)),
    firmname = names(V(adjmatrix)),
    dgr_cent = dgr_cent, 
    btw_cent = btw_cent,
    pwr_p75 = pwr_p75,
    pwr_max = pwr_max,
    pwr_zero = pwr_zero,
    constraint_value = constraint_value
  )
  
  # Convert both to data.table for safe merging
  cent_dta <- as.data.table(cent_dta)
  ego_dta <- as.data.table(ego_dta)
  
  result <- merge(cent_dta, ego_dta,
                  by="firmname", all.x=TRUE)
  
  return(result)
}

#' Calculate power centrality with different beta values
#' @param network igraph network object
#' @param beta_values Vector of beta values
#' @return data.frame with power centrality measures
calculate_power_centrality <- function(network, beta_values = c(0.75, 1.0, 0.0)) {
  
  # Original logic: beta determination
  upsilon <- max(eigen(as_adjacency_matrix(network))$values)
  
  power_measures <- list()
  for(beta in beta_values) {
    if(beta == 0.75) {
      power_measures[["pwr_p75"]] <- power_centrality(network, exponent = (1/upsilon)*0.75)
    } else if(beta == 1.0) {
      power_measures[["pwr_max"]] <- power_centrality(network, exponent = 1/upsilon*(1 - 10^-10))
    } else if(beta == 0.0) {
      power_measures[["pwr_zero"]] <- power_centrality(network, exponent = 0)
    }
  }
  
  return(as.data.frame(power_measures))
}

#' Calculate ego network density
#' @param network igraph network object
#' @return data.frame with ego density measures
calculate_ego_density <- function(network) {
  
  # Original logic from imprinting_Dec18.R
  egonet_list <- make_ego_graph(network)
  
  ego_dta <- data.frame(
    firmname = names(V(network)),
    ego_density = lapply(egonet_list, graph.density) %>% unlist()
  )
  
  return(ego_dta)
}

#' Calculate structural hole constraint
#' @param network igraph network object
#' @return data.frame with constraint measures
calculate_constraint <- function(network) {
  
  # Original logic from both files
  constraint_value <- constraint(network)
  
  return(data.frame(
    firmname = names(V(network)),
    constraint_value = constraint_value
  ))
} 