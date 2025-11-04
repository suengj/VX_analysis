"""
Geographic distance calculations

This module provides functions to compute geographic distances
based on ZIP codes using the Haversine formula.
"""

import pandas as pd
import numpy as np
from math import radians, cos, sin, asin, sqrt
from typing import Optional
import logging

logger = logging.getLogger(__name__)


def haversine_distance(lat1, lon1, lat2, lon2, unit='km'):
    """
    Calculate Haversine distance between two points
    
    Parameters
    ----------
    lat1, lon1 : float
        First point coordinates
    lat2, lon2 : float
        Second point coordinates
    unit : str, default='km'
        'km' or 'miles'
    
    Returns
    -------
    float
        Distance
    """
    # Convert to radians
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    
    # Haversine formula
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a))
    
    # Earth radius
    r = 6371 if unit == 'km' else 3959
    
    return c * r


def compute_geographic_distances(df: pd.DataFrame,
                                firm1_col: str = 'vc1',
                                firm2_col: str = 'vc2',
                                lat_col: str = 'lat',
                                lon_col: str = 'lng') -> pd.DataFrame:
    """
    Compute geographic distances between VC pairs
    
    Parameters
    ----------
    df : pd.DataFrame
        DataFrame with VC pairs and coordinates
    firm1_col : str, default='vc1'
        First VC column
    firm2_col : str, default='vc2'
        Second VC column
    lat_col : str, default='lat'
        Latitude column suffix
    lon_col : str, default='lng'
        Longitude column suffix
    
    Returns
    -------
    pd.DataFrame
        DataFrame with geographic distances
    """
    df = df.copy()
    
    # Compute distances
    df['geo_distance'] = df.apply(
        lambda row: haversine_distance(
            row[f'{firm1_col}_{lat_col}'],
            row[f'{firm1_col}_{lon_col}'],
            row[f'{firm2_col}_{lat_col}'],
            row[f'{firm2_col}_{lon_col}']
        ),
        axis=1
    )
    
    return df

