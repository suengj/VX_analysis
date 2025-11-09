"""
Data loading functions

This module provides functions to load raw Excel files and convert them
to pandas DataFrames with optimized dtypes.
"""

import pandas as pd
import numpy as np
from pathlib import Path
from typing import List, Dict, Optional
from concurrent.futures import ProcessPoolExecutor
from tqdm import tqdm
import logging

from ..config import paths, constants

logger = logging.getLogger(__name__)


def read_excel_file(file_path: Path, **kwargs) -> pd.DataFrame:
    """
    Read a single Excel file
    
    Parameters
    ----------
    file_path : Path
        Path to Excel file
    **kwargs : dict
        Additional arguments for pd.read_excel()
    
    Returns
    -------
    pd.DataFrame
        Loaded data
    """
    try:
        df = pd.read_excel(file_path, **kwargs)
        logger.info(f"Loaded {file_path.name}: {len(df)} rows")
        return df
    except Exception as e:
        logger.error(f"Error loading {file_path}: {e}")
        return pd.DataFrame()


def load_round_data() -> pd.DataFrame:
    """
    Load round data from CSV
    
    Returns
    -------
    pd.DataFrame
        Round data
    """
    if not paths.ROUND_FILE.exists():
        logger.warning(f"Round file not found: {paths.ROUND_FILE}")
        return pd.DataFrame()
    
    logger.info(f"Loading round file: {paths.ROUND_FILE.name}")
    
    try:
        round_df = pd.read_csv(paths.ROUND_FILE)
        logger.info(f"Loaded round data: {len(round_df)} rows, {len(round_df.columns)} columns")
        
        # 1) Exclude 'Undisclosed' entities
        if 'firmname' in round_df.columns:
            removed_firm = int((round_df['firmname'] == 'Undisclosed Firm').sum())
            if removed_firm:
                logger.info(f"Removed 'Undisclosed Firm' rows: {removed_firm}")
                round_df = round_df[round_df['firmname'] != 'Undisclosed Firm']

        if 'comname' in round_df.columns:
            removed_comp = int((round_df['comname'] == 'Undisclosed Company').sum())
            if removed_comp:
                logger.info(f"Removed 'Undisclosed Company' rows: {removed_comp}")
                round_df = round_df[round_df['comname'] != 'Undisclosed Company']

        # 2) Drop exact duplicate rows (all columns identical)
        before_dups = len(round_df)
        round_df = round_df.drop_duplicates()
        dup_removed = before_dups - len(round_df)
        if dup_removed:
            logger.info(f"Removed exact duplicate rows: {dup_removed}")

        # Convert Excel serial number to datetime (origin: 1899-12-30)
        if 'rnddate' in round_df.columns:
            try:
                # Excel serial number conversion
                round_df['rnddate'] = pd.to_datetime(round_df['rnddate'], unit='D', origin='1899-12-30')
                logger.info("Converted rnddate from Excel serial number")
            except:
                # If already in datetime format, try regular parsing
                round_df['rnddate'] = pd.to_datetime(round_df['rnddate'], errors='coerce')
                logger.info("Parsed rnddate as datetime")
        
        # Add year column
        if 'rnddate' in round_df.columns:
            round_df['year'] = round_df['rnddate'].dt.year
            logger.info(f"Created year column: {round_df['year'].min()} - {round_df['year'].max()}")
        
        # Optimize dtypes
        round_df = optimize_dtypes(round_df)
        
        return round_df
    except Exception as e:
        logger.error(f"Error loading round data: {e}")
        return pd.DataFrame()


def load_company_data() -> pd.DataFrame:
    """
    Load company data from CSV
    
    Returns
    -------
    pd.DataFrame
        Company data
    """
    if not paths.COMDTA_FILE.exists():
        logger.warning(f"Company file not found: {paths.COMDTA_FILE}")
        return pd.DataFrame()
    
    logger.info(f"Loading company file: {paths.COMDTA_FILE.name}")
    
    try:
        company_df = pd.read_csv(paths.COMDTA_FILE)
        logger.info(f"Loaded company data: {len(company_df)} rows, {len(company_df.columns)} columns")

        # 1) Exclude 'Undisclosed Company'
        if 'comname' in company_df.columns:
            undisclosed = int((company_df['comname'] == 'Undisclosed Company').sum())
            if undisclosed:
                logger.info(f"Removed 'Undisclosed Company' rows: {undisclosed}")
                company_df = company_df[company_df['comname'] != 'Undisclosed Company']

        # 2) Parse dates (support optional date_fnd if present)
        date_cols = [c for c in ['date_fnd', 'date_sit', 'date_ipo'] if c in company_df.columns]
        if date_cols:
            company_df = parse_dates(company_df, date_cols)

        # 3) Deduplicate by comname keeping the row with MOST non-null fields
        if 'comname' in company_df.columns and not company_df.empty:
            before = len(company_df)
            # non-null count across all columns as information score
            company_df['_non_null_score'] = company_df.notna().sum(axis=1)
            # pick the index with max score per comname (ties -> first)
            idx = company_df.groupby('comname')['_non_null_score'].idxmax()
            company_df = company_df.loc[idx].drop(columns=['_non_null_score'])
            logger.info(f"Deduplicated companies: {before - len(company_df)} rows removed")

        # 4) Optimize dtypes
        company_df = optimize_dtypes(company_df)

        return company_df
    except Exception as e:
        logger.error(f"Error loading company data: {e}")
        return pd.DataFrame()
    

def _deduplicate_firm_rows(df: pd.DataFrame) -> pd.DataFrame:
    """
    Deduplicate firm rows by firmname using simple, readable rules:
    1) Prefer rows with a founding date; among them keep the earliest.
    2) If multiple remain, prefer rows with a zip code present.
    3) If the picked row lacks both founding date and zip code, drop the firm.
    """
    if df.empty or 'firmname' not in df.columns:
        return df

    has_found_col = 'firmfounding' in df.columns
    has_zip_col = 'firmzip' in df.columns

    # Build sorting keys to select the best row per firm
    df_sorted = df.assign(
        _missing_found=(~df['firmfounding'].notna()) if has_found_col else True,
        _missing_zip=(~df['firmzip'].notna()) if has_zip_col else True,
    )

    sort_cols = ['firmname']
    if has_found_col:
        sort_cols += ['_missing_found', 'firmfounding']  # keep earliest founding first
    if has_zip_col:
        sort_cols += ['_missing_zip']  # prefer having zip

    df_sorted = df_sorted.sort_values(sort_cols, ascending=True)

    # Keep the best row per firm
    dedup = df_sorted.drop_duplicates(subset=['firmname'], keep='first').copy()
    
    # Drop firms where both founding date and zip are missing
    if has_found_col and has_zip_col:
        invalid = dedup['firmfounding'].isna() & dedup['firmzip'].isna()
    elif has_found_col:
        invalid = dedup['firmfounding'].isna()
    else:
        invalid = pd.Series(False, index=dedup.index)

    result = dedup.loc[~invalid].drop(columns=['_missing_found', '_missing_zip'], errors='ignore')
    return result


def load_firm_data() -> pd.DataFrame:
    """
    Load firm data from Excel and apply concise, transparent cleaning:
    - Drop rows flagged for removal (remove == 'x')
    - Exclude 'Undisclosed Firm'
    - Parse dates (firmfounding)
    - Deduplicate by firmname (earliest founding, prefer zip; drop if both missing)
    - Merge firmtype2
    - Optimize dtypes
    """
    if not paths.FIRMDTA_FILE.exists():
        logger.warning(f"Firm file not found: {paths.FIRMDTA_FILE}")
        return pd.DataFrame()
    
    logger.info(f"Loading firm file: {paths.FIRMDTA_FILE.name}")

    try:
        firm_df = pd.read_excel(paths.FIRMDTA_FILE)
        logger.info(f"Loaded firm data: {len(firm_df)} rows, {len(firm_df.columns)} columns")

        # 1) Drop rows flagged for removal
        if 'remove' in firm_df.columns:
            removed = int((firm_df['remove'] == 'x').sum())
            if removed:
                logger.info(f"Removed rows flagged for removal: {removed}")
            firm_df = firm_df[firm_df['remove'] != 'x']

        # 2) Exclude 'Undisclosed Firm'
        if 'firmname' in firm_df.columns:
            undisclosed = int((firm_df['firmname'] == 'Undisclosed Firm').sum())
            if undisclosed:
                logger.info(f"Removed 'Undisclosed Firm' rows: {undisclosed}")
                firm_df = firm_df[firm_df['firmname'] != 'Undisclosed Firm']

        # 3) Parse dates (before deduplication)
        firm_df = parse_dates(firm_df, ['firmfounding'])
        
        # 4) Deduplicate by firmname with simple rules
        before = len(firm_df)
        firm_df = _deduplicate_firm_rows(firm_df)
        logger.info(f"Deduplicated firms: {before - len(firm_df)} rows removed")

        # 5) Merge firmtype2 from firm_check.csv
        if paths.FIRM_CHECK_FILE.exists() and not firm_df.empty and 'firmname' in firm_df.columns:
            firm_check = pd.read_csv(paths.FIRM_CHECK_FILE)
            cols = [c for c in ['firmname', 'firmtype2'] if c in firm_check.columns]
            if len(cols) == 2:
                firm_df = firm_df.merge(
                    firm_check[cols].drop_duplicates(subset=['firmname']),
                    on='firmname', how='left'
                )
                logger.info("Merged firmtype2 from firm_check.csv")

        # 6) Optimize dtypes
        firm_df = optimize_dtypes(firm_df)
        
        logger.info(f"Final firm data: {len(firm_df)} rows, {len(firm_df.columns)} columns")
        return firm_df
    except Exception as e:
        logger.error(f"Error loading firm data: {e}")
        return pd.DataFrame()


def load_fund_data() -> pd.DataFrame:
    """
    Load fund data from Excel
    
    Returns
    -------
    pd.DataFrame
        Fund data
    """
    if not paths.FUND_FILE.exists():
        logger.warning(f"Fund file not found: {paths.FUND_FILE}")
        return pd.DataFrame()
    
    logger.info(f"Loading fund file: {paths.FUND_FILE.name}")
    
    try:
        fund_df = pd.read_excel(paths.FUND_FILE)
        logger.info(f"Loaded fund data: {len(fund_df)} rows, {len(fund_df.columns)} columns")
        
        # Optimize dtypes
        fund_df = optimize_dtypes(fund_df)
        
        return fund_df
    except Exception as e:
        logger.error(f"Error loading fund data: {e}")
        return pd.DataFrame()


def parse_dates(df: pd.DataFrame, date_columns: List[str]) -> pd.DataFrame:
    """
    Parse date columns
    
    Parameters
    ----------
    df : pd.DataFrame
        Input dataframe
    date_columns : List[str]
        List of date column names
    
    Returns
    -------
    pd.DataFrame
        DataFrame with parsed dates
    """
    for col in date_columns:
        if col in df.columns:
            try:
                df[col] = pd.to_datetime(df[col], errors='coerce')
            except Exception as e:
                logger.warning(f"Error parsing date column {col}: {e}")
    
    return df


def optimize_dtypes(df: pd.DataFrame) -> pd.DataFrame:
    """
    Optimize DataFrame dtypes for memory efficiency
    
    Parameters
    ----------
    df : pd.DataFrame
        Input dataframe
    
    Returns
    -------
    pd.DataFrame
        DataFrame with optimized dtypes
    """
    for col, dtype in constants.DTYPE_OPTIMIZATION.items():
        if col in df.columns:
            try:
                if dtype == 'category':
                    df[col] = df[col].astype('category')
                else:
                    df[col] = pd.to_numeric(df[col], errors='coerce').astype(dtype)
            except Exception as e:
                logger.warning(f"Error converting {col} to {dtype}: {e}")
    
    return df


def load_all_data() -> Dict[str, pd.DataFrame]:
    """
    Load all data files
    
    Returns
    -------
    Dict[str, pd.DataFrame]
        Dictionary with keys: 'round', 'company', 'firm', 'fund'
    """
    logger.info("Loading all data files...")
    
    data = {
        'round': load_round_data(),
        'company': load_company_data(),
        'firm': load_firm_data(),
        'fund': load_fund_data()
    }
    
    # CRITICAL: Filter out "Undisclosed" entries FIRST (before any calculations)
    logger.info("🚨 CRITICAL PREPROCESSING: Filtering Undisclosed entries...")
    
    # Filter Undisclosed Firm from round
    if not data['round'].empty and 'firmname' in data['round'].columns:
        before_firm = len(data['round'])
        data['round'] = data['round'][data['round']['firmname'] != "Undisclosed Firm"]
        removed_firm = before_firm - len(data['round'])
        if removed_firm > 0:
            logger.info(f"  ❌ Removed {removed_firm} rows with 'Undisclosed Firm' ({removed_firm/before_firm*100:.2f}%)")
    
    # Filter Undisclosed Company from round
    if not data['round'].empty and 'comname' in data['round'].columns:
        before_com = len(data['round'])
        data['round'] = data['round'][data['round']['comname'] != "Undisclosed Company"]
        removed_com = before_com - len(data['round'])
        if removed_com > 0:
            logger.info(f"  ❌ Removed {removed_com} rows with 'Undisclosed Company' ({removed_com/before_com*100:.2f}%)")
    
    logger.info(f"✅ Undisclosed filtering complete: {len(data['round'])} rows remaining")
    
    # Merge firmtype2 into round data
    if not data['round'].empty and not data['firm'].empty:
        if 'firmtype2' in data['firm'].columns and 'firmname' in data['round'].columns:
            logger.info("Merging firmtype2 into round data...")
            initial_len = len(data['round'])
            data['round'] = data['round'].merge(
                data['firm'][['firmname', 'firmtype2']].drop_duplicates(subset=['firmname']),
                on='firmname',
                how='left'
            )
            logger.info(f"Merged firmtype2: {initial_len} -> {len(data['round'])} rows")
            
            # Check merge results
            firmtype2_null = data['round']['firmtype2'].isna().sum()
            if firmtype2_null > 0:
                logger.info(f"firmtype2 is null for {firmtype2_null} rows ({firmtype2_null/len(data['round'])*100:.1f}%)")
    
    # Print summary
    for name, df in data.items():
        if not df.empty:
            memory_mb = df.memory_usage(deep=True).sum() / 1024**2
            logger.info(f"{name}: {len(df)} rows, {len(df.columns)} columns, {memory_mb:.2f} MB")
        else:
            logger.warning(f"{name}: No data loaded")
    
    return data


def save_to_cache(data: Dict[str, pd.DataFrame], compression: str = 'snappy'):
    """
    Save loaded data to cache for faster loading next time
    
    Parameters
    ----------
    data : Dict[str, pd.DataFrame]
        Data dictionary
    compression : str, default='snappy'
        Compression method for parquet
    """
    for name, df in data.items():
        if not df.empty:
            cache_path = paths.get_cache_path(f"raw_{name}", 'parquet')
            df.to_parquet(cache_path, compression=compression)
            logger.info(f"Cached {name} data to {cache_path}")


def load_from_cache() -> Optional[Dict[str, pd.DataFrame]]:
    """
    Load data from cache
    
    Returns
    -------
    Optional[Dict[str, pd.DataFrame]]
        Cached data or None if cache doesn't exist
    """
    data_names = ['round', 'company', 'firm', 'fund']
    data = {}
    
    for name in data_names:
        cache_path = paths.get_cache_path(f"raw_{name}", 'parquet')
        if cache_path.exists():
            try:
                data[name] = pd.read_parquet(cache_path)
                logger.info(f"Loaded {name} from cache: {len(data[name])} rows")
            except Exception as e:
                logger.error(f"Error loading {name} from cache: {e}")
                return None
        else:
            return None
    
    return data


def load_data_with_cache(use_cache: bool = True, 
                         force_reload: bool = False) -> Dict[str, pd.DataFrame]:
    """
    Load data with caching support
    
    Parameters
    ----------
    use_cache : bool, default=True
        Try to load from cache
    force_reload : bool, default=False
        Force reload from files
    
    Returns
    -------
    Dict[str, pd.DataFrame]
        Data dictionary
    """
    if use_cache and not force_reload:
        cached_data = load_from_cache()
        if cached_data is not None:
            logger.info("Loaded data from cache")
            return cached_data
    
    # Load from raw files
    data = load_all_data()
    
    # Save to cache
    if use_cache:
        save_to_cache(data)
    
    return data


def filter_round_by_firm_registry(
    round_df: pd.DataFrame,
    firm_df: pd.DataFrame,
    mode: str = "strict",
    nation_codes: Optional[list] = None,
    firmname_col: str = "firmname",
    firmnation_col: str = "firmnation",
) -> pd.DataFrame:
    """
    Filter round data to firms present in firm registry.

    Parameters
    ----------
    round_df : pd.DataFrame
        Round dataset containing firmname
    firm_df : pd.DataFrame
        Firm registry
    mode : str, default "strict"
        - "strict": keep round rows where firmname exists in firm_df
        - "nation_select": first filter firm_df by firmnation in nation_codes,
          then keep round rows where firmname exists in that filtered set
    nation_codes : list or None
        List of nation codes (e.g., ["US", "CA"]) for nation_select mode
    firmname_col : str, default "firmname"
    firmnation_col : str, default "firmnation"

    Returns
    -------
    pd.DataFrame
        Filtered round dataframe
    """
    # Safety checks
    if round_df is None or firm_df is None or round_df.empty:
        return round_df
    if firmname_col not in round_df.columns:
        logger.warning(f"'{firmname_col}' not in round_df; skipping registry filter")
        return round_df
    if firmname_col not in firm_df.columns:
        logger.warning(f"'{firmname_col}' not in firm_df; skipping registry filter")
        return round_df

    before = len(round_df)

    # Build valid firm set
    valid_firm_series = firm_df[firmname_col].dropna().astype(str)

    if mode == "nation_select":
        if nation_codes is None or len(nation_codes) == 0:
            logger.warning("nation_select mode requires nation_codes; falling back to strict")
        elif firmnation_col not in firm_df.columns:
            logger.warning(f"'{firmnation_col}' not in firm_df; falling back to strict")
        else:
            nation_set = set(map(str, nation_codes))
            firm_df_ns = firm_df[firm_df[firmnation_col].astype(str).isin(nation_set)]
            valid_firm_series = firm_df_ns[firmname_col].dropna().astype(str)

    valid_firms = set(valid_firm_series.unique())

    # Apply filter
    mask = round_df[firmname_col].astype(str).isin(valid_firms)
    filtered = round_df.loc[mask].copy()

    removed = before - len(filtered)
    mode_info = f"mode={mode}"
    if mode == "nation_select" and nation_codes:
        mode_info += f", nation_codes={list(nation_codes)}"
    logger.info(f"Filtered round by firm registry ({mode_info}): removed {removed} of {before} rows")

    return filtered

