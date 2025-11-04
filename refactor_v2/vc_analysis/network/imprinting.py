"""
Initial Network Partner Analysis for Imprinting Research

This module implements functions to identify and analyze initial network partners
for venture capital firms, following Podolny's status theory framework.

Author: Seungjae Hong
Date: 2025-10-18
"""

import pandas as pd
import numpy as np
import networkx as nx
from typing import Dict, List, Optional, Tuple
import logging

logger = logging.getLogger(__name__)


def identify_initial_year(round_df: pd.DataFrame,
                          firm_col: str = 'firmname',
                          year_col: str = 'year') -> pd.DataFrame:
    """
    Identify the first year each firm appears in the network.
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Round data with firm and year information
    firm_col : str
        Column name for firm identifier
    year_col : str
        Column name for year
        
    Returns
    -------
    pd.DataFrame
        DataFrame with columns: [firmname, initial_year]
    """
    initial_year_df = (
        round_df
        .sort_values([firm_col, year_col])
        .groupby(firm_col, as_index=False)
        .first()
        [[firm_col, year_col]]
        .rename(columns={year_col: 'initial_year'})
    )
    
    logger.info(f"Identified initial year for {len(initial_year_df)} firms")
    return initial_year_df


def extract_initial_partners(round_df: pd.DataFrame,
                             networks: Dict[int, nx.Graph],
                             initial_year_df: pd.DataFrame,
                             imprinting_period: int = 3,
                             firm_col: str = 'firmname') -> pd.DataFrame:
    """
    Extract initial network partners for each firm during their imprinting period.
    
    For each firm, identifies all unique partners they connected with during
    their first 3 years (t1 ~ t3) in the network.
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Round data
    networks : Dict[int, nx.Graph]
        Dictionary of year -> network graph
    initial_year_df : pd.DataFrame
        DataFrame with initial_year for each firm
    imprinting_period : int
        Number of years for imprinting period (default: 3)
    firm_col : str
        Column name for firm identifier
        
    Returns
    -------
    pd.DataFrame
        Initial ties with columns:
        - firmname: focal firm
        - initial_partner: partner firm
        - tied_year: year of tie formation
        - initial_year: focal firm's first year
    """
    initial_ties_list = []
    
    # For each firm's initial year
    for _, row in initial_year_df.iterrows():
        firm = row[firm_col]
        t1 = row['initial_year']
        
        # Imprinting period: t1 to t3
        for year_offset in range(imprinting_period):
            year = t1 + year_offset
            
            # Check if network exists for this year
            if year not in networks:
                continue
                
            G = networks[year]
            
            # Check if firm exists in this year's network
            if firm not in G.nodes():
                continue
            
            # Get all neighbors (partners) in this year
            partners = list(G.neighbors(firm))
            
            # Record each partnership
            for partner in partners:
                initial_ties_list.append({
                    firm_col: firm,
                    'initial_partner': partner,
                    'tied_year': year,
                    'initial_year': t1
                })
    
    initial_ties_df = pd.DataFrame(initial_ties_list)
    
    logger.info(f"Extracted {len(initial_ties_df)} initial partnerships")
    logger.info(f"Unique focal firms: {initial_ties_df[firm_col].nunique()}")
    logger.info(f"Unique partners: {initial_ties_df['initial_partner'].nunique()}")
    
    return initial_ties_df


def calculate_partner_centrality_by_year(initial_ties_df: pd.DataFrame,
                                         centrality_df: pd.DataFrame,
                                         firm_col: str = 'firmname') -> pd.DataFrame:
    """
    Merge partner centrality values for each year during imprinting period.
    
    For each initial partner, retrieves their centrality scores at t1, t2, t3.
    
    Parameters
    ----------
    initial_ties_df : pd.DataFrame
        Initial ties data
    centrality_df : pd.DataFrame
        Centrality data with columns: [firmname, year, dgr_cent, btw_cent, ...]
    firm_col : str
        Column name for firm identifier
        
    Returns
    -------
    pd.DataFrame
        Initial ties with partner centrality values merged
    """
    # Merge partner's centrality at tied_year
    result_df = initial_ties_df.merge(
        centrality_df,
        left_on=['initial_partner', 'tied_year'],
        right_on=[firm_col, 'year'],
        how='left',
        suffixes=('', '_partner')
    )
    
    # Rename centrality columns to indicate they are partner's
    cent_cols = [col for col in centrality_df.columns 
                 if col not in [firm_col, 'year']]
    
    rename_dict = {col: f'partner_{col}' for col in cent_cols}
    result_df = result_df.rename(columns=rename_dict)
    
    # Drop duplicate columns from merge
    result_df = result_df.drop(columns=[f'{firm_col}_partner', 'year'], errors='ignore')
    
    logger.info(f"Merged partner centrality for {len(result_df)} partnerships")
    
    return result_df


def compute_initial_partner_status(initial_ties_with_cent: pd.DataFrame,
                                   centrality_measure: str = 'dgr_cent',
                                   firm_col: str = 'firmname') -> pd.DataFrame:
    """
    Compute three options of initial partner status for each focal firm.
    
    Option 1 (Mean): Average of each partner's average centrality
    Option 2 (Max): Maximum of each partner's average centrality (benefit/advantage)
    Option 3 (Min): Minimum of each partner's average centrality (penalty/contamination)
    
    Calculation Logic:
    -----------------
    1. For each focal firm, calculate each partner's average centrality across t1~t3
    2. Mean: Average of these partner-level averages
    3. Max: Maximum of these partner-level averages
    4. Min: Minimum of these partner-level averages
    
    Example:
    --------
    Firm A with partners B, C, D:
    - Partner B: centrality at t1=100, t2=100 → avg=100
    - Partner C: centrality at t1=10, t3=10 → avg=10
    - Partner D: centrality at t2=10 → avg=10
    
    Result:
    - Mean: (100 + 10 + 10) / 3 = 40
    - Max: 100
    - Min: 10
    
    Parameters
    ----------
    initial_ties_with_cent : pd.DataFrame
        Initial ties with partner centrality merged
    centrality_measure : str
        Which centrality measure to use (e.g., 'dgr_cent', 'btw_cent', 'pwr_p75')
    firm_col : str
        Column name for firm identifier
        
    Returns
    -------
    pd.DataFrame
        Focal firm-level data with columns:
        - firmname
        - initial_year
        - n_initial_partners: number of unique partners
        - n_partner_years: number of partner-year observations
        - initial_{measure}_mean: Option 1 (partner-weighted average)
        - initial_{measure}_max: Option 2 (max partner average - benefit)
        - initial_{measure}_min: Option 3 (min partner average - penalty)
    """
    partner_cent_col = f'partner_{centrality_measure}'
    
    # Check if centrality column exists
    if partner_cent_col not in initial_ties_with_cent.columns:
        raise ValueError(f"Column {partner_cent_col} not found. "
                        f"Available columns: {initial_ties_with_cent.columns.tolist()}")
    
    # Step 1: Calculate each partner's average centrality (across t1~t3)
    partner_avg = initial_ties_with_cent.groupby(
        [firm_col, 'initial_year', 'initial_partner']
    )[partner_cent_col].mean().reset_index()
    partner_avg.columns = [firm_col, 'initial_year', 'initial_partner', 'partner_avg_cent']
    
    # Step 2: Calculate focal firm-level statistics from partner averages
    result = partner_avg.groupby([firm_col, 'initial_year']).agg({
        'initial_partner': 'nunique',  # Number of unique partners
        'partner_avg_cent': ['mean', 'max', 'min']  # Three options from partner averages
    }).reset_index()
    
    # Flatten column names
    result.columns = [
        firm_col,
        'initial_year',
        'n_initial_partners',
        f'initial_{centrality_measure}_mean',
        f'initial_{centrality_measure}_max',
        f'initial_{centrality_measure}_min'
    ]
    
    # Add n_partner_years (total observations)
    partner_years = initial_ties_with_cent.groupby([firm_col, 'initial_year']).size().reset_index(name='n_partner_years')
    result = result.merge(partner_years, on=[firm_col, 'initial_year'], how='left')
    
    # Reorder columns
    status_cols = [col for col in result.columns 
                   if col.startswith('initial_') and col not in ['initial_year']]
    cols = [firm_col, 'initial_year', 'n_initial_partners', 'n_partner_years'] + status_cols
    result = result[cols]
    
    logger.info(f"Computed initial partner status for {len(result)} focal firms")
    logger.info(f"Using centrality measure: {centrality_measure}")
    logger.info(f"Calculation: Partner-weighted (each partner's average across years)")
    
    return result


def compute_all_initial_partner_status(initial_ties_with_cent: pd.DataFrame,
                                       centrality_measures: Optional[List[str]] = None,
                                       firm_col: str = 'firmname') -> pd.DataFrame:
    """
    Compute initial partner status for multiple centrality measures.
    
    Parameters
    ----------
    initial_ties_with_cent : pd.DataFrame
        Initial ties with partner centrality merged
    centrality_measures : List[str], optional
        List of centrality measures to compute. If None, uses all available.
    firm_col : str
        Column name for firm identifier
        
    Returns
    -------
    pd.DataFrame
        Focal firm-level data with all status variables
    """
    # Identify available centrality measures
    if centrality_measures is None:
        partner_cols = [col for col in initial_ties_with_cent.columns 
                       if col.startswith('partner_') and 
                       col not in ['partner_firmname', 'partner_year']]
        centrality_measures = [col.replace('partner_', '') for col in partner_cols]
    
    logger.info(f"Computing status for measures: {centrality_measures}")
    
    # Compute for first measure (includes firm info)
    result_df = compute_initial_partner_status(
        initial_ties_with_cent,
        centrality_measures[0],
        firm_col
    )
    
    # Compute for remaining measures and merge
    for measure in centrality_measures[1:]:
        measure_df = compute_initial_partner_status(
            initial_ties_with_cent,
            measure,
            firm_col
        )
        
        # Keep only the status columns (drop firm info and initial_year)
        status_cols = [col for col in measure_df.columns 
                      if col.startswith('initial_') and col != 'initial_year']
        
        result_df = result_df.merge(
            measure_df[[firm_col] + status_cols],
            on=firm_col,
            how='left'
        )
    
    logger.info(f"Final dataset: {len(result_df)} firms, {len(result_df.columns)} columns")
    
    return result_df

