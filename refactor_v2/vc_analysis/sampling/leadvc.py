"""
LeadVC identification

This module implements the algorithm to identify lead VCs
in investment rounds.
"""

import pandas as pd
import numpy as np
import logging

logger = logging.getLogger(__name__)


def identify_lead_vcs(round_df: pd.DataFrame,
                     first_round_weight: float = 3.0,
                     investment_ratio_weight: float = 2.0,
                     total_amount_weight: float = 1.0,
                     random_state: int = 123) -> pd.DataFrame:
    """
    Identify lead VCs for each company
    
    This implements the R function leadVC_identifier()
    
    Criteria (priority order):
    1. FirstRound: Invested in the first round
    2. InvestmentRatio: Highest investment frequency in the company
    3. TotalAmount: Highest total investment amount
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Investment round data
    first_round_weight : float, default=3.0
        Weight for first round criterion
    investment_ratio_weight : float, default=2.0
        Weight for investment ratio criterion
    total_amount_weight : float, default=1.0
        Weight for total amount criterion
    random_state : int, default=123
        Random seed for tie-breaking
    
    Returns
    -------
    pd.DataFrame
        LeadVC data with columns: comname, leadVC
    """
    df = round_df.copy()
    
    # Calculate company-level statistics
    df['comInvested'] = df.groupby('comname')['firmname'].transform('count')
    
    # Identify first round
    df['minRound'] = df.groupby('comname')['RoundNumber'].transform('min')
    df['FirstRound'] = (df['RoundNumber'] == df['minRound']).astype(int)
    
    # Calculate firm-company investment frequency
    df['firm_comInvested'] = df.groupby(['firmname', 'comname']).cumcount() + 1
    df['firm_inv_ratio'] = df['firm_comInvested'] / df['comInvested']
    
    # Calculate investment amount
    df['RoundAmount'] = np.maximum(
        df['RoundAmountDisclosedThou'].fillna(0),
        df['RoundAmountEstimatedThou'].fillna(0)
    )
    df['TotalAmountPerCompany'] = df.groupby(['firmname', 'comname'])['RoundAmount'].transform('sum')
    
    # Calculate LeadVC scores
    df['leadVC1'] = (df['FirstRound'] == 1).astype(int)
    df['leadVC2'] = (df['firm_inv_ratio'] == df.groupby('comname')['firm_inv_ratio'].transform('max')).astype(int)
    df['leadVC3'] = (df['TotalAmountPerCompany'] == df.groupby('comname')['TotalAmountPerCompany'].transform('max')).astype(int)
    
    df['leadVCsum'] = (
        df['leadVC1'] * first_round_weight +
        df['leadVC2'] * investment_ratio_weight +
        df['leadVC3'] * total_amount_weight
    )
    
    # Select lead VC per company
    def select_leadvc(group):
        # Priority 1: FirstRound investors
        first_round_investors = group[group['FirstRound'] == 1]
        
        if len(first_round_investors) == 0:
            # No first round data, select by total score
            max_score = group['leadVCsum'].max()
            candidates = group[group['leadVCsum'] == max_score]
        else:
            # Among first round investors, select by total score
            max_score = first_round_investors['leadVCsum'].max()
            candidates = first_round_investors[first_round_investors['leadVCsum'] == max_score]
        
        # Random tie-breaking
        if len(candidates) > 1:
            return candidates.sample(n=1, random_state=random_state).iloc[0]
        else:
            return candidates.iloc[0]
    
    leadvc_df = df.groupby('comname').apply(select_leadvc).reset_index(drop=True)
    leadvc_df = leadvc_df[['comname', 'firmname']].rename(columns={'firmname': 'leadVC'})
    
    logger.info(f"Identified {len(leadvc_df)} lead VCs")
    
    return leadvc_df

