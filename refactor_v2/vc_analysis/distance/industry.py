"""
Industry distance calculations

This module provides functions to compute industry diversity
using the Blau index and industry distances.
"""

import pandas as pd
import numpy as np
import logging

logger = logging.getLogger(__name__)


def compute_blau_index(df: pd.DataFrame,
                      firm_col: str = 'firmname',
                      industry_cols: list = None) -> pd.DataFrame:
    """
    Compute Blau index for industry diversity
    
    Blau Index = 1 - Σ(p_i^2)
    where p_i is the proportion of investments in industry i
    
    Parameters
    ----------
    df : pd.DataFrame
        DataFrame with investment counts by industry
    firm_col : str, default='firmname'
        Firm identifier column
    industry_cols : list, default=None
        List of industry columns
    
    Returns
    -------
    pd.DataFrame
        DataFrame with Blau index
    """
    df = df.copy()
    
    if industry_cols is None:
        # Auto-detect industry columns
        industry_cols = [col for col in df.columns if col.startswith('ind_')]
    
    # Calculate total investments
    df['total_inv'] = df[industry_cols].sum(axis=1)
    
    # Calculate proportions
    for col in industry_cols:
        df[f'{col}_prop'] = df[col] / df['total_inv']
    
    # Calculate Blau index
    prop_cols = [f'{col}_prop' for col in industry_cols]
    df['blau_index'] = 1 - (df[prop_cols] ** 2).sum(axis=1)
    
    return df[[firm_col, 'total_inv', 'blau_index']]

