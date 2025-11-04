# Imprinting Analysis Functions
# Extracted from imprinting_Dec18.R
# Original logic preserved for imprinting effect analysis

# Load required packages
if (!require('igraph')) install.packages('igraph'); library('igraph')
if (!require('tidyverse')) install.packages('tidyverse'); library('tidyverse')
if (!require('data.table')) install.packages('data.table'); library('data.table')

#' Identify initial network ties
#' Original function from imprinting_Dec18.R
#' @param edge_raw Edge data
#' @param y Target year
#' @param time_window Time window for analysis
#' @return Initial ties data
VC_initial_ties <- function(edge_raw, y, time_window=NULL){
  
  # Original logic from imprinting_Dec18.R
  if(!is.null(time_window)) {
    edge_df <- edge_raw %>% as_tibble() %>%
      filter(year >= y & year < y+time_window) %>% as.data.frame() # y ~ y+ (time window)
    
  } else {
    edge_df <- edge_raw %>% as_tibble() %>% 
      filter(year == y) %>% as.data.frame() # 1-year only
  }
  
  y_loop <- edge_df %>% as_tibble() %>% 
    select(year) %>%
    distinct()
  
  df_list <- list()
  for(i in 1:NROW(y_loop)){
    tmp <- edge_df %>% filter(year==as.numeric(y_loop[i,1]))
    
    # Ensure we have the correct columns for bipartite network
    if (nrow(tmp) > 0 && all(c("firmname", "comname") %in% colnames(tmp))) {
      # Create bipartite network with firmname and comname
      edge_data <- tmp[, c("firmname", "comname")]
      
      # Remove any rows with missing values
      edge_data <- edge_data[complete.cases(edge_data), ]
      
      if (nrow(edge_data) > 0) {
        # Check for overlapping names between firms and companies
        firmnames <- unique(edge_data[,1])
        companynames <- unique(edge_data[,2])
        overlap <- intersect(as.character(firmnames), as.character(companynames))
        if (length(overlap) > 0) {
          cat("Warning: Found", length(overlap), "overlapping names between firms and companies\n")
          # Add prefix to companies to make them unique
          edge_data[,2] <- paste0("com_", edge_data[,2])
        }
        
        # Create bipartite graph
        twomode <- graph_from_data_frame(edge_data, directed = FALSE)
        
        # Set vertex types: TRUE for firms (first column), FALSE for companies (second column)
        V(twomode)$type <- V(twomode)$name %in% edge_data[,1]
        
        # Check if graph is bipartite
        if (is_bipartite(twomode)) {
          # Create bipartite projection (firm-firm network)
          edge_list <- bipartite_projection(twomode)$proj1  # proj1 for firms
          
          if (length(E(edge_list)) > 0) {
            df1 <- as.data.frame(get.edgelist(edge_list))
            df1$tied_year <- as.numeric(y_loop[i,1])
            
            df2 <- df1
            colnames(df2) <- c("V2","V1","tied_year")
            
            df_list[[i]] <- rbind(df1, df2)
          }
        }
      }
    }
  }
  
  if (length(df_list) > 0) {
    df <- do.call("rbind", df_list)
    
    # Rename columns to match expected format
    if (nrow(df) > 0) {
      colnames(df) <- c("firmname", "initial_partner", "tied_year")
    } else {
      df <- data.frame(firmname = character(), initial_partner = character(), tied_year = numeric())
    }
  } else {
    df <- data.frame(firmname = character(), initial_partner = character(), tied_year = numeric())
  }

  return(df)
}

#' Filter initial period ties
#' Original function from imprinting_Dec18.R
#' @param df Initial ties data
#' @param period Imprinting period
#' @return Filtered initial period data
VC_initial_period <- function(df, period){
  
  # Original logic from imprinting_Dec18.R
  df <- df %>%
    mutate(check = tied_year - initial_year) %>%
    filter(check < period) %>%
    select(-check)
  
  return(df)
}

#' Calculate focal firm centrality from initial partners
#' Original function from imprinting_Dec18.R
#' @param initial_partner_list Initial partner list
#' @param cent Centrality data
#' @return Focal firm centrality data
VC_initial_focal_centrality <- function(initial_partner_list, cent){
  
  # Original logic from imprinting_Dec18.R
  df <- left_join(initial_partner_list, cent,
                  by=c("firmname" = "firmname",
                       "tied_year" = "year"))
  
  # summarize by mean
  df_mean <- df %>%
    dplyr::select(-initial_partner) %>%
    group_by(firmname, tied_year) %>%
    summarise(across(matches("dgr|btw|pwr|cons|density"), mean, na.rm = TRUE), .groups = "drop")
  
  # merge
  df_merged <- rename_with(df_mean,
                           .fn = ~paste0("f_", .),
                           .cols = matches("dgr|btw|pwr|cons|density"))
  
  return(df_merged)
}

#' Calculate initial partner centrality
#' Original function from imprinting_Dec18.R
#' @param initial_partner_list Initial partner list
#' @param cent Centrality data
#' @return Initial partner centrality data
VC_initial_partner_centrality <- function(initial_partner_list, cent){
  
  # Original logic from imprinting_Dec18.R
  df <- left_join(initial_partner_list, cent,
                  by=c("initial_partner" = "firmname",
                       "tied_year" = "year"))
  
  # summarize by sum
  df_sum <- df %>%
    dplyr::select(-initial_partner) %>%
    group_by(firmname, tied_year) %>%
    summarise(across(matches("dgr"), sum, na.rm = TRUE), .groups = "drop")
  
  # summarize by mean
  df_mean <- df %>%
    dplyr::select(-initial_partner) %>%
    group_by(firmname, tied_year) %>%
    summarise(across(matches("btw|pwr|cons|density"), mean, na.rm = TRUE), .groups = "drop")
  
  # merge
  df_merged <- left_join(df_sum, df_mean,
                         by=c("firmname","tied_year"))
  
  df_merged <- rename_with(df_merged,
                           .fn = ~paste0("p_", .),
                           .cols = matches("dgr|btw|pwr|cons|density"))

  return(df_merged)
}

#' Calculate initial centrality for focal firms
#' Original function from imprinting_Dec18.R (incomplete but preserved)
#' @param edge_raw Edge data
#' @param initial_partner_df Initial partner data
#' @param time_window Time window
#' @param edge_cutpoint Edge cutpoint
#' @return Initial centrality data
VC_initial_centrality <- function(edge_raw, initial_partner_df, time_window=NULL, edge_cutpoint=NULL){
  
  # Original logic from imprinting_Dec18.R
  initial_year_df <- initial_partner_df %>% as_tibble() %>%
    dplyr::select(firmname, initial_year) %>%
    distinct()
  
  edge_raw_initial <- left_join(edge_raw, initial_year_df, by="firmname")
  
  # Note: This function was incomplete in the original code
  # Additional logic would need to be implemented based on research needs
  
  return(edge_raw_initial)
}

#' Create comprehensive imprinting dataset
#' @param initial_partner_list Initial partner data
#' @param centrality_data Centrality measures
#' @param performance_data Performance metrics
#' @param investment_data Investment data
#' @return Complete imprinting dataset
create_imprinting_dataset <- function(initial_partner_list, centrality_data, performance_data, investment_data) {
  
  # Merge all imprinting data
  imprinting_dataset <- initial_partner_list %>%
    left_join(centrality_data, by = c("firmname", "tied_year")) %>%
    left_join(performance_data, by = c("firmname", "year")) %>%
    left_join(investment_data, by = c("firmname", "year")) %>%
    mutate(
      initial_partner_num = n_distinct(initial_partner, na.rm = TRUE),
      timesince = year - initial_year
    )
  
  return(imprinting_dataset)
}

#' Calculate imprinting effect measures
#' @param imprinting_dataset Imprinting dataset
#' @param performance_data Performance data
#' @return Imprinting effect measures
calculate_imprinting_effects <- function(imprinting_dataset, performance_data) {
  
  # Calculate imprinting effect measures
  imprinting_effects <- imprinting_dataset %>%
    group_by(firmname) %>%
    summarise(
      initial_partner_count = n_distinct(initial_partner, na.rm = TRUE),
      avg_partner_degree = mean(p_dgr_1y, na.rm = TRUE),
      avg_partner_betweenness = mean(p_btw_1y, na.rm = TRUE),
      avg_partner_power = mean(p_pwr_max_5y, na.rm = TRUE),
      focal_degree = mean(f_dgr_1y, na.rm = TRUE),
      focal_betweenness = mean(f_btw_1y, na.rm = TRUE),
      focal_power = mean(f_pwr_max_5y, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    left_join(performance_data, by = "firmname")
  
  return(imprinting_effects)
}

#' Create imprinting analysis dataset
#' @param edge_raw Edge data
#' @param centrality_data Centrality data
#' @param initial_year_data Initial year data
#' @param imprinting_period Imprinting period
#' @param time_windows Vector of time windows for centrality
#' @return Complete imprinting analysis dataset
create_imprinting_dataset <- function(edge_raw, centrality_data, initial_year_data, 
                                     imprinting_period = 1, time_windows = c(1, 3, 5)) {
  
  # Get initial ties
  cat("Calculating initial ties...\n")
  initial_ties <- foreach(y = unique(edge_raw$year),
                         .combine = rbind) %dopar% {
    VC_initial_ties(edge_raw, y, imprinting_period)
  }
  
  # Add initial year information
  initial_ties <- left_join(initial_ties, initial_year_data, by = "firmname")
  
  # Filter by imprinting period
  initial_partner_list <- VC_initial_period(initial_ties, imprinting_period)
  
  # Calculate partner centrality for different time windows
  partner_centrality_list <- list()
  focal_centrality_list <- list()
  
  for (tw in time_windows) {
    cat("Processing time window:", tw, "years\n")
    
    # Filter centrality data for time window
    cent_tw <- centrality_data %>% 
      filter(grepl(paste0("_", tw, "y$"), colnames(centrality_data)))
    
    # Calculate partner centrality
    partner_centrality_list[[paste0("_", tw, "y")]] <- 
      VC_initial_partner_centrality(initial_partner_list, cent_tw)
    
    # Calculate focal centrality
    focal_centrality_list[[paste0("_", tw, "y")]] <- 
      VC_initial_focal_centrality(initial_partner_list, cent_tw)
  }
  
  # Combine results
  partner_centrality <- do.call("left_join", partner_centrality_list)
  focal_centrality <- do.call("left_join", focal_centrality_list)
  
  # Merge with initial partner list
  result <- left_join(initial_partner_list, partner_centrality, 
                     by = c("firmname", "tied_year"))
  result <- left_join(result, focal_centrality, 
                     by = c("firmname", "tied_year"))
  
  return(result)
}

#' Calculate imprinting effect measures
#' @param imprinting_data Imprinting analysis dataset
#' @param performance_data Performance data
#' @return Imprinting effect measures
calculate_imprinting_effects <- function(imprinting_data, performance_data) {
  
  # Merge imprinting data with performance data
  analysis_data <- left_join(imprinting_data, performance_data, 
                            by = c("firmname", "year"))
  
  # Calculate imprinting effect measures
  effects <- analysis_data %>%
    group_by(firmname) %>%
    summarise(
      initial_partner_count = n_distinct(initial_partner),
      avg_partner_degree = mean(p_dgr_1y, na.rm = TRUE),
      avg_partner_betweenness = mean(p_btw_1y, na.rm = TRUE),
      avg_partner_power = mean(p_pwr_max_1y, na.rm = TRUE),
      focal_degree = mean(f_dgr_1y, na.rm = TRUE),
      focal_betweenness = mean(f_btw_1y, na.rm = TRUE),
      focal_power = mean(f_pwr_max_1y, na.rm = TRUE),
      .groups = "drop"
    )
  
  return(effects)
} 