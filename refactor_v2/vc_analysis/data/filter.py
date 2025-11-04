"""
Data filtering functions

This module provides functions to filter data based on various criteria.
"""

import pandas as pd
import numpy as np
import logging
from typing import List, Optional

from ..config import parameters

logger = logging.getLogger(__name__)


def filter_by_country(df: pd.DataFrame, 
                     country: str = 'United States',
                     firm_column: str = 'firmnation',
                     company_column: Optional[str] = 'comnation') -> pd.DataFrame:
    """
    Filter by country
    
    Parameters
    ----------
    df : pd.DataFrame
        Input data
    country : str, default='United States'
        Country name
    firm_column : str, default='firmnation'
        Firm country column
    company_column : Optional[str], default='comnation'
        Company country column (optional)
    
    Returns
    -------
    pd.DataFrame
        Filtered data
    """
    initial_len = len(df)
    
    # Filter firm country
    if firm_column in df.columns:
        df = df[df[firm_column] == country]
    
    # Filter company country
    if company_column and company_column in df.columns:
        df = df[df[company_column] == country]
    
    logger.info(f"Country filter ({country}): {initial_len} → {len(df)} rows ({len(df)/initial_len*100:.1f}%)")
    return df.copy()


def filter_by_year_range(df: pd.DataFrame,
                        min_year: int,
                        max_year: int,
                        year_column: str = 'year') -> pd.DataFrame:
    """
    Filter by year range
    
    Parameters
    ----------
    df : pd.DataFrame
        Input data
    min_year : int
        Minimum year
    max_year : int
        Maximum year
    year_column : str, default='year'
        Year column name
    
    Returns
    -------
    pd.DataFrame
        Filtered data
    """
    initial_len = len(df)
    
    if year_column in df.columns:
        df = df[(df[year_column] >= min_year) & (df[year_column] <= max_year)]
    
    logger.info(f"Year filter ({min_year}-{max_year}): {initial_len} → {len(df)} rows")
    return df.copy()


def filter_by_vc_type(df: pd.DataFrame,
                     exclude_types: List[str],
                     type_column: str = 'firmtype',
                     exclude_null: bool = True) -> pd.DataFrame:
    """
    Filter by VC type
    
    Parameters
    ----------
    df : pd.DataFrame
        Input data
    exclude_types : List[str]
        List of VC types to exclude (e.g., ['Angel', 'Other'])
    type_column : str, default='firmtype'
        VC type column name
    exclude_null : bool, default=True
        Whether to exclude null values
    
    Returns
    -------
    pd.DataFrame
        Filtered data
    """
    initial_len = len(df)
    
    if type_column in df.columns:
        # Exclude specified types
        mask = ~df[type_column].isin(exclude_types)
        
        # Exclude null values if requested
        if exclude_null:
            mask = mask & df[type_column].notna()
        
        df = df[mask]
    
    exclude_info = f"{exclude_types}"
    if exclude_null:
        exclude_info += " + Null"
    
    logger.info(f"VC type filter (exclude {exclude_info}): {initial_len} → {len(df)} rows ({len(df)/initial_len*100:.1f}%)")
    return df.copy()


def filter_by_firm_age(df: pd.DataFrame,
                      min_age: int = 0,
                      age_column: str = 'firmage') -> pd.DataFrame:
    """
    Filter by firm age
    
    Parameters
    ----------
    df : pd.DataFrame
        Input data
    min_age : int, default=0
        Minimum firm age
    age_column : str, default='firmage'
        Firm age column name
    
    Returns
    -------
    pd.DataFrame
        Filtered data
    """
    initial_len = len(df)
    
    # Calculate firm age if not present
    if age_column not in df.columns:
        if 'firmfounding' in df.columns and 'year' in df.columns:
            df[age_column] = df['year'] - pd.to_datetime(df['firmfounding']).dt.year
    
    if age_column in df.columns:
        df = df[df[age_column] >= min_age]
    
    logger.info(f"Firm age filter (>= {min_age}): {initial_len} → {len(df)} rows")
    return df.copy()


def remove_duplicates(df: pd.DataFrame,
                     subset: Optional[List[str]] = None,
                     keep: str = 'first') -> pd.DataFrame:
    """
    Remove duplicate rows
    
    Parameters
    ----------
    df : pd.DataFrame
        Input data
    subset : Optional[List[str]], default=None
        Columns to consider for duplicate check
    keep : str, default='first'
        Which duplicates to keep
    
    Returns
    -------
    pd.DataFrame
        De-duplicated data
    """
    initial_len = len(df)
    
    df = df.drop_duplicates(subset=subset, keep=keep)
    
    logger.info(f"Duplicate removal: {initial_len} → {len(df)} rows ({initial_len - len(df)} duplicates)")
    return df.copy()


def remove_missing_values(df: pd.DataFrame,
                         required_columns: List[str],
                         how: str = 'any') -> pd.DataFrame:
    """
    Remove rows with missing values in required columns
    
    Parameters
    ----------
    df : pd.DataFrame
        Input data
    required_columns : List[str]
        List of required columns
    how : str, default='any'
        'any' or 'all'
    
    Returns
    -------
    pd.DataFrame
        Filtered data
    """
    initial_len = len(df)
    
    existing_columns = [col for col in required_columns if col in df.columns]
    df = df.dropna(subset=existing_columns, how=how)
    
    logger.info(f"Missing value removal ({existing_columns}): {initial_len} → {len(df)} rows")
    return df.copy()


def apply_standard_filters(df: pd.DataFrame,
                          params: parameters.FilterParameters) -> pd.DataFrame:
    """
    Apply standard filtering pipeline
    
    Parameters
    ----------
    df : pd.DataFrame
        Input data
    params : FilterParameters
        Filter parameters
    
    Returns
    -------
    pd.DataFrame
        Filtered data
    """
    logger.info(f"Applying standard filters to {len(df)} rows...")
    
    # US only
    if params.us_only:
        df = filter_by_country(df, 'United States')
    
    # Year range
    df = filter_by_year_range(df, params.min_year, params.max_year)
    
    # VC type
    if params.exclude_vc_types:
        df = filter_by_vc_type(df, params.exclude_vc_types)
    
    # Firm age
    df = filter_by_firm_age(df, params.min_firm_age)
    
    # Remove duplicates
    df = remove_duplicates(df)
    
    logger.info(f"Final filtered data: {len(df)} rows")
    
    return df

