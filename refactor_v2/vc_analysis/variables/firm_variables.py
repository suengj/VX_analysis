"""
VC Firm-level variables calculation

This module calculates various firm-level characteristics including:
- Firm age (year - founding year)
- Investment diversity (Blau index by industry)
- Performance metrics (all exits, IPO, M&A)
- Early stage participation ratio
- Firm HQ location (CA, MA dummy)
- Total investment amount (by year)
- Total investment number (by year)
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
    Calculate firm HQ dummy (1 if CA or MA, 0 otherwise)
    
    CA (California) and MA (Massachusetts) are major VC hubs:
    - Silicon Valley (CA)
    - Boston/Cambridge (MA)
    
    Parameters
    ----------
    firm_df : pd.DataFrame
        Firm data with state information
    state_col : str
        Column name for firm state
    
    Returns
    -------
    pd.DataFrame
        Firm data with firm_hq column
    """
    logger.info("Calculating firm HQ dummy (CA/MA)...")
    
    firm_hq = firm_df[['firmname']].drop_duplicates()
    
    if state_col in firm_df.columns:
        firm_hq = firm_hq.merge(
            firm_df[['firmname', state_col]].drop_duplicates(subset=['firmname']),
            on='firmname',
            how='left'
        )
        
        # Get high-value states from constants
        high_value_states = (
            constants.FIRM_HQ_HIGH_VALUE_STATES['state_codes'] + 
            constants.FIRM_HQ_HIGH_VALUE_STATES['state_names']
        )
        logger.info(f"  High-value states: {high_value_states}")
        
        # Create dummy (1 if in high-value states)
        firm_hq['firm_hq'] = firm_hq[state_col].isin(high_value_states).astype(int)
        
        # Drop state column
        firm_hq = firm_hq.drop(columns=[state_col])
        
        logger.info(f"Calculated HQ dummy for {len(firm_hq)} firms")
        logger.info(f"  CA/MA firms: {firm_hq['firm_hq'].sum():.0f} ({firm_hq['firm_hq'].mean()*100:.1f}%)")
    else:
        logger.warning(f"Column '{state_col}' not found. Setting firm_hq to NaN")
        firm_hq['firm_hq'] = np.nan
    
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

