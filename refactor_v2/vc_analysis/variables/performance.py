"""
Performance variable calculations

This module calculates exit-related performance metrics:
- Exit numbers (IPO, M&A, total)
- Success rates
"""

import pandas as pd
import logging

logger = logging.getLogger(__name__)


def calculate_exit_numbers(round_df: pd.DataFrame,
                          company_df: pd.DataFrame,
                          year_col: str = 'year',
                          exit_window: int = 5) -> pd.DataFrame:
    """
    Calculate exit numbers for VCs
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Investment round data
    company_df : pd.DataFrame
        Company data with exit information
    year_col : str, default='year'
        Year column
    exit_window : int, default=5
        Number of years to look ahead for exits
    
    Returns
    -------
    pd.DataFrame
        Exit numbers per VC-year
    """
    # Merge round and company data
    df = round_df.merge(company_df[['comname', 'comsitu', 'date_sit']], on='comname')
    
    # Extract exit year
    df['exit_year'] = pd.to_datetime(df['date_sit']).dt.year
    
    # Calculate exit flags
    df['ipoExit'] = df['comsitu'].isin(['Went Public', 'Public']).astype(int)
    df['MnAExit'] = df['comsitu'].isin(['Merger', 'Acquisition', 'Acquired']).astype(int)
    df['anyExit'] = (df['ipoExit'] + df['MnAExit'] > 0).astype(int)
    
    # Calculate cumulative exits within window
    result = []
    
    for (firm, year), group in df.groupby(['firmname', year_col]):
        # Count exits within window
        exit_data = group[
            (group['exit_year'] >= year) &
            (group['exit_year'] <= year + exit_window)
        ]
        
        result.append({
            'firmname': firm,
            'year': year,
            'exitNum': exit_data['anyExit'].sum(),
            'ipoNum': exit_data['ipoExit'].sum(),
            'MnANum': exit_data['MnAExit'].sum()
        })
    
    return pd.DataFrame(result)

