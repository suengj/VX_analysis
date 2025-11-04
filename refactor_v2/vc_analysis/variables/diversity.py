"""Diversity variable calculations"""

import pandas as pd
from ..distance.industry import compute_blau_index


def calculate_portfolio_diversity(round_df: pd.DataFrame,
                                  industry_col: str = 'comindmnr') -> pd.DataFrame:
    """
    Calculate portfolio diversity using Blau index
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Investment round data with industry information
    industry_col : str, default='comindmnr'
        Industry column name
    
    Returns
    -------
    pd.DataFrame
        Portfolio diversity per VC-year
    """
    # Count investments by industry
    industry_counts = round_df.groupby(['firmname', 'year', industry_col]).size().unstack(fill_value=0)
    
    # Rename columns
    industry_counts.columns = [f'ind_{col}' for col in industry_counts.columns]
    industry_counts = industry_counts.reset_index()
    
    # Compute Blau index
    diversity_df = compute_blau_index(industry_counts, firm_col='firmname')
    
    return diversity_df

