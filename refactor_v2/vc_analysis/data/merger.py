"""
Data merging functions

This module provides functions to merge different datasets
(round, company, firm, fund) into integrated analysis datasets.
"""

import pandas as pd
import logging
from typing import Dict

logger = logging.getLogger(__name__)


def merge_round_company(round_df: pd.DataFrame, 
                       company_df: pd.DataFrame,
                       how: str = 'left') -> pd.DataFrame:
    """
    Merge round and company data
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Round data
    company_df : pd.DataFrame
        Company data
    how : str, default='left'
        Merge method
    
    Returns
    -------
    pd.DataFrame
        Merged data
    """
    logger.info(f"Merging round ({len(round_df)}) and company ({len(company_df)}) data...")
    
    merged = round_df.merge(
        company_df,
        on='comname',
        how=how,
        suffixes=('', '_comp')
    )
    
    logger.info(f"Merged result: {len(merged)} rows")
    return merged


def merge_with_firm(df: pd.DataFrame,
                   firm_df: pd.DataFrame,
                   how: str = 'left') -> pd.DataFrame:
    """
    Merge with firm data
    
    Parameters
    ----------
    df : pd.DataFrame
        Input data (with firmname column)
    firm_df : pd.DataFrame
        Firm data
    how : str, default='left'
        Merge method
    
    Returns
    -------
    pd.DataFrame
        Merged data
    """
    logger.info(f"Merging with firm data ({len(firm_df)} firms)...")
    
    merged = df.merge(
        firm_df,
        on='firmname',
        how=how,
        suffixes=('', '_firm')
    )
    
    logger.info(f"Merged result: {len(merged)} rows")
    return merged


def create_analysis_dataset(data: Dict[str, pd.DataFrame]) -> pd.DataFrame:
    """
    Create integrated analysis dataset
    
    Parameters
    ----------
    data : Dict[str, pd.DataFrame]
        Dictionary with 'round', 'company', 'firm' data
    
    Returns
    -------
    pd.DataFrame
        Integrated dataset
    """
    logger.info("Creating integrated analysis dataset...")
    
    # Start with round data
    df = data['round'].copy()
    
    # Merge with company
    if 'company' in data and not data['company'].empty:
        df = merge_round_company(df, data['company'])
    
    # Merge with firm
    if 'firm' in data and not data['firm'].empty:
        df = merge_with_firm(df, data['firm'])
    
    logger.info(f"Final integrated dataset: {len(df)} rows, {len(df.columns)} columns")
    
    return df

