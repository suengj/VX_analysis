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


def calculate_initial_period_variables(initial_year_df: pd.DataFrame,
                                      firm_vars_df: pd.DataFrame,
                                      market_heat_df: pd.DataFrame = None,
                                      new_venture_demand_df: pd.DataFrame = None,
                                      imprinting_period: int = 3,
                                      firm_col: str = 'firmname',
                                      year_col: str = 'year') -> pd.DataFrame:
    """
    Calculate firm-level variables during initial period (t1~t3) for imprinting analysis.
    
    This function aggregates firm-year level variables during the imprinting period
    (initial_year to initial_year + imprinting_period - 1) to create initial_xxx variables.
    
    Variables calculated:
    - initial_early_stage_ratio: Average early stage ratio during t1~t3
    - initial_industry_blau: Average industry diversity (Blau index) during t1~t3
    - initial_inv_num: Total investment count during t1~t3
    - initial_inv_amt: Total investment amount during t1~t3
    - initial_firmage: Firm age at t1 (initial_year)
    - initial_market_heat: Average market heat during t1~t3 (if provided)
    - initial_new_venture_demand: Average new venture demand during t1~t3 (if provided)
    
    Parameters
    ----------
    initial_year_df : pd.DataFrame
        DataFrame with columns: [firmname, initial_year]
    firm_vars_df : pd.DataFrame
        Firm-year level variables (must include: firmname, year, early_stage_ratio,
        industry_blau, inv_num, inv_amt, firmage)
    market_heat_df : pd.DataFrame, optional
        Year-level market heat data (columns: year, market_heat)
    new_venture_demand_df : pd.DataFrame, optional
        Year-level new venture demand data (columns: year, new_venture_demand)
    imprinting_period : int
        Number of years in imprinting period (default: 3, i.e., t1~t3)
    firm_col : str
        Column name for firm identifier
    year_col : str
        Column name for year
        
    Returns
    -------
    pd.DataFrame
        Firm-level data with initial_xxx variables
        Columns: firmname, initial_year, initial_early_stage_ratio, initial_industry_blau,
        initial_inv_num, initial_inv_amt, initial_firmage, initial_market_heat,
        initial_new_venture_demand
    """
    logger.info("=" * 80)
    logger.info("Calculating Initial Period Variables (t1~t3)...")
    logger.info("=" * 80)
    
    result = initial_year_df[[firm_col, 'initial_year']].copy()
    
    # Required firm variables
    required_vars = ['early_stage_ratio', 'industry_blau', 'inv_num', 'inv_amt', 'firmage']
    missing_vars = [v for v in required_vars if v not in firm_vars_df.columns]
    
    if missing_vars:
        logger.warning(f"Missing required variables in firm_vars_df: {missing_vars}")
        logger.warning("Setting corresponding initial_xxx variables to NaN")
    
    # Step 1: Calculate initial period aggregations for each firm (vectorized)
    logger.info(f"\nStep 1: Aggregating firm variables during imprinting period (t1~t3)...")
    
    logger.info(f"  Input data:")
    logger.info(f"    - initial_year_df: {len(initial_year_df)} firms")
    logger.info(f"    - firm_vars_df: {len(firm_vars_df)} firm-year observations")
    logger.info(f"    - firm_vars_df year range: {firm_vars_df[year_col].min():.0f} ~ {firm_vars_df[year_col].max():.0f}")
    
    # Merge initial_year info into firm_vars_df for vectorized filtering
    # Use left join to preserve all firms in initial_year_df
    firm_vars_with_init = firm_vars_df.merge(
        initial_year_df[[firm_col, 'initial_year']],
        on=firm_col,
        how='right'  # Right join to preserve all firms in initial_year_df
    )
    
    logger.info(f"  After merge: {len(firm_vars_with_init)} firm-year observations")
    
    # Filter: year must be in [initial_year, initial_year + imprinting_period - 1]
    firm_vars_with_init['t3'] = firm_vars_with_init['initial_year'] + imprinting_period - 1
    period_mask = (
        (firm_vars_with_init[year_col] >= firm_vars_with_init['initial_year']) &
        (firm_vars_with_init[year_col] <= firm_vars_with_init['t3'])
    )
    period_data = firm_vars_with_init[period_mask].copy()
    
    logger.info(f"  Period data (t1~t3): {len(period_data)} firm-year observations")
    logger.info(f"  Unique firms with period data: {period_data[firm_col].nunique()}")
    
    # Aggregate by firm and initial_year
    agg_dict = {}
    
    # Average for ratios and diversity
    if 'early_stage_ratio' in period_data.columns:
        agg_dict['early_stage_ratio'] = 'mean'
    if 'industry_blau' in period_data.columns:
        agg_dict['industry_blau'] = 'mean'
    
    # Sum for investment counts and amounts
    if 'inv_num' in period_data.columns:
        agg_dict['inv_num'] = 'sum'
    if 'inv_amt' in period_data.columns:
        agg_dict['inv_amt'] = 'sum'
    
    # Group by firm and initial_year
    if agg_dict:
        initial_vars_df = period_data.groupby([firm_col, 'initial_year']).agg(agg_dict).reset_index()
        
        # Rename columns
        rename_dict = {
            'early_stage_ratio': 'initial_early_stage_ratio',
            'industry_blau': 'initial_industry_blau',
            'inv_num': 'initial_inv_num',
            'inv_amt': 'initial_inv_amt'
        }
        initial_vars_df = initial_vars_df.rename(columns=rename_dict)
    else:
        # No matching columns
        initial_vars_df = initial_year_df[[firm_col, 'initial_year']].copy()
        initial_vars_df['initial_early_stage_ratio'] = np.nan
        initial_vars_df['initial_industry_blau'] = np.nan
        initial_vars_df['initial_inv_num'] = 0
        initial_vars_df['initial_inv_amt'] = 0
    
    # Add firmage at t1 (initial_year) - need separate merge
    firmage_at_t1 = firm_vars_df[
        firm_vars_df[year_col].isin(initial_year_df['initial_year'])
    ].merge(
        initial_year_df[[firm_col, 'initial_year']],
        left_on=[firm_col, year_col],
        right_on=[firm_col, 'initial_year'],
        how='inner'
    )
    
    if 'firmage' in firmage_at_t1.columns and len(firmage_at_t1) > 0:
        firmage_df = firmage_at_t1[[firm_col, 'initial_year', 'firmage']].drop_duplicates(subset=[firm_col, 'initial_year'])
        firmage_df = firmage_df.rename(columns={'firmage': 'initial_firmage'})
        initial_vars_df = initial_vars_df.merge(firmage_df, on=[firm_col, 'initial_year'], how='left')
    else:
        initial_vars_df['initial_firmage'] = np.nan
    
    # Fill missing values
    if 'initial_inv_num' in initial_vars_df.columns:
        initial_vars_df['initial_inv_num'] = initial_vars_df['initial_inv_num'].fillna(0)
    if 'initial_inv_amt' in initial_vars_df.columns:
        initial_vars_df['initial_inv_amt'] = initial_vars_df['initial_inv_amt'].fillna(0)
    
    # Merge with result
    result = result.merge(initial_vars_df, on=[firm_col, 'initial_year'], how='left')
    
    logger.info(f"  Calculated initial period variables for {len(result)} firms")
    logger.info(f"  Variables: early_stage_ratio, industry_blau, inv_num, inv_amt, firmage")
    
    # Step 2: Add market-level variables (if provided) - vectorized
    if market_heat_df is not None and 'market_heat' in market_heat_df.columns:
        logger.info(f"\nStep 2: Adding initial_market_heat (vectorized)...")
        logger.info(f"  market_heat_df: {len(market_heat_df)} year observations")
        logger.info(f"  market_heat_df year range: {market_heat_df[year_col].min():.0f} ~ {market_heat_df[year_col].max():.0f}")
        
        # Expand initial_year_df to include all years in imprinting period
        init_expanded = initial_year_df.copy()
        init_expanded['t3'] = init_expanded['initial_year'] + imprinting_period - 1
        
        # Create year range for each firm
        expanded_list = []
        for _, row in init_expanded.iterrows():
            t1 = int(row['initial_year'])
            t3 = int(row['t3'])
            for year in range(t1, t3 + 1):
                expanded_list.append({
                    firm_col: row[firm_col],
                    'initial_year': t1,
                    year_col: year
                })
        
        expanded_df = pd.DataFrame(expanded_list)
        logger.info(f"  Expanded to {len(expanded_df)} firm-year observations")
        
        # Merge with market heat
        expanded_with_heat = expanded_df.merge(
            market_heat_df[[year_col, 'market_heat']],
            on=year_col,
            how='left'
        )
        
        logger.info(f"  After merge: {len(expanded_with_heat)} observations")
        logger.info(f"  Non-null market_heat: {expanded_with_heat['market_heat'].notna().sum()}")
        
        # Aggregate by firm and initial_year
        market_heat_period_df = expanded_with_heat.groupby([firm_col, 'initial_year'])['market_heat'].mean().reset_index()
        market_heat_period_df = market_heat_period_df.rename(columns={'market_heat': 'initial_market_heat'})
        
        logger.info(f"  Aggregated to {len(market_heat_period_df)} firms")
        logger.info(f"  Non-null initial_market_heat: {market_heat_period_df['initial_market_heat'].notna().sum()}")
        
        result = result.merge(market_heat_period_df, on=[firm_col, 'initial_year'], how='left')
        logger.info(f"  Added initial_market_heat for {len(result)} firms")
    else:
        logger.info(f"\nStep 2: Skipping initial_market_heat (not provided)")
        logger.info(f"  market_heat_df is None: {market_heat_df is None}")
        if market_heat_df is not None:
            logger.info(f"  market_heat_df columns: {market_heat_df.columns.tolist()}")
        result['initial_market_heat'] = np.nan
    
    # Step 3: Add new venture demand (if provided) - vectorized
    if new_venture_demand_df is not None and 'new_venture_demand' in new_venture_demand_df.columns:
        logger.info(f"\nStep 3: Adding initial_new_venture_demand (vectorized)...")
        logger.info(f"  new_venture_demand_df: {len(new_venture_demand_df)} year observations")
        logger.info(f"  new_venture_demand_df year range: {new_venture_demand_df[year_col].min():.0f} ~ {new_venture_demand_df[year_col].max():.0f}")
        
        # Expand initial_year_df to include all years in imprinting period
        init_expanded = initial_year_df.copy()
        init_expanded['t3'] = init_expanded['initial_year'] + imprinting_period - 1
        
        # Create year range for each firm
        expanded_list = []
        for _, row in init_expanded.iterrows():
            t1 = int(row['initial_year'])
            t3 = int(row['t3'])
            for year in range(t1, t3 + 1):
                expanded_list.append({
                    firm_col: row[firm_col],
                    'initial_year': t1,
                    year_col: year
                })
        
        expanded_df = pd.DataFrame(expanded_list)
        logger.info(f"  Expanded to {len(expanded_df)} firm-year observations")
        
        # Merge with new venture demand
        expanded_with_demand = expanded_df.merge(
            new_venture_demand_df[[year_col, 'new_venture_demand']],
            on=year_col,
            how='left'
        )
        
        logger.info(f"  After merge: {len(expanded_with_demand)} observations")
        logger.info(f"  Non-null new_venture_demand: {expanded_with_demand['new_venture_demand'].notna().sum()}")
        
        # Aggregate by firm and initial_year
        demand_period_df = expanded_with_demand.groupby([firm_col, 'initial_year'])['new_venture_demand'].mean().reset_index()
        demand_period_df = demand_period_df.rename(columns={'new_venture_demand': 'initial_new_venture_demand'})
        
        logger.info(f"  Aggregated to {len(demand_period_df)} firms")
        logger.info(f"  Non-null initial_new_venture_demand: {demand_period_df['initial_new_venture_demand'].notna().sum()}")
        
        result = result.merge(demand_period_df, on=[firm_col, 'initial_year'], how='left')
        logger.info(f"  Added initial_new_venture_demand for {len(result)} firms")
    else:
        logger.info(f"\nStep 3: Skipping initial_new_venture_demand (not provided)")
        logger.info(f"  new_venture_demand_df is None: {new_venture_demand_df is None}")
        if new_venture_demand_df is not None:
            logger.info(f"  new_venture_demand_df columns: {new_venture_demand_df.columns.tolist()}")
        result['initial_new_venture_demand'] = np.nan
    
    # Summary statistics
    logger.info("=" * 80)
    logger.info("✅ Initial Period Variables Calculated!")
    logger.info(f"   - Firms: {len(result)}")
    logger.info(f"   - Variables: {len([c for c in result.columns if c.startswith('initial_')])} initial_xxx variables")
    
    # Log non-null counts
    for col in result.columns:
        if col.startswith('initial_') and col != 'initial_year':
            non_null = result[col].notna().sum()
            logger.info(f"   - {col}: {non_null:,} non-null ({non_null/len(result)*100:.1f}%)")
    
    logger.info("=" * 80)
    
    return result


def calculate_initial_period_geographic_distances(initial_year_df: pd.DataFrame,
                                                  copartner_dist_df: pd.DataFrame,
                                                  imprinting_period: int = 3,
                                                  firm_col: str = 'firmname',
                                                  year_col: str = 'year') -> pd.DataFrame:
    """
    Calculate initial period (t1~t3) geographic distances to co-investment partners
    
    Aggregates co-partner distance variables during the imprinting period.
    
    Parameters
    ----------
    initial_year_df : pd.DataFrame
        DataFrame with columns: [firmname, initial_year]
    copartner_dist_df : pd.DataFrame
        Firm-year level co-partner distance data (from calculate_vc_copartner_distances)
    imprinting_period : int
        Number of years in imprinting period (default: 3, i.e., t1~t3)
    firm_col : str
        Column name for firm identifier
    year_col : str
        Column name for year
        
    Returns
    -------
    pd.DataFrame
        Firm-level data with initial_xxx geographic distance variables
        Columns: firmname, initial_year, initial_geo_dist_copartner_mean,
        initial_geo_dist_copartner_min, initial_geo_dist_copartner_max,
        initial_geo_dist_copartner_median, initial_geo_dist_copartner_weighted_mean,
        initial_geo_dist_copartner_std
    """
    logger.info("=" * 80)
    logger.info("Calculating Initial Period Co-Partner Geographic Distances (t1~t3)...")
    logger.info("=" * 80)
    
    result = initial_year_df[[firm_col, 'initial_year']].copy()
    
    # Distance columns to aggregate (excluding median)
    dist_cols = [col for col in copartner_dist_df.columns 
                if col.startswith('geo_dist_copartner') and 
                col not in [firm_col, year_col] and 
                'median' not in col]
    
    if not dist_cols:
        logger.warning("No co-partner distance columns found in copartner_dist_df")
        for col in ['geo_dist_copartner_mean', 'geo_dist_copartner_min', 'geo_dist_copartner_max',
                   'geo_dist_copartner_weighted_mean', 'geo_dist_copartner_std']:
            result[f'initial_{col}'] = np.nan
        return result
    
    logger.info(f"  Aggregating {len(dist_cols)} distance variables during imprinting period")
    
    # Aggregate distances for each firm during t1~t3 (vectorized)
    logger.info("  Aggregating distances (vectorized)...")
    
    logger.info(f"  Input data:")
    logger.info(f"    - initial_year_df: {len(initial_year_df)} firms")
    logger.info(f"    - copartner_dist_df: {len(copartner_dist_df)} firm-year observations")
    if len(copartner_dist_df) > 0:
        logger.info(f"    - copartner_dist_df year range: {copartner_dist_df[year_col].min():.0f} ~ {copartner_dist_df[year_col].max():.0f}")
    
    # Merge initial_year info into copartner_dist_df for vectorized filtering
    # Use right join to preserve all firms in initial_year_df
    copartner_with_init = copartner_dist_df.merge(
        initial_year_df[[firm_col, 'initial_year']],
        on=firm_col,
        how='right'  # Right join to preserve all firms in initial_year_df
    )
    
    logger.info(f"  After merge: {len(copartner_with_init)} firm-year observations")
    
    # Filter: year must be in [initial_year, initial_year + imprinting_period - 1]
    copartner_with_init['t3'] = copartner_with_init['initial_year'] + imprinting_period - 1
    period_mask = (
        (copartner_with_init[year_col] >= copartner_with_init['initial_year']) &
        (copartner_with_init[year_col] <= copartner_with_init['t3'])
    )
    period_data = copartner_with_init[period_mask].copy()
    
    logger.info(f"  Period data (t1~t3): {len(period_data)} firm-year observations")
    logger.info(f"  Unique firms with period data: {period_data[firm_col].nunique()}")
    
    # Aggregate by firm and initial_year (mean for all distance statistics)
    if len(period_data) > 0 and dist_cols:
        agg_dict = {col: 'mean' for col in dist_cols if col in period_data.columns}
        
        if agg_dict:
            initial_dist_df = period_data.groupby([firm_col, 'initial_year']).agg(agg_dict).reset_index()
            
            # Rename columns
            rename_dict = {col: f'initial_{col}' for col in dist_cols if col in initial_dist_df.columns}
            initial_dist_df = initial_dist_df.rename(columns=rename_dict)
        else:
            # No matching columns
            initial_dist_df = initial_year_df[[firm_col, 'initial_year']].copy()
            for col in dist_cols:
                initial_dist_df[f'initial_{col}'] = np.nan
    else:
        # No data in imprinting period
        initial_dist_df = initial_year_df[[firm_col, 'initial_year']].copy()
        for col in dist_cols:
            initial_dist_df[f'initial_{col}'] = np.nan
    
    # Merge with result
    result = result.merge(initial_dist_df, on=[firm_col, 'initial_year'], how='left')
    
    logger.info(f"✅ Calculated initial period distances for {len(result)} firms")
    logger.info(f"   Variables: {len([c for c in result.columns if c.startswith('initial_geo_dist_copartner')])} initial_xxx variables")
    
    # Log non-null counts
    for col in result.columns:
        if col.startswith('initial_geo_dist_copartner'):
            non_null = result[col].notna().sum()
            logger.info(f"   - {col}: {non_null:,} non-null ({non_null/len(result)*100:.1f}%)")
    
    logger.info("=" * 80)
    
    return result

