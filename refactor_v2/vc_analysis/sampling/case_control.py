"""
Case-control sampling

This module implements 1:n case-control sampling for partnership analysis.
"""

import pandas as pd
import numpy as np
import logging

logger = logging.getLogger(__name__)


def case_control_sampling(round_df: pd.DataFrame,
                         leadvc_df: pd.DataFrame,
                         ratio: int = 10,
                         replacement: bool = True,
                         random_state: int = 123) -> pd.DataFrame:
    """
    Perform 1:n case-control sampling
    
    This implements the R function VC_sampling_opt1()
    
    For each lead VC-company pair:
    - Cases: Realized partnerships (coVCs who actually invested)
    - Controls: Unrealized partnerships (sampled from potential partners)
    - Ratio: n controls per 1 case
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Investment round data
    leadvc_df : pd.DataFrame
        Lead VC data (comname, leadVC)
    ratio : int, default=10
        Sampling ratio (controls per case)
    replacement : bool, default=True
        Sample with replacement
    random_state : int, default=123
        Random seed
    
    Returns
    -------
    pd.DataFrame
        Sampled data with realized column (1=case, 0=control)
    """
    np.random.seed(random_state)
    
    # Merge to get leadVC-company pairs
    df = round_df.merge(leadvc_df, on='comname')
    
    # Get quarter information
    if 'quarter' not in df.columns:
        df['quarter'] = df['year'].astype(str) + 'Q' + ((df['rnddate'].dt.month - 1) // 3 + 1).astype(str)
    
    results = []
    
    # Group by quarter, leadVC, and company
    for (quarter, leadVC, comname), group in df.groupby(['quarter', 'leadVC', 'comname']):
        # Get realized coVCs
        realized_covcs = group[group['firmname'] != leadVC]['firmname'].unique()
        
        # Get potential coVCs (all VCs active in that quarter)
        potential_covcs = df[df['quarter'] == quarter]['firmname'].unique()
        potential_covcs = [vc for vc in potential_covcs if vc != leadVC]
        
        # Create realized ties
        for coVC in realized_covcs:
            results.append({
                'quarter': quarter,
                'leadVC': leadVC,
                'coVC': coVC,
                'comname': comname,
                'realized': 1
            })
        
        # Sample unrealized ties
        unrealized_covcs = [vc for vc in potential_covcs if vc not in realized_covcs]
        n_sample = len(realized_covcs) * ratio
        
        if len(unrealized_covcs) > 0:
            sampled_covcs = np.random.choice(
                unrealized_covcs,
                size=min(n_sample, len(unrealized_covcs)) if not replacement else n_sample,
                replace=replacement
            )
            
            for coVC in sampled_covcs:
                results.append({
                    'quarter': quarter,
                    'leadVC': leadVC,
                    'coVC': coVC,
                    'comname': comname,
                    'realized': 0
                })
    
    sampled_df = pd.DataFrame(results)
    
    logger.info(f"Sampled data: {len(sampled_df)} rows "
                f"({(sampled_df['realized']==1).sum()} cases, "
                f"{(sampled_df['realized']==0).sum()} controls)")
    
    return sampled_df

