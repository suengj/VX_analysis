"""Data validation utilities"""

import pandas as pd
import logging

logger = logging.getLogger(__name__)


def check_required_columns(df: pd.DataFrame, required_columns: list) -> bool:
    """
    Check if DataFrame has all required columns
    
    Parameters
    ----------
    df : pd.DataFrame
        Input dataframe
    required_columns : list
        List of required column names
    
    Returns
    -------
    bool
        True if all columns present
    """
    missing = set(required_columns) - set(df.columns)
    
    if missing:
        logger.error(f"Missing required columns: {missing}")
        return False
    
    return True


def check_missing_values(df: pd.DataFrame, columns: list, max_rate: float = 0.5) -> bool:
    """
    Check missing value rates
    
    Parameters
    ----------
    df : pd.DataFrame
        Input dataframe
    columns : list
        Columns to check
    max_rate : float, default=0.5
        Maximum acceptable missing rate
    
    Returns
    -------
    bool
        True if all columns pass
    """
    for col in columns:
        if col in df.columns:
            missing_rate = df[col].isna().sum() / len(df)
            if missing_rate > max_rate:
                logger.warning(f"Column {col} has {missing_rate:.1%} missing values")
                return False
    
    return True

