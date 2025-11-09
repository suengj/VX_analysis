"""
VC Firm-level variables calculation

This module calculates various firm-level characteristics including:
- Firm age (year - founding year)
- Investment diversity (Blau index by industry)
- Performance metrics (all exits, IPO, M&A)
- Early stage participation ratio
- Firm HQ location (CA, MA, NY dummies)
- Total investment amount (by year)
- Total investment number (by year)
- VC Reputation index (6-component index with z-score standardization)
- Market Heat (industry-level, relative VC fund raising activity)
- New Venture Funding Demand (industry-level, current year, NOT lagged)
"""

import pandas as pd
import numpy as np
from typing import Dict, List, Optional
import logging

from ..config import constants

logger = logging.getLogger(__name__)


def fill_missing_performance_with_zero(df: pd.DataFrame,
                                       columns: Optional[List[str]] = None,
                                       inplace: bool = False) -> pd.DataFrame:
    """
    Fill missing performance columns (perf_*) with zeros.

    Parameters
    ----------
    df : pd.DataFrame
        DataFrame containing performance columns
    columns : Optional[List[str]]
        Columns to fill. If None, auto-detect ['perf_IPO','perf_MnA','perf_all'] when present.
    inplace : bool
        If True, modify df in place; otherwise return a filled copy

    Returns
    -------
    pd.DataFrame
        DataFrame with selected performance columns filled with 0
    """
    if df is None or df.empty:
        return df

    if columns is None:
        candidate_cols = ['perf_IPO', 'perf_MnA', 'perf_all']
        columns = [c for c in candidate_cols if c in df.columns]

    if not columns:
        return df

    target = df if inplace else df.copy()
    target[columns] = target[columns].fillna(0)

    # Optionally cast to integer if values are integral
    for c in columns:
        if c in target.columns:
            try:
                # Preserve float if non-integer values exist
                if (target[c] % 1 == 0).all():
                    target[c] = target[c].astype(int)
            except Exception:
                # Ignore casting issues and keep original dtype
                pass

    return target

def calculate_firm_age(firm_df: pd.DataFrame, 
                       round_df: pd.DataFrame,
                       founding_col: str = 'firmfounding',
                       year_col: str = 'year') -> pd.DataFrame:
    """
    Calculate firm age for each firm-year
    
    Parameters
    ----------
    firm_df : pd.DataFrame
        Firm data with founding dates
    round_df : pd.DataFrame
        Round data with years
    founding_col : str
        Column name for firm founding date
    year_col : str
        Column name for year
    
    Returns
    -------
    pd.DataFrame
        Firm-year data with firmage column
    """
    logger.info("Calculating firm age...")
    
    # Get unique firm-year combinations
    firm_years = round_df[['firmname', year_col]].drop_duplicates()
    
    # Merge founding dates
    firm_years = firm_years.merge(
        firm_df[['firmname', founding_col]].drop_duplicates(subset=['firmname']),
        on='firmname',
        how='left'
    )
    
    # Calculate age
    if founding_col in firm_years.columns:
        # Extract founding year
        firm_years['founding_year'] = pd.to_datetime(firm_years[founding_col], errors='coerce').dt.year
        firm_years['firmage'] = firm_years[year_col] - firm_years['founding_year']
        
        # Handle negative ages (set to 0)
        firm_years.loc[firm_years['firmage'] < 0, 'firmage'] = 0
        
        # Drop intermediate columns
        firm_years = firm_years.drop(columns=[founding_col, 'founding_year'])
        
        logger.info(f"Calculated firm age for {len(firm_years)} firm-years")
        logger.info(f"  Age range: {firm_years['firmage'].min():.0f} - {firm_years['firmage'].max():.0f} years")
    else:
        logger.warning(f"Column '{founding_col}' not found")
        firm_years['firmage'] = np.nan
    
    return firm_years


def calculate_investment_diversity(round_df: pd.DataFrame,
                                   company_df: pd.DataFrame,
                                   industry_col: str = None,
                                   year_col: str = 'year') -> pd.DataFrame:
    """
    Calculate investment diversity (Blau index) by industry for each firm-year
    
    Blau Index = 1 - Σ(p_i^2)
    where p_i = proportion of investments in industry i
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Round data
    company_df : pd.DataFrame
        Company data with industry information
    industry_col : str
        Column name for industry
    year_col : str
        Column name for year
    
    Returns
    -------
    pd.DataFrame
        Firm-year data with industry_blau column
    """
    logger.info("Calculating investment diversity (Blau index)...")
    
    # Auto-detect industry column if not provided
    if industry_col is None:
        industry_col = constants.DIVERSITY_SETTINGS['industry_column']
        logger.info(f"  Using industry column from constants: '{industry_col}'")
    
    # Check if industry column exists
    if industry_col not in company_df.columns:
        logger.warning(f"Industry column '{industry_col}' not found in company_df")
        logger.warning("Setting industry_blau to NaN")
        firm_years = round_df[['firmname', year_col]].drop_duplicates()
        firm_years['industry_blau'] = np.nan
        return firm_years
    
    # Merge industry information
    round_with_industry = round_df.merge(
        company_df[['comname', industry_col]].drop_duplicates(subset=['comname']),
        on='comname',
        how='left'
    )
    
    # Calculate Blau index for each firm-year
    def blau_index(industries):
        """Calculate Blau index for a list of industries"""
        if len(industries) == 0:
            return 0.0
        
        # Remove nulls
        industries = [i for i in industries if pd.notna(i)]
        if len(industries) == 0:
            return 0.0
        
        # Calculate proportions
        counts = pd.Series(industries).value_counts()
        proportions = counts / counts.sum()
        
        # Blau = 1 - Σ(p^2)
        return 1 - (proportions ** 2).sum()
    
    diversity = round_with_industry.groupby(['firmname', year_col])[industry_col].apply(blau_index).reset_index()
    diversity.columns = ['firmname', year_col, 'industry_blau']
    
    logger.info(f"Calculated diversity for {len(diversity)} firm-years")
    logger.info(f"  Blau range: {diversity['industry_blau'].min():.3f} - {diversity['industry_blau'].max():.3f}")
    
    return diversity


def calculate_performance_metrics(round_df: pd.DataFrame,
                                  company_df: pd.DataFrame,
                                  year_col: str = 'year',
                                  lookback_years: int = None) -> pd.DataFrame:
    """
    Calculate CUMULATIVE performance metrics for each firm-year
    
    Based on original R code: VC_exit_num, VC_IPO_num, VC_MnA_num functions
    - Calculates exits in PAST lookback_years (default: 5 years)
    - For year Y, counts exits from investments made in [Y-lookback_years, Y)
    - Matches round year with exit year (situ_yr)
    
    Logic:
    1. Create exit indicators from comsitu + dates
    2. Extract exit year (situ_yr) from date_sit or date_ipo
    3. For each firm-year, count exits from past investments
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Round data with investment year
    company_df : pd.DataFrame
        Company data with comsitu, date_sit, date_ipo
    year_col : str
        Column name for year
    lookback_years : int, optional
        Number of years to look back (default: from constants, usually 5)
    
    Returns
    -------
    pd.DataFrame
        Firm-year data with CUMULATIVE performance columns
    """
    logger.info("Calculating CUMULATIVE performance metrics...")
    
    # Get settings from constants
    settings = constants.PERFORMANCE_SETTINGS
    if lookback_years is None:
        lookback_years = settings['lookback_years']
    
    logger.info(f"  Lookback period: {lookback_years} years")
    
    situ_col = settings['situation_column']
    date_sit_col = settings['situation_date_column']
    date_ipo_col = settings['ipo_date_column']
    
    # Check required columns
    required_cols = ['comname', situ_col, date_sit_col, date_ipo_col]
    missing_cols = [col for col in required_cols if col not in company_df.columns]
    
    if missing_cols:
        logger.warning(f"Missing columns in company_df: {missing_cols}")
        logger.warning("Setting all performance metrics to 0")
        firm_years = round_df[['firmname', year_col]].drop_duplicates()
        firm_years['perf_IPO'] = 0
        firm_years['perf_MnA'] = 0
        firm_years['perf_all'] = 0
        return firm_years
    
    # Step 1: Create exit indicators
    company_exits = company_df[required_cols].copy()
    
    # IPO Exit: comsitu = "Went Public" AND (date_sit != "" OR date_ipo != "")
    company_exits['ipoExit'] = (
        (company_exits[situ_col].isin(settings['ipo_values'])) &
        ((company_exits[date_sit_col].notna() & (company_exits[date_sit_col] != '')) |
         (company_exits[date_ipo_col].notna() & (company_exits[date_ipo_col] != '')))
    ).astype(int)
    
    # M&A Exit: comsitu IN ("Merger", "Acquisition") AND date_sit != ""
    company_exits['MnAExit'] = (
        (company_exits[situ_col].isin(settings['mna_values'])) &
        (company_exits[date_sit_col].notna()) &
        (company_exits[date_sit_col] != '')
    ).astype(int)
    
    # All exits
    company_exits['exit'] = company_exits['ipoExit'] + company_exits['MnAExit']
    
    # Step 2: Extract exit year (situ_yr) from dates
    # Priority: date_ipo for IPO, date_sit for M&A and general
    def extract_year_from_date(date_str):
        """Extract year from date string, handling various formats"""
        if pd.isna(date_str) or date_str == '':
            return np.nan
        try:
            # Try parsing as datetime
            date_obj = pd.to_datetime(date_str, errors='coerce')
            if pd.notna(date_obj):
                return date_obj.year
        except:
            pass
        return np.nan
    
    # For IPO: use date_ipo if available, else date_sit
    company_exits['situ_yr'] = company_exits.apply(
        lambda row: (
            extract_year_from_date(row[date_ipo_col]) 
            if row['ipoExit'] == 1 and pd.notna(row[date_ipo_col]) and row[date_ipo_col] != ''
            else extract_year_from_date(row[date_sit_col])
        ),
        axis=1
    )
    
    # Step 3: Merge round data with exit data
    # Join on comname AND match investment year with exit year
    round_with_exits = round_df[['firmname', 'comname', year_col]].merge(
        company_exits[['comname', 'situ_yr', 'ipoExit', 'MnAExit', 'exit']],
        on='comname',
        how='left'
    )
    
    # Fill NaN exits with 0
    round_with_exits['ipoExit'] = round_with_exits['ipoExit'].fillna(0)
    round_with_exits['MnAExit'] = round_with_exits['MnAExit'].fillna(0)
    round_with_exits['exit'] = round_with_exits['exit'].fillna(0)
    round_with_exits['situ_yr'] = round_with_exits['situ_yr'].fillna(0).astype(int)
    
    # Step 4: Calculate CUMULATIVE performance for each firm-year
    # For each target year (v_yr), count exits from investments in specified period
    all_years = sorted(round_with_exits[year_col].unique())
    performance_list = []
    
    for target_year in all_years:
        # Filter: investments made in lookback period
        # If lookback_years=0: only current year (year == target_year)
        # If lookback_years>0: [target_year - lookback_years, target_year)
        if lookback_years == 0:
            # Current year only
            investments = round_with_exits[
                round_with_exits[year_col] == target_year
            ].copy()
        else:
            # Past N years (excluding current year)
            lookback_start = target_year - lookback_years
            investments = round_with_exits[
                (round_with_exits[year_col] >= lookback_start) &
                (round_with_exits[year_col] < target_year)
            ].copy()
        
        # Match with exit year: only count exits that happened (situ_yr matches investment year)
        # Following R code: left_join by comname AND year=situ_yr
        investments_with_exits = investments[
            investments['situ_yr'] == investments[year_col]
        ]
        
        # Aggregate by firm
        if len(investments_with_exits) > 0:
            firm_perf = investments_with_exits.groupby('firmname').agg({
                'ipoExit': 'sum',
                'MnAExit': 'sum',
                'exit': 'sum'
            }).reset_index()
            
            firm_perf[year_col] = target_year
            performance_list.append(firm_perf)
    
    # Combine all years
    if performance_list:
        performance = pd.concat(performance_list, ignore_index=True)
        performance.columns = ['firmname', 'perf_IPO', 'perf_MnA', 'perf_all', year_col]
        performance = performance[['firmname', year_col, 'perf_IPO', 'perf_MnA', 'perf_all']]
    else:
        # No data
        firm_years = round_df[['firmname', year_col]].drop_duplicates()
        firm_years['perf_IPO'] = 0
        firm_years['perf_MnA'] = 0
        firm_years['perf_all'] = 0
        performance = firm_years
    
    logger.info(f"Calculated CUMULATIVE performance for {len(performance)} firm-years")
    logger.info(f"  Total exits: {performance['perf_all'].sum():.0f}")
    logger.info(f"  IPO exits: {performance['perf_IPO'].sum():.0f}")
    logger.info(f"  M&A exits: {performance['perf_MnA'].sum():.0f}")
    
    return performance


def calculate_early_stage_ratio(round_df: pd.DataFrame,
                                year_col: str = 'year',
                                stage_col: str = None) -> pd.DataFrame:
    """
    Calculate early stage participation ratio for each firm-year
    
    Based on original R code: CVC_preprcs_v4.R
    - Primary column: CompanyStageLevel1 (values: 'Startup/Seed', 'Early Stage')
    - Fallback columns: rndstage, stage
    
    Ratio = mean(is_early_stage) per firm-year
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Round data with stage information
    year_col : str
        Column name for year
    stage_col : str, optional
        Column name for round stage. If None, auto-detect from available columns
    
    Returns
    -------
    pd.DataFrame
        Firm-year data with early_stage_ratio column
    """
    logger.info("Calculating early stage participation ratio...")
    
    # Auto-detect stage column if not provided
    if stage_col is None:
        stage_columns = constants.EARLY_STAGE_DEFINITIONS.get('stage_columns', [])
        for col in stage_columns:
            if col in round_df.columns:
                stage_col = col
                logger.info(f"  Auto-detected stage column: '{stage_col}'")
                break
    
    if stage_col is None or stage_col not in round_df.columns:
        tried_cols = constants.EARLY_STAGE_DEFINITIONS.get('stage_columns', [])
        logger.warning(f"No valid stage column found. Tried: {tried_cols}")
        logger.warning("Setting early_stage_ratio to NaN")
        firm_years = round_df[['firmname', year_col]].drop_duplicates()
        firm_years['early_stage_ratio'] = np.nan
        return firm_years
    
    # Get early stage definitions
    early_stages = constants.EARLY_STAGE_DEFINITIONS.get('early_stage_values', [])
    logger.info(f"  Using stage column: '{stage_col}'")
    logger.info(f"  Early stage values: {early_stages}")
    
    # Mark early stage investments
    round_df_copy = round_df.copy()
    round_df_copy['is_early'] = round_df_copy[stage_col].isin(early_stages).astype(int)
    
    # Calculate ratio for each firm-year (using mean as in original R code)
    early_ratio = round_df_copy.groupby(['firmname', year_col]).agg({
        'is_early': 'mean'  # mean(earlyStageCnt) in original R code
    }).reset_index()
    
    early_ratio.columns = ['firmname', year_col, 'early_stage_ratio']
    
    logger.info(f"Calculated early stage ratio for {len(early_ratio)} firm-years")
    logger.info(f"  Ratio range: {early_ratio['early_stage_ratio'].min():.3f} - {early_ratio['early_stage_ratio'].max():.3f}")
    logger.info(f"  Mean ratio: {early_ratio['early_stage_ratio'].mean():.3f}")
    
    return early_ratio


def calculate_firm_hq_dummy(firm_df: pd.DataFrame,
                            state_col: str = 'firmstate') -> pd.DataFrame:
    """
    Calculate firm HQ dummy variables (CA, MA, NY, and combined CA/MA)
    
    Major VC hubs:
    - Silicon Valley (CA)
    - Boston/Cambridge (MA)
    - New York (NY)
    
    Parameters
    ----------
    firm_df : pd.DataFrame
        Firm data with state information
    state_col : str
        Column name for firm state
    
    Returns
    -------
    pd.DataFrame
        Firm data with firm_hq, firm_hq_CA, firm_hq_MA, firm_hq_NY columns
    """
    logger.info("Calculating firm HQ dummy variables (CA/MA/NY)...")
    
    firm_hq = firm_df[['firmname']].drop_duplicates()
    
    if state_col in firm_df.columns:
        firm_hq = firm_hq.merge(
            firm_df[['firmname', state_col]].drop_duplicates(subset=['firmname']),
            on='firmname',
            how='left'
        )
        
        # Get high-value states from constants (CA, MA)
        high_value_states = (
            constants.FIRM_HQ_HIGH_VALUE_STATES['state_codes'] + 
            constants.FIRM_HQ_HIGH_VALUE_STATES['state_names']
        )
        
        # Define state mappings (codes and names)
        ca_states = ['CA', 'California']
        ma_states = ['MA', 'Massachusetts']
        ny_states = ['NY', 'New York']
        
        logger.info(f"  High-value states (CA/MA): {high_value_states}")
        logger.info(f"  Additional state (NY): {ny_states}")
        
        # Create individual state dummies
        firm_hq['firm_hq_CA'] = firm_hq[state_col].isin(ca_states).astype(int)
        firm_hq['firm_hq_MA'] = firm_hq[state_col].isin(ma_states).astype(int)
        firm_hq['firm_hq_NY'] = firm_hq[state_col].isin(ny_states).astype(int)
        
        # Create combined dummy (1 if CA or MA, 0 otherwise) - keep for backward compatibility
        firm_hq['firm_hq'] = firm_hq[state_col].isin(high_value_states).astype(int)
        
        # Drop state column
        firm_hq = firm_hq.drop(columns=[state_col])
        
        logger.info(f"Calculated HQ dummies for {len(firm_hq)} firms")
        logger.info(f"  CA firms: {firm_hq['firm_hq_CA'].sum():.0f} ({firm_hq['firm_hq_CA'].mean()*100:.1f}%)")
        logger.info(f"  MA firms: {firm_hq['firm_hq_MA'].sum():.0f} ({firm_hq['firm_hq_MA'].mean()*100:.1f}%)")
        logger.info(f"  NY firms: {firm_hq['firm_hq_NY'].sum():.0f} ({firm_hq['firm_hq_NY'].mean()*100:.1f}%)")
        logger.info(f"  CA/MA firms (combined): {firm_hq['firm_hq'].sum():.0f} ({firm_hq['firm_hq'].mean()*100:.1f}%)")
    else:
        logger.warning(f"Column '{state_col}' not found. Setting all HQ dummies to NaN")
        firm_hq['firm_hq'] = np.nan
        firm_hq['firm_hq_CA'] = np.nan
        firm_hq['firm_hq_MA'] = np.nan
        firm_hq['firm_hq_NY'] = np.nan
    
    return firm_hq


def calculate_investment_amount(round_df: pd.DataFrame,
                                year_col: str = 'year',
                                amount_col: str = None) -> pd.DataFrame:
    """
    Calculate total investment amount for each firm-year
    
    Tries columns in order of preference (from constants):
    1. RoundAmountDisclosedThou (primary)
    2. RoundAmountEstimatedThou (if disclosed not available)
    3. RoundAmount (fallback)
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Round data with investment amounts
    year_col : str
        Column name for year
    amount_col : str, optional
        Column name for investment amount. If None, auto-detect from constants
    
    Returns
    -------
    pd.DataFrame
        Firm-year data with inv_amt column
    """
    logger.info("Calculating total investment amount...")
    
    # Auto-detect amount column if not provided
    if amount_col is None:
        for col in constants.INVESTMENT_AMOUNT_COLUMNS:
            if col in round_df.columns:
                amount_col = col
                logger.info(f"  Auto-detected amount column: '{amount_col}'")
                break
    
    if amount_col is None or amount_col not in round_df.columns:
        logger.warning(f"No valid amount column found. Tried: {constants.INVESTMENT_AMOUNT_COLUMNS}")
        logger.warning("Setting inv_amt to NaN")
        firm_years = round_df[['firmname', year_col]].drop_duplicates()
        firm_years['inv_amt'] = np.nan
        return firm_years
    
    # Aggregate by firm-year
    inv_amt = round_df.groupby(['firmname', year_col])[amount_col].sum().reset_index()
    inv_amt.columns = ['firmname', year_col, 'inv_amt']
    
    logger.info(f"Calculated investment amount for {len(inv_amt)} firm-years")
    logger.info(f"  Total amount: ${inv_amt['inv_amt'].sum()/1000:.1f}M")
    logger.info(f"  Mean per firm-year: ${inv_amt['inv_amt'].mean():.0f}K")
    
    return inv_amt


def calculate_investment_number(round_df: pd.DataFrame,
                                year_col: str = 'year') -> pd.DataFrame:
    """
    Calculate total investment number for each firm-year
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Round data
    year_col : str
        Column name for year
    
    Returns
    -------
    pd.DataFrame
        Firm-year data with inv_num column
    """
    logger.info("Calculating total investment number...")
    
    # Count investments by firm-year
    inv_num = round_df.groupby(['firmname', year_col]).size().reset_index(name='inv_num')
    
    logger.info(f"Calculated investment number for {len(inv_num)} firm-years")
    logger.info(f"  Total investments: {inv_num['inv_num'].sum():.0f}")
    logger.info(f"  Mean per firm-year: {inv_num['inv_num'].mean():.1f}")
    
    return inv_num


def calculate_all_firm_variables(round_df: pd.DataFrame,
                                 company_df: pd.DataFrame,
                                 firm_df: pd.DataFrame,
                                 year_col: str = 'year') -> pd.DataFrame:
    """
    Calculate all firm-level variables at once
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Round data
    company_df : pd.DataFrame
        Company data
    firm_df : pd.DataFrame
        Firm data
    year_col : str
        Column name for year
    
    Returns
    -------
    pd.DataFrame
        Comprehensive firm-year data with all variables
    """
    logger.info("=" * 80)
    logger.info("Calculating ALL firm-level variables...")
    logger.info("=" * 80)
    
    # 1. Firm age (firm-year level)
    firm_age = calculate_firm_age(firm_df, round_df, year_col=year_col)
    
    # 2. Investment diversity (firm-year level)
    diversity = calculate_investment_diversity(round_df, company_df, year_col=year_col)
    
    # 3. Performance metrics (firm-year level)
    performance = calculate_performance_metrics(round_df, company_df, year_col=year_col)
    
    # 4. Early stage ratio (firm-year level)
    early_ratio = calculate_early_stage_ratio(round_df, year_col=year_col)
    
    # 5. Firm HQ dummy (firm level - will be merged to all years)
    firm_hq = calculate_firm_hq_dummy(firm_df)
    
    # 6. Investment amount (firm-year level)
    inv_amt = calculate_investment_amount(round_df, year_col=year_col)
    
    # 7. Investment number (firm-year level)
    inv_num = calculate_investment_number(round_df, year_col=year_col)
    
    # Merge all variables
    logger.info("Merging all variables...")
    
    result = firm_age.copy()
    
    for df in [diversity, performance, early_ratio, inv_amt, inv_num]:
        result = result.merge(df, on=['firmname', year_col], how='left')
    
    # Merge firm HQ (firm-level, no year)
    result = result.merge(firm_hq, on='firmname', how='left')
    
    logger.info("=" * 80)
    logger.info(f"✅ ALL firm variables calculated!")
    logger.info(f"   - Firm-years: {len(result)}")
    logger.info(f"   - Unique firms: {result['firmname'].nunique()}")
    logger.info(f"   - Year range: {result[year_col].min()} - {result[year_col].max()}")
    logger.info(f"   - Variables: {len(result.columns)}")
    logger.info("=" * 80)
    
    # Print summary statistics
    logger.info("\n📊 Summary Statistics:")
    for col in result.columns:
        if col not in ['firmname', year_col]:
            if result[col].dtype in ['float64', 'int64']:
                logger.info(f"   {col}: mean={result[col].mean():.2f}, std={result[col].std():.2f}, "
                           f"min={result[col].min():.2f}, max={result[col].max():.2f}")
    
    return result


# ============================================================================
# VC Reputation Calculation Functions
# ============================================================================

def calculate_portfolio_count_rolling(round_df: pd.DataFrame,
                                     year_col: str = 'year',
                                     window_years: int = 5) -> pd.DataFrame:
    """
    Calculate total number of portfolio companies invested in (5-year rolling window)
    
    Variable 1: Total number of portfolio companies a VC invested in
    - Definition: Given year [t-4, t] period, unique comname count per firmname
    - Rolling window: [t-4, t] inclusive
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Round data with firmname, comname, year
    year_col : str
        Column name for year
    window_years : int
        Rolling window size (default: 5 years)
    
    Returns
    -------
    pd.DataFrame
        Firm-year data with rep_portfolio_count column
    """
    logger.info(f"Calculating portfolio count (rolling {window_years}-year window)...")
    
    # Get all unique firm-year combinations
    all_years = sorted(round_df[year_col].unique())
    firm_years = round_df[['firmname', year_col]].drop_duplicates()
    
    result_list = []
    
    for target_year in all_years:
        # Filter: [t-4, t] inclusive
        window_start = target_year - (window_years - 1)
        window_data = round_df[
            (round_df[year_col] >= window_start) & 
            (round_df[year_col] <= target_year)
        ].copy()
        
        # Count unique comname per firmname
        portfolio_count = window_data.groupby('firmname')['comname'].nunique().reset_index()
        portfolio_count.columns = ['firmname', 'rep_portfolio_count']
        portfolio_count[year_col] = target_year
        
        result_list.append(portfolio_count)
    
    if result_list:
        result = pd.concat(result_list, ignore_index=True)
        # Merge with all firm-years and fill missing with 0
        result = firm_years.merge(result, on=['firmname', year_col], how='left')
        result['rep_portfolio_count'] = result['rep_portfolio_count'].fillna(0).astype(int)
    else:
        result = firm_years.copy()
        result['rep_portfolio_count'] = 0
    
    logger.info(f"Calculated portfolio count for {len(result)} firm-years")
    logger.info(f"  Mean portfolio count: {result['rep_portfolio_count'].mean():.2f}")
    
    return result[['firmname', year_col, 'rep_portfolio_count']]


def calculate_total_invested_rolling(round_df: pd.DataFrame,
                                    year_col: str = 'year',
                                    window_years: int = 5,
                                    amount_col: str = None) -> pd.DataFrame:
    """
    Calculate total funds invested in portfolio firms (5-year rolling window)
    
    Variable 2: Total funds invested in portfolio firms
    - Definition: Given year [t-4, t] period, sum of RoundAmountDisclosedThou per firmname
    - Missing values treated as 0
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Round data with firmname, year, amount columns
    year_col : str
        Column name for year
    window_years : int
        Rolling window size (default: 5 years)
    amount_col : str, optional
        Column name for investment amount. If None, auto-detect from constants
    
    Returns
    -------
    pd.DataFrame
        Firm-year data with rep_total_invested column
    """
    logger.info(f"Calculating total invested (rolling {window_years}-year window)...")
    
    # Auto-detect amount column
    if amount_col is None:
        for col in constants.INVESTMENT_AMOUNT_COLUMNS:
            if col in round_df.columns:
                amount_col = col
                logger.info(f"  Auto-detected amount column: '{amount_col}'")
                break
    
    if amount_col is None or amount_col not in round_df.columns:
        logger.warning(f"No valid amount column found. Tried: {constants.INVESTMENT_AMOUNT_COLUMNS}")
        logger.warning("Setting rep_total_invested to 0")
        firm_years = round_df[['firmname', year_col]].drop_duplicates()
        firm_years['rep_total_invested'] = 0
        return firm_years[['firmname', year_col, 'rep_total_invested']]
    
    # Get all unique firm-year combinations
    all_years = sorted(round_df[year_col].unique())
    firm_years = round_df[['firmname', year_col]].drop_duplicates()
    
    result_list = []
    
    for target_year in all_years:
        # Filter: [t-4, t] inclusive
        window_start = target_year - (window_years - 1)
        window_data = round_df[
            (round_df[year_col] >= window_start) & 
            (round_df[year_col] <= target_year)
        ].copy()
        
        # Fill missing amounts with 0
        window_data[amount_col] = window_data[amount_col].fillna(0)
        
        # Sum amount per firmname
        total_invested = window_data.groupby('firmname')[amount_col].sum().reset_index()
        total_invested.columns = ['firmname', 'rep_total_invested']
        total_invested[year_col] = target_year
        
        result_list.append(total_invested)
    
    if result_list:
        result = pd.concat(result_list, ignore_index=True)
        # Merge with all firm-years and fill missing with 0
        result = firm_years.merge(result, on=['firmname', year_col], how='left')
        result['rep_total_invested'] = result['rep_total_invested'].fillna(0)
    else:
        result = firm_years.copy()
        result['rep_total_invested'] = 0
    
    logger.info(f"Calculated total invested for {len(result)} firm-years")
    logger.info(f"  Mean total invested: ${result['rep_total_invested'].mean():.0f}K")
    
    return result[['firmname', year_col, 'rep_total_invested']]


def calculate_avg_fum(fund_df: pd.DataFrame,
                     round_df: pd.DataFrame,
                     year_col: str = 'year',
                     fundyear_col: str = 'fundyear',
                     fundiniclosing_col: str = 'fundiniclosing',
                     fundsize_col: str = 'fundsize') -> pd.DataFrame:
    """
    Calculate average dollar amount of total funds under management
    
    Variable 3: Average funds under management
    - Definition: At year t, average fundsize of funds raised before t that are still open
    - Logic:
      * fundyear < t (raised before t)
      * fundiniclosing is empty → still open (include)
      * fundiniclosing year > t → still open (include)
      * fundiniclosing year <= t → closed (exclude)
    
    Parameters
    ----------
    fund_df : pd.DataFrame
        Fund data with firmname, fundyear, fundiniclosing, fundsize
    round_df : pd.DataFrame
        Round data to get firm-year combinations
    year_col : str
        Column name for year
    fundyear_col : str
        Column name for fund year
    fundiniclosing_col : str
        Column name for fund initial closing date (dd.mm.yyyy format)
    fundsize_col : str
        Column name for fund size
    
    Returns
    -------
    pd.DataFrame
        Firm-year data with rep_avg_fum column
    """
    logger.info("Calculating average funds under management...")
    
    # Check required columns
    required_cols = ['firmname', fundyear_col, fundsize_col]
    missing_cols = [col for col in required_cols if col not in fund_df.columns]
    
    if missing_cols:
        logger.warning(f"Missing columns in fund_df: {missing_cols}")
        logger.warning("Setting rep_avg_fum to 0")
        firm_years = round_df[['firmname', year_col]].drop_duplicates()
        firm_years['rep_avg_fum'] = 0
        return firm_years[['firmname', year_col, 'rep_avg_fum']]
    
    # Parse fundiniclosing dates (dd.mm.yyyy format)
    fund_df_work = fund_df.copy()
    
    def extract_year_from_ddmmyyyy(date_str):
        """Extract year from dd.mm.yyyy format"""
        if pd.isna(date_str) or date_str == '':
            return np.nan
        try:
            # Try parsing dd.mm.yyyy format
            if isinstance(date_str, str):
                parts = date_str.split('.')
                if len(parts) == 3:
                    return int(parts[2])  # yyyy is the third part
            # Fallback: try pandas datetime parsing
            date_obj = pd.to_datetime(date_str, format='%d.%m.%Y', errors='coerce')
            if pd.notna(date_obj):
                return date_obj.year
        except:
            pass
        return np.nan
    
    if fundiniclosing_col in fund_df.columns:
        # Parse fundiniclosing dates and track parsing failures
        parsed_years = fund_df_work[fundiniclosing_col].apply(extract_year_from_ddmmyyyy)
        fund_df_work['fundiniclosing_year'] = parsed_years
        
        # Monitor parsing failures
        total_funds = len(fund_df_work)
        non_empty = fund_df_work[fundiniclosing_col].notna() & (fund_df_work[fundiniclosing_col] != '')
        parsing_failed = non_empty & parsed_years.isna()
        parsing_failed_count = parsing_failed.sum()
        
        if parsing_failed_count > 0:
            logger.warning(f"⚠️  fundiniclosing 파싱 실패: {parsing_failed_count:,}개 / {non_empty.sum():,}개 (비어있지 않은 항목 중 {parsing_failed_count/non_empty.sum()*100:.1f}%)")
            logger.warning(f"   → 파싱 실패 항목은 'still open'으로 처리됩니다")
        else:
            logger.info(f"✅ fundiniclosing 파싱 성공: {non_empty.sum():,}개 항목 모두 파싱 완료")
    else:
        logger.warning(f"Column '{fundiniclosing_col}' not found. Treating all funds as still open.")
        fund_df_work['fundiniclosing_year'] = np.nan
    
    # Get all unique firm-year combinations
    all_years = sorted(round_df[year_col].unique())
    firm_years = round_df[['firmname', year_col]].drop_duplicates()
    
    result_list = []
    
    for target_year in all_years:
        # Filter funds: raised before t AND still open
        # Condition 1: fundyear < t
        funds_before_t = fund_df_work[fund_df_work[fundyear_col] < target_year].copy()
        
        # Condition 2: Still open (fundiniclosing is empty OR fundiniclosing_year > t)
        still_open_mask = (
            funds_before_t['fundiniclosing_year'].isna() |
            (funds_before_t['fundiniclosing_year'] > target_year)
        )
        open_funds = funds_before_t[still_open_mask].copy()
        
        # Calculate average fundsize per firmname
        if len(open_funds) > 0:
            avg_fum = open_funds.groupby('firmname')[fundsize_col].mean().reset_index()
            avg_fum.columns = ['firmname', 'rep_avg_fum']
            avg_fum[year_col] = target_year
            result_list.append(avg_fum)
    
    if result_list:
        result = pd.concat(result_list, ignore_index=True)
        # Merge with all firm-years and fill missing with 0
        result = firm_years.merge(result, on=['firmname', year_col], how='left')
        result['rep_avg_fum'] = result['rep_avg_fum'].fillna(0)
    else:
        result = firm_years.copy()
        result['rep_avg_fum'] = 0
    
    logger.info(f"Calculated avg FUM for {len(result)} firm-years")
    logger.info(f"  Mean avg FUM: ${result['rep_avg_fum'].mean():.0f}")
    
    return result[['firmname', year_col, 'rep_avg_fum']]


def calculate_funds_raised_rolling(fund_df: pd.DataFrame,
                                   round_df: pd.DataFrame,
                                   year_col: str = 'year',
                                   window_years: int = 5,
                                   fundyear_col: str = 'fundyear',
                                   fundname_col: str = 'fundname') -> pd.DataFrame:
    """
    Calculate number of funds raised (5-year rolling window)
    
    Variable 4: Number of individual funds raised
    - Definition: Given year [t-4, t] period, count of unique fundname per firmname
    
    Parameters
    ----------
    fund_df : pd.DataFrame
        Fund data with firmname, fundyear, fundname
    round_df : pd.DataFrame
        Round data to get firm-year combinations
    year_col : str
        Column name for year
    window_years : int
        Rolling window size (default: 5 years)
    fundyear_col : str
        Column name for fund year
    fundname_col : str
        Column name for fund name
    
    Returns
    -------
    pd.DataFrame
        Firm-year data with rep_funds_raised column
    """
    logger.info(f"Calculating funds raised count (rolling {window_years}-year window)...")
    
    # Check required columns
    required_cols = ['firmname', fundyear_col]
    missing_cols = [col for col in required_cols if col not in fund_df.columns]
    
    if missing_cols:
        logger.warning(f"Missing columns in fund_df: {missing_cols}")
        logger.warning("Setting rep_funds_raised to 0")
        firm_years = round_df[['firmname', year_col]].drop_duplicates()
        firm_years['rep_funds_raised'] = 0
        return firm_years[['firmname', year_col, 'rep_funds_raised']]
    
    # Get all unique firm-year combinations
    all_years = sorted(round_df[year_col].unique())
    firm_years = round_df[['firmname', year_col]].drop_duplicates()
    
    result_list = []
    
    for target_year in all_years:
        # Filter: [t-4, t] inclusive
        window_start = target_year - (window_years - 1)
        window_funds = fund_df[
            (fund_df[fundyear_col] >= window_start) & 
            (fund_df[fundyear_col] <= target_year)
        ].copy()
        
        # Count unique fundname per firmname
        if fundname_col in fund_df.columns:
            funds_raised = window_funds.groupby('firmname')[fundname_col].nunique().reset_index()
        else:
            # If no fundname column, count rows
            funds_raised = window_funds.groupby('firmname').size().reset_index(name=fundname_col)
        
        funds_raised.columns = ['firmname', 'rep_funds_raised']
        funds_raised[year_col] = target_year
        
        result_list.append(funds_raised)
    
    if result_list:
        result = pd.concat(result_list, ignore_index=True)
        # Merge with all firm-years and fill missing with 0
        result = firm_years.merge(result, on=['firmname', year_col], how='left')
        result['rep_funds_raised'] = result['rep_funds_raised'].fillna(0).astype(int)
    else:
        result = firm_years.copy()
        result['rep_funds_raised'] = 0
    
    logger.info(f"Calculated funds raised for {len(result)} firm-years")
    logger.info(f"  Mean funds raised: {result['rep_funds_raised'].mean():.2f}")
    
    return result[['firmname', year_col, 'rep_funds_raised']]


def calculate_ipos_cumulative_rolling(round_df: pd.DataFrame,
                                     company_df: pd.DataFrame,
                                     year_col: str = 'year',
                                     window_years: int = 5) -> pd.DataFrame:
    """
    Calculate cumulative number of portfolio firms taken public (5-year rolling window)
    
    Variable 5: Number of portfolio firms taken public
    - Definition: VC firm이 과거에 투자했던 회사들 중에서 [t-4, t] 기간 동안 IPO한 회사 수
    - Logic: 투자는 과거에 했고, IPO는 [t-4, t] 동안 일어난 것만 카운트
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Round data with firmname, comname, year
    company_df : pd.DataFrame
        Company data with comsitu, date_sit, date_ipo
    year_col : str
        Column name for year
    window_years : int
        Rolling window size (default: 5 years)
    
    Returns
    -------
    pd.DataFrame
        Firm-year data with rep_ipos column
    """
    logger.info(f"Calculating cumulative IPOs (rolling {window_years}-year window)...")
    
    # Use performance settings from constants
    settings = constants.PERFORMANCE_SETTINGS
    situ_col = settings['situation_column']
    date_sit_col = settings['situation_date_column']
    date_ipo_col = settings['ipo_date_column']
    
    # Check required columns
    required_cols = ['comname', situ_col, date_sit_col, date_ipo_col]
    missing_cols = [col for col in required_cols if col not in company_df.columns]
    
    if missing_cols:
        logger.warning(f"Missing columns in company_df: {missing_cols}")
        logger.warning("Setting rep_ipos to 0")
        firm_years = round_df[['firmname', year_col]].drop_duplicates()
        firm_years['rep_ipos'] = 0
        return firm_years[['firmname', year_col, 'rep_ipos']]
    
    # Step 1: Create IPO exit indicators
    company_exits = company_df[required_cols].copy()
    
    # IPO Exit: comsitu = "Went Public" AND (date_sit != "" OR date_ipo != "")
    company_exits['ipoExit'] = (
        (company_exits[situ_col].isin(settings['ipo_values'])) &
        ((company_exits[date_sit_col].notna() & (company_exits[date_sit_col] != '')) |
         (company_exits[date_ipo_col].notna() & (company_exits[date_ipo_col] != '')))
    ).astype(int)
    
    # Step 2: Extract IPO year
    def extract_year_from_date(date_str):
        """Extract year from date string"""
        if pd.isna(date_str) or date_str == '':
            return np.nan
        try:
            date_obj = pd.to_datetime(date_str, errors='coerce')
            if pd.notna(date_obj):
                return date_obj.year
        except:
            pass
        return np.nan
    
    company_exits['ipo_year'] = company_exits.apply(
        lambda row: (
            extract_year_from_date(row[date_ipo_col]) 
            if row['ipoExit'] == 1 and pd.notna(row[date_ipo_col]) and row[date_ipo_col] != ''
            else extract_year_from_date(row[date_sit_col])
        ),
        axis=1
    )
    
    # Step 3: Merge round data with IPO data
    round_with_ipos = round_df[['firmname', 'comname', year_col]].merge(
        company_exits[['comname', 'ipoExit', 'ipo_year']],
        on='comname',
        how='left'
    )
    
    # Fill NaN IPOs with 0
    round_with_ipos['ipoExit'] = round_with_ipos['ipoExit'].fillna(0)
    round_with_ipos['ipo_year'] = round_with_ipos['ipo_year'].fillna(0).astype(int)
    
    # Step 4: Calculate cumulative IPOs for rolling window
    all_years = sorted(round_df[year_col].unique())
    firm_years = round_df[['firmname', year_col]].drop_duplicates()
    
    result_list = []
    
    for target_year in all_years:
        # Window: [t-4, t] for IPO year
        window_start = target_year - (window_years - 1)
        
        # Find all companies that IPO'd in [t-4, t]
        ipos_in_window = company_exits[
            (company_exits['ipoExit'] == 1) &
            (company_exits['ipo_year'] >= window_start) &
            (company_exits['ipo_year'] <= target_year) &
            (company_exits['ipo_year'].notna())
        ][['comname']].drop_duplicates()
        
        if len(ipos_in_window) > 0:
            # Find all firms that invested in these companies (투자는 과거에 했어도 됨)
            firms_with_ipos = round_with_ipos[
                round_with_ipos['comname'].isin(ipos_in_window['comname'])
            ].groupby('firmname')['comname'].nunique().reset_index()
            
            firms_with_ipos.columns = ['firmname', 'rep_ipos']
            firms_with_ipos[year_col] = target_year
            result_list.append(firms_with_ipos)
    
    if result_list:
        result = pd.concat(result_list, ignore_index=True)
        # Merge with all firm-years and fill missing with 0
        result = firm_years.merge(result, on=['firmname', year_col], how='left')
        result['rep_ipos'] = result['rep_ipos'].fillna(0).astype(int)
    else:
        result = firm_years.copy()
        result['rep_ipos'] = 0
    
    logger.info(f"Calculated cumulative IPOs for {len(result)} firm-years")
    logger.info(f"  Mean IPOs: {result['rep_ipos'].mean():.2f}")
    
    return result[['firmname', year_col, 'rep_ipos']]


def calculate_funding_age(fund_df: pd.DataFrame,
                         round_df: pd.DataFrame,
                         year_col: str = 'year',
                         fundyear_col: str = 'fundyear') -> pd.DataFrame:
    """
    Calculate VC age based on first fund raising year
    
    Variable 6: VC age (fundingAge)
    - Definition: At year t, difference between t and first fundyear
    - Formula: fundingAge = t - min(fundyear) per firm
    
    Parameters
    ----------
    fund_df : pd.DataFrame
        Fund data with firmname, fundyear
    round_df : pd.DataFrame
        Round data to get firm-year combinations
    year_col : str
        Column name for year
    fundyear_col : str
        Column name for fund year
    
    Returns
    -------
    pd.DataFrame
        Firm-year data with fundingAge column
    """
    logger.info("Calculating funding age (from first fund year)...")
    
    # Check required columns
    if fundyear_col not in fund_df.columns:
        logger.warning(f"Column '{fundyear_col}' not found in fund_df")
        logger.warning("Setting fundingAge to NaN")
        firm_years = round_df[['firmname', year_col]].drop_duplicates()
        firm_years['fundingAge'] = np.nan
        return firm_years[['firmname', year_col, 'fundingAge']]
    
    # Get first fund year per firm
    first_fund_year = fund_df.groupby('firmname')[fundyear_col].min().reset_index()
    first_fund_year.columns = ['firmname', 'first_fund_year']
    
    # Get all firm-year combinations
    firm_years = round_df[['firmname', year_col]].drop_duplicates()
    
    # Merge first fund year
    result = firm_years.merge(first_fund_year, on='firmname', how='left')
    
    # Calculate funding age
    result['fundingAge'] = result[year_col] - result['first_fund_year']
    
    # Handle negative ages (set to 0)
    result.loc[result['fundingAge'] < 0, 'fundingAge'] = 0
    
    # Drop intermediate column
    result = result.drop(columns=['first_fund_year'])
    
    # Fill missing with 0 (firms with no fund data)
    result['fundingAge'] = result['fundingAge'].fillna(0).astype(int)
    
    logger.info(f"Calculated funding age for {len(result)} firm-years")
    logger.info(f"  Age range: {result['fundingAge'].min():.0f} - {result['fundingAge'].max():.0f} years")
    
    return result[['firmname', year_col, 'fundingAge']]


def calculate_vc_reputation(round_df: pd.DataFrame,
                            company_df: pd.DataFrame,
                            fund_df: pd.DataFrame,
                            year_col: str = 'year',
                            window_years: int = 5) -> pd.DataFrame:
    """
    Calculate VC reputation index using 6 variables with z-score standardization
    
    Methodology:
    1. Calculate 6 reputation variables (5-year rolling window):
       - rep_portfolio_count: Unique portfolio companies [t-4, t]
       - rep_total_invested: Total funds invested [t-4, t]
       - rep_avg_fum: Average funds under management (at year t)
       - rep_funds_raised: Number of funds raised [t-4, t]
       - rep_ipos: Cumulative IPOs [t-4, t]
       - fundingAge: VC age from first fund year
    
    2. Z-score standardize each variable BY YEAR
    3. Sum all 6 z-scores
    4. Min-Max scale to [0.01, 100] BY YEAR
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Round data
    company_df : pd.DataFrame
        Company data
    fund_df : pd.DataFrame
        Fund data
    year_col : str
        Column name for year
    window_years : int
        Rolling window size (default: 5 years)
    
    Returns
    -------
    pd.DataFrame
        Firm-year data with VC_reputation column and all 6 component variables.
        Also includes rep_missing_fund_data flag (1 if any fund-based variable is missing, 0 otherwise).
        This flag can be used to exclude observations in final sampling.
    """
    logger.info("=" * 80)
    logger.info("Calculating VC Reputation Index...")
    logger.info("=" * 80)
    
    # Step 1: Calculate all 6 variables
    logger.info("\nStep 1: Calculating component variables...")
    
    var1 = calculate_portfolio_count_rolling(round_df, year_col, window_years)
    var2 = calculate_total_invested_rolling(round_df, year_col, window_years)
    var3 = calculate_avg_fum(fund_df, round_df, year_col)
    var4 = calculate_funds_raised_rolling(fund_df, round_df, year_col, window_years)
    var5 = calculate_ipos_cumulative_rolling(round_df, company_df, year_col, window_years)
    var6 = calculate_funding_age(fund_df, round_df, year_col)
    
    # Step 2: Merge all variables (left join to preserve round_df-based firm-year structure)
    logger.info("\nStep 2: Merging all variables...")
    
    result = var1.copy()
    for df in [var2, var3, var4, var5, var6]:
        result = result.merge(df, on=['firmname', year_col], how='left')
    
    # Identify fund data missing cases BEFORE filling NaN (for var3, var4, var6 which use fund_df)
    fund_based_vars = ['rep_avg_fum', 'rep_funds_raised', 'fundingAge']
    result['rep_missing_fund_data'] = (
        result[[v for v in fund_based_vars if v in result.columns]].isna().any(axis=1)
    ).astype(int)
    
    # Fill all missing values with 0
    rep_vars = ['rep_portfolio_count', 'rep_total_invested', 'rep_funds_raised', 'rep_ipos']
    for var in rep_vars:
        if var in result.columns:
            result[var] = result[var].fillna(0)
    
    # For fund-based vars, fill with 0 but keep the missing flag
    for var in fund_based_vars:
        if var in result.columns:
            result[var] = result[var].fillna(0)
    
    # Log missing fund data statistics
    missing_fund_count = result['rep_missing_fund_data'].sum()
    if missing_fund_count > 0:
        logger.warning(f"⚠️  Fund 데이터 누락: {missing_fund_count:,}개 firm-year ({missing_fund_count/len(result)*100:.1f}%)")
        logger.warning(f"   → rep_missing_fund_data 컬럼으로 표시됨 (최종 샘플링 시 제외 가능)")
    else:
        logger.info(f"✅ 모든 firm-year에 fund 데이터 존재")
    
    # Step 3: Z-score standardize BY YEAR
    logger.info("\nStep 3: Z-score standardizing by year...")
    
    # All 6 reputation variables for z-score standardization
    all_rep_vars = ['rep_portfolio_count', 'rep_total_invested', 'rep_avg_fum', 
                    'rep_funds_raised', 'rep_ipos', 'fundingAge']
    
    for var in all_rep_vars:
        if var in result.columns:
            z_col = f'{var}_z'
            result[z_col] = result.groupby(year_col)[var].transform(
                lambda x: (x - x.mean()) / x.std() if x.std() > 0 else 0
            )
            # Fill NaN z-scores (when std=0) with 0
            result[z_col] = result[z_col].fillna(0)
    
    # Step 4: Sum z-scores
    logger.info("\nStep 4: Summing z-scores...")
    
    z_cols = [f'{var}_z' for var in all_rep_vars if f'{var}_z' in result.columns]
    result['rep_index_raw'] = result[z_cols].sum(axis=1)
    
    # Step 5: Min-Max scale to [0.01, 100] BY YEAR
    logger.info("\nStep 5: Min-Max scaling to [0.01, 100] by year...")
    
    def min_max_scale_by_year(group):
        """Scale to [0.01, 100]"""
        if len(group) == 0:
            return group
        min_val = group['rep_index_raw'].min()
        max_val = group['rep_index_raw'].max()
        if max_val == min_val:
            # All values are the same, set to midpoint
            group['VC_reputation'] = 50.0
        else:
            # Scale: 0.01 + (value - min) / (max - min) * (100 - 0.01)
            group['VC_reputation'] = 0.01 + (group['rep_index_raw'] - min_val) / (max_val - min_val) * 99.99
        return group
    
    result = result.groupby(year_col).apply(min_max_scale_by_year).reset_index(drop=True)
    
    # Drop intermediate z-score columns (optional - keep for debugging)
    # result = result.drop(columns=z_cols + ['rep_index_raw'])
    
    logger.info("=" * 80)
    logger.info(f"✅ VC Reputation calculated!")
    logger.info(f"   - Firm-years: {len(result)}")
    logger.info(f"   - Unique firms: {result['firmname'].nunique()}")
    logger.info(f"   - Year range: {result[year_col].min()} - {result[year_col].max()}")
    logger.info(f"   - Reputation range: {result['VC_reputation'].min():.2f} - {result['VC_reputation'].max():.2f}")
    logger.info("=" * 80)
    
    return result


def calculate_market_heat(fund_df: pd.DataFrame,
                          year_col: str = 'year',
                          fundyear_col: str = 'fundyear',
                          fundname_col: str = 'fundname') -> pd.DataFrame:
    """
    Calculate Market Heat at industry level
    
    Market Heat measures the relative activity of VC fund raising:
    - Hot market: Market heat > 0
    - Cold market: Market heat < 0
    
    Formula:
    Market heat_t = ln((VC funds raised_t × 3) / Σ_{k=t-3}^{t-1} VC funds raised_k)
    
    Where:
    - VC funds raised_t: Number of unique VC funds raised in year t (industry level)
    - Denominator: Sum of VC funds raised in the antecedent 3 years (t-3, t-2, t-1)
    
    Note: The denominator uses shift(1) to calculate past 3 years, but the Market Heat
    value itself is for the current year t (raw dataset).
    
    Parameters
    ----------
    fund_df : pd.DataFrame
        Fund data with fundyear and fundname columns
    year_col : str
        Column name for year (for output)
    fundyear_col : str
        Column name for fund year
    fundname_col : str
        Column name for fund name (unique identifier)
    
    Returns
    -------
    pd.DataFrame
        Year-level data with market_heat column
        Columns: year, market_heat
    """
    logger.info("=" * 80)
    logger.info("Calculating Market Heat (industry-level)...")
    logger.info("=" * 80)
    
    # Check required columns
    required_cols = [fundyear_col]
    if fundname_col not in fund_df.columns:
        logger.warning(f"Column '{fundname_col}' not found. Using row count instead.")
        use_fundname = False
    else:
        use_fundname = True
        required_cols.append(fundname_col)
    
    missing_cols = [col for col in required_cols if col not in fund_df.columns]
    if missing_cols:
        logger.error(f"Missing required columns: {missing_cols}")
        logger.error("Cannot calculate Market Heat. Returning empty DataFrame.")
        return pd.DataFrame({year_col: [], 'market_heat': []})
    
    # Step 1: Calculate annual fund counts (industry level)
    logger.info("Step 1: Calculating annual fund counts...")
    
    if use_fundname:
        # Count unique fundname per year
        annual_funds = fund_df.groupby(fundyear_col)[fundname_col].nunique().reset_index()
        annual_funds.columns = [fundyear_col, 'funds_raised']
    else:
        # Count rows per year (fallback)
        annual_funds = fund_df.groupby(fundyear_col).size().reset_index(name='funds_raised')
    
    # Sort by year
    annual_funds = annual_funds.sort_values(fundyear_col).reset_index(drop=True)
    
    logger.info(f"  Year range: {annual_funds[fundyear_col].min()} - {annual_funds[fundyear_col].max()}")
    logger.info(f"  Total years: {len(annual_funds)}")
    logger.info(f"  Mean funds per year: {annual_funds['funds_raised'].mean():.1f}")
    
    # Step 2: Calculate 3-year antecedent sum (t-3 ~ t-1)
    logger.info("Step 2: Calculating 3-year antecedent sums...")
    
    # Create a complete year series for proper alignment
    min_year = int(annual_funds[fundyear_col].min())
    max_year = int(annual_funds[fundyear_col].max())
    all_years = pd.DataFrame({fundyear_col: range(min_year, max_year + 1)})
    
    # Merge with annual funds (fill missing years with 0)
    annual_funds_complete = all_years.merge(
        annual_funds,
        on=fundyear_col,
        how='left'
    )
    annual_funds_complete['funds_raised'] = annual_funds_complete['funds_raised'].fillna(0)
    
    # Calculate rolling sum of previous 3 years (t-3, t-2, t-1)
    # Shift by 1 to exclude current year, then rolling sum of 3 years
    annual_funds_complete['funds_raised_sum_3yr'] = (
        annual_funds_complete['funds_raised']
        .shift(1)  # Exclude current year
        .rolling(window=3, min_periods=1)  # Sum of t-3, t-2, t-1
        .sum()
    )
    
    # Step 3: Calculate Market Heat
    logger.info("Step 3: Calculating Market Heat...")
    
    # Numerator: funds_raised_t × 3
    annual_funds_complete['numerator'] = annual_funds_complete['funds_raised'] * 3
    
    # Denominator: sum of t-3 ~ t-1
    denominator = annual_funds_complete['funds_raised_sum_3yr']
    
    # Calculate ratio
    ratio = annual_funds_complete['numerator'] / denominator
    
    # Apply natural log (handle edge cases)
    # NaN if denominator = 0 or ratio <= 0
    market_heat = np.where(
        (denominator > 0) & (ratio > 0),
        np.log(ratio),
        np.nan
    )
    
    annual_funds_complete['market_heat'] = market_heat
    
    # Step 4: Prepare output
    result = annual_funds_complete[[fundyear_col, 'market_heat']].copy()
    result.columns = [year_col, 'market_heat']
    
    # Remove rows with NaN market_heat (edge cases)
    result = result.dropna(subset=['market_heat'])
    
    # Log statistics
    logger.info("=" * 80)
    logger.info(f"✅ Market Heat calculated!")
    logger.info(f"   - Year range: {result[year_col].min()} - {result[year_col].max()}")
    logger.info(f"   - Valid years: {len(result)}")
    logger.info(f"   - Market Heat range: {result['market_heat'].min():.3f} - {result['market_heat'].max():.3f}")
    logger.info(f"   - Mean Market Heat: {result['market_heat'].mean():.3f}")
    
    # Count hot vs cold markets
    hot_markets = (result['market_heat'] > 0).sum()
    cold_markets = (result['market_heat'] < 0).sum()
    logger.info(f"   - Hot markets (>0): {hot_markets} ({hot_markets/len(result)*100:.1f}%)")
    logger.info(f"   - Cold markets (<0): {cold_markets} ({cold_markets/len(result)*100:.1f}%)")
    logger.info("=" * 80)
    
    return result


def calculate_new_venture_funding_demand(round_df: pd.DataFrame,
                                        company_df: pd.DataFrame,
                                        year_col: str = 'year',
                                        roundnumber_col: str = 'RoundNumber',
                                        comname_col: str = 'comname',
                                        comnation_col: str = 'comnation',
                                        us_nation: str = 'US') -> pd.DataFrame:
    """
    Calculate New Venture Funding Demand (current year, NOT lagged)
    
    Measures demand for VC funding based on the natural log of the total
    number of new ventures that received a first round of VC financing in the
    United States in the current calendar year.
    
    Note: This is a RAW dataset variable. For panel analysis, lagging should
    be done during regression analysis (e.g., using year t-1 value).
    
    Formula:
    new_venture_demand_t = ln(count of first-round ventures in year t)
    
    Where:
    - First round: RoundNumber == min(RoundNumber) per company
    - US only: comnation == 'US' (from company_df)
    - Current year: Uses year t (NOT lagged)
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Round data with RoundNumber, comname, year
    company_df : pd.DataFrame
        Company data with comname, comnation (for US filtering)
    year_col : str
        Column name for year
    roundnumber_col : str
        Column name for round number
    comname_col : str
        Column name for company name
    comnation_col : str
        Column name for company nationality
    us_nation : str
        Value indicating US companies (default: 'US')
    
    Returns
    -------
    pd.DataFrame
        Year-level data with new_venture_demand column
        Columns: year, new_venture_demand
    """
    logger.info("=" * 80)
    logger.info("Calculating New Venture Funding Demand (current year, NOT lagged)...")
    logger.info("=" * 80)
    
    # Check required columns
    required_cols = [comname_col, year_col]
    if roundnumber_col not in round_df.columns:
        logger.warning(f"Column '{roundnumber_col}' not found. Cannot identify first rounds.")
        logger.warning("Returning empty DataFrame.")
        return pd.DataFrame({year_col: [], 'new_venture_demand': []})
    
    # Step 1: Merge company nationality information from company_df
    logger.info("Step 1: Merging company nationality information from company_df...")
    
    if comnation_col not in company_df.columns:
        logger.error(f"Column '{comnation_col}' not found in company_df.")
        logger.error("Cannot filter US companies. Returning empty DataFrame.")
        return pd.DataFrame({year_col: [], 'new_venture_demand': []})
    
    # Merge nationality from company_df to round_df
    round_with_nation = round_df.merge(
        company_df[[comname_col, comnation_col]].drop_duplicates(subset=[comname_col]),
        on=comname_col,
        how='left'
    )
    logger.info(f"  Merged nationality for {len(round_with_nation)} rounds")
    logger.info(f"  Rounds with nationality info: {round_with_nation[comnation_col].notna().sum():,} / {len(round_with_nation):,}")
    logger.info(f"  Unique nation values: {round_with_nation[comnation_col].dropna().unique()[:10]} (showing first 10)")
    
    # Step 2: Identify first rounds per company
    logger.info("Step 2: Identifying first rounds...")
    
    # Fill NaN RoundNumber with a large number (so they're not considered first rounds)
    round_with_nation[roundnumber_col] = round_with_nation[roundnumber_col].fillna(9999)
    
    # Find minimum RoundNumber per company
    round_with_nation['min_round'] = round_with_nation.groupby(comname_col)[roundnumber_col].transform('min')
    round_with_nation['is_first_round'] = (round_with_nation[roundnumber_col] == round_with_nation['min_round']).astype(int)
    
    first_rounds = round_with_nation[round_with_nation['is_first_round'] == 1].copy()
    logger.info(f"  Identified {len(first_rounds)} first-round investments")
    logger.info(f"  Unique companies with first rounds: {first_rounds[comname_col].nunique()}")
    
    # Step 3: Filter US companies only
    logger.info("Step 3: Filtering US companies...")
    
    if comnation_col in company_df.columns:
        # Check what values exist in comnation
        unique_nations = first_rounds[comnation_col].dropna().unique()
        logger.info(f"  Unique nation values in first_rounds: {unique_nations[:10]} (showing first 10)")
        logger.info(f"  Looking for: '{us_nation}'")
        
        # Try exact match first
        us_first_rounds = first_rounds[
            first_rounds[comnation_col] == us_nation
        ].copy()
        
        # If no matches, try case-insensitive or partial match
        if len(us_first_rounds) == 0:
            logger.warning(f"  No exact match for '{us_nation}'. Trying case-insensitive match...")
            us_first_rounds = first_rounds[
                first_rounds[comnation_col].str.contains(us_nation, case=False, na=False)
            ].copy()
            if len(us_first_rounds) > 0:
                logger.info(f"  Found {len(us_first_rounds)} matches with case-insensitive search")
        
        logger.info(f"  US first-round investments: {len(us_first_rounds)}")
        if len(us_first_rounds) > 0:
            logger.info(f"  Unique US companies: {us_first_rounds[comname_col].nunique()}")
        else:
            logger.warning(f"  ⚠️  No US first-round investments found!")
            logger.warning(f"  This may cause new_venture_demand to be empty.")
    else:
        us_first_rounds = first_rounds.copy()
        logger.warning("  US filter not applied (comnation column missing)")
    
    # Step 4: Count unique ventures per year (CURRENT YEAR, NOT LAGGED)
    logger.info("Step 4: Counting unique ventures per year (current year)...")
    
    if len(us_first_rounds) == 0:
        logger.warning("  ⚠️  us_first_rounds is empty. Cannot calculate annual ventures.")
        logger.warning("  Returning empty DataFrame.")
        return pd.DataFrame({year_col: [], 'new_venture_demand': []})
    
    annual_ventures = us_first_rounds.groupby(year_col)[comname_col].nunique().reset_index()
    annual_ventures.columns = [year_col, 'venture_count']
    
    if len(annual_ventures) == 0:
        logger.warning("  ⚠️  annual_ventures is empty after grouping.")
        logger.warning("  Returning empty DataFrame.")
        return pd.DataFrame({year_col: [], 'new_venture_demand': []})
    
    logger.info(f"  Year range: {annual_ventures[year_col].min()} - {annual_ventures[year_col].max()}")
    logger.info(f"  Total years: {len(annual_ventures)}")
    logger.info(f"  Mean ventures per year: {annual_ventures['venture_count'].mean():.1f}")
    logger.info(f"  Years with zero ventures: {(annual_ventures['venture_count'] == 0).sum()}")
    
    # Step 5: Apply natural log transformation
    logger.info("Step 5: Applying natural log transformation...")
    
    # Handle zeros and negative values (shouldn't happen, but safety check)
    annual_ventures['new_venture_demand'] = np.where(
        annual_ventures['venture_count'] > 0,
        np.log(annual_ventures['venture_count']),
        np.nan
    )
    
    # Prepare output
    result = annual_ventures[[year_col, 'new_venture_demand']].copy()
    
    # Remove rows with NaN (zero count)
    result = result.dropna(subset=['new_venture_demand'])
    
    # Log statistics
    logger.info("=" * 80)
    logger.info(f"✅ New Venture Funding Demand calculated!")
    logger.info(f"   - Year range: {result[year_col].min()} - {result[year_col].max()}")
    logger.info(f"   - Valid years: {len(result)}")
    logger.info(f"   - Demand range: {result['new_venture_demand'].min():.3f} - {result['new_venture_demand'].max():.3f}")
    logger.info(f"   - Mean demand: {result['new_venture_demand'].mean():.3f}")
    logger.info(f"   - Note: This is CURRENT YEAR value. Lagging should be done during regression analysis.")
    logger.info("=" * 80)
    
    return result

