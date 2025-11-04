"""Investment variable calculations"""

import pandas as pd


def calculate_investment_metrics(round_df: pd.DataFrame) -> pd.DataFrame:
    """
    Calculate investment metrics per VC-year
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Investment round data
    
    Returns
    -------
    pd.DataFrame
        Investment metrics
    """
    # Calculate investment amount
    round_df['InvestmentAmount'] = round_df[['RoundAmountDisclosedThou', 'RoundAmountEstimatedThou']].max(axis=1)
    
    # Aggregate by VC-year
    metrics = round_df.groupby(['firmname', 'year']).agg({
        'comname': 'count',  # Number of investments
        'InvestmentAmount': 'sum'  # Total investment amount
    }).reset_index()
    
    metrics.columns = ['firmname', 'year', 'numInvestments', 'totalInvested']
    
    return metrics

