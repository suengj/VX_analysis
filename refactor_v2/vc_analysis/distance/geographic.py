"""
Geographic distance calculations

This module provides functions to compute geographic distances
based on ZIP codes using the Haversine formula.
"""

import pandas as pd
import numpy as np
from math import radians, cos, sin, asin, sqrt
from typing import Optional, Dict, List
import logging
from joblib import Parallel, delayed
from tqdm import tqdm

logger = logging.getLogger(__name__)

# Try to import uszipcode for ZIP code to coordinates conversion
try:
    from uszipcode import SearchEngine, SimpleZipcode
    HAS_USZIPCODE = True
except ImportError:
    HAS_USZIPCODE = False
    logger.warning("uszipcode library not found. ZIP code to coordinates conversion will be limited.")


def haversine_distance(lat1, lon1, lat2, lon2, unit='km'):
    """
    Calculate Haversine distance between two points
    
    Supports both scalar and vectorized (numpy array) inputs.
    
    Parameters
    ----------
    lat1 : float or array-like
        Latitude of first point(s)
    lon1 : float or array-like
        Longitude of first point(s)
    lat2 : float or array-like
        Latitude of second point(s)
    lon2 : float or array-like
        Longitude of second point(s)
    unit : str, default='km'
        Unit of distance ('km' or 'miles')
    
    Returns
    -------
    float or array
        Distance in specified unit
    """
    # Convert to numpy arrays for vectorized operations
    lat1 = np.asarray(lat1)
    lon1 = np.asarray(lon1)
    lat2 = np.asarray(lat2)
    lon2 = np.asarray(lon2)
    
    # Handle NaN values
    mask = ~(np.isnan(lat1) | np.isnan(lon1) | np.isnan(lat2) | np.isnan(lon2))
    result = np.full_like(lat1, np.nan, dtype=float)
    
    if not mask.any():
        return result if lat1.ndim > 0 else result.item()
    
    # Convert to radians
    lat1_rad = np.radians(lat1[mask])
    lon1_rad = np.radians(lon1[mask])
    lat2_rad = np.radians(lat2[mask])
    lon2_rad = np.radians(lon2[mask])
    
    # Haversine formula (vectorized)
    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad
    a = np.sin(dlat/2)**2 + np.cos(lat1_rad) * np.cos(lat2_rad) * np.sin(dlon/2)**2
    c = 2 * np.arcsin(np.sqrt(a))
    
    # Earth radius in km
    R = 6371.0
    
    distance = R * c
    
    if unit == 'miles':
        distance = distance * 0.621371
    
    result[mask] = distance
    
    return result if lat1.ndim > 0 else result.item()


def normalize_zip_code(zip_code) -> Optional[str]:
    """
    Normalize ZIP code to 5-digit string format
    
    Handles:
    - Leading zeros (e.g., '01234' -> '01234')
    - String conversion (e.g., 1234 -> '01234')
    - NaN/None handling
    
    Parameters
    ----------
    zip_code : str, int, float, or None
        ZIP code in various formats
    
    Returns
    -------
    str or None
        Normalized 5-digit ZIP code string, or None if invalid
    """
    if pd.isna(zip_code) or zip_code is None:
        return None
    
    # Handle float/int: convert 1234.0 -> 1234 first to avoid decimal point issues
    if isinstance(zip_code, float):
        # Check if it's a whole number (e.g., 1234.0)
        if zip_code.is_integer():
            zip_code = int(zip_code)
        else:
            # Non-integer float (e.g., 1234.5) - invalid ZIP code
            return None
    
    # Convert to string and strip whitespace
    zip_str = str(zip_code).strip()
    
    # Remove non-digit characters (e.g., ZIP+4 format: "12345-6789")
    zip_str = ''.join(filter(str.isdigit, zip_str))
    
    # Handle empty string
    if not zip_str:
        return None
    
    # Pad with leading zeros to 5 digits (e.g., 1234 -> 01234)
    zip_str = zip_str.zfill(5)
    
    # Validate length (should be 5 digits)
    if len(zip_str) != 5:
        return None
    
    return zip_str


def zip_to_coordinates(zip_code, zipcode_db: Optional[Dict[str, Dict]] = None) -> tuple:
    """
    Convert ZIP code to latitude and longitude coordinates
    
    Parameters
    ----------
    zip_code : str, int, or None
        ZIP code
    zipcode_db : dict, optional
        Pre-loaded ZIP code database {zip: {'lat': float, 'lng': float}}
        If None, uses uszipcode library
    
    Returns
    -------
    tuple
        (latitude, longitude) or (None, None) if not found
    """
    zip_normalized = normalize_zip_code(zip_code)
    
    if zip_normalized is None:
        return (None, None)
    
    # Use pre-loaded database if available
    if zipcode_db is not None:
        if zip_normalized in zipcode_db:
            coords = zipcode_db[zip_normalized]
            return (coords.get('lat'), coords.get('lng'))
        return (None, None)
    
    # Use uszipcode library if available
    if HAS_USZIPCODE:
        try:
            search = SearchEngine()
            result = search.by_zipcode(zip_normalized)
            if result and result.lat and result.lng:
                return (result.lat, result.lng)
        except Exception as e:
            logger.debug(f"Error looking up ZIP {zip_normalized}: {e}")
    
    return (None, None)


def build_zipcode_database(firm_df: pd.DataFrame,
                          company_df: pd.DataFrame,
                          firmzip_col: str = 'firmzip',
                          comzip_col: str = 'comzip') -> Dict[str, Dict]:
    """
    Build ZIP code to coordinates database from firm and company data
    
    Parameters
    ----------
    firm_df : pd.DataFrame
        Firm data with firmzip column
    company_df : pd.DataFrame
        Company data with comzip column
    firmzip_col : str
        Column name for firm ZIP code
    comzip_col : str
        Column name for company ZIP code
    
    Returns
    -------
    dict
        Dictionary mapping ZIP codes to coordinates {zip: {'lat': float, 'lng': float}}
    """
    logger.info("Building ZIP code to coordinates database...")
    
    zipcode_db = {}
    
    # Collect unique ZIP codes
    unique_zips = set()
    
    if firmzip_col in firm_df.columns:
        firm_zips = firm_df[firmzip_col].dropna().unique()
        unique_zips.update(firm_zips)
        logger.info(f"  Found {len(firm_zips)} unique firm ZIP codes")
    
    if comzip_col in company_df.columns:
        com_zips = company_df[comzip_col].dropna().unique()
        unique_zips.update(com_zips)
        logger.info(f"  Found {len(com_zips)} unique company ZIP codes")
    
    logger.info(f"  Total unique ZIP codes: {len(unique_zips)}")
    
    # Convert ZIP codes to coordinates
    if HAS_USZIPCODE:
        search = SearchEngine()
        converted = 0
        failed = 0
        failed_samples = []  # Store samples of failed ZIP codes for debugging
        
        for zip_code in unique_zips:
            zip_normalized = normalize_zip_code(zip_code)
            if zip_normalized is None:
                failed += 1
                if len(failed_samples) < 10:  # Store first 10 failed samples
                    failed_samples.append((zip_code, "normalization_failed"))
                continue
            
            # Skip if already in database
            if zip_normalized in zipcode_db:
                continue
            
            try:
                result = search.by_zipcode(zip_normalized)
                if result and result.lat and result.lng:
                    zipcode_db[zip_normalized] = {
                        'lat': result.lat,
                        'lng': result.lng
                    }
                    converted += 1
                else:
                    failed += 1
                    if len(failed_samples) < 10:
                        failed_samples.append((zip_code, zip_normalized, "not_found_in_uszipcode"))
            except Exception as e:
                logger.debug(f"Error looking up ZIP {zip_normalized}: {e}")
                failed += 1
                if len(failed_samples) < 10:
                    failed_samples.append((zip_code, zip_normalized, f"exception: {str(e)[:50]}"))
        
        logger.info(f"  Converted: {converted:,}, Failed: {failed:,} ({failed/(converted+failed)*100:.1f}%)")
        if failed_samples:
            logger.info(f"  Sample failed ZIP codes (original -> normalized -> reason):")
            for sample in failed_samples[:5]:
                logger.info(f"    {sample}")
    else:
        logger.warning("  uszipcode library not available. Cannot build ZIP code database.")
    
    return zipcode_db


def calculate_vc_company_distances(round_df: pd.DataFrame,
                                  firm_df: pd.DataFrame,
                                  company_df: pd.DataFrame,
                                  zipcode_db: Optional[Dict[str, Dict]] = None,
                                  firm_col: str = 'firmname',
                                  comname_col: str = 'comname',
                                  year_col: str = 'year',
                                  firmzip_col: str = 'firmzip',
                                  comzip_col: str = 'comzip',
                                  amount_col: Optional[str] = None) -> pd.DataFrame:
    """
    Calculate geographic distances between VC firms and their invested companies (firm-year level)
    
    Computes multiple statistics:
    - Mean distance
    - Min distance
    - Max distance
    - Median distance (recommended: robust to outliers)
    - Weighted mean distance (if amount_col provided)
    - Standard deviation (recommended: distance dispersion)
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Round data with firmname, comname, year
    firm_df : pd.DataFrame
        Firm data with firmname, firmzip
    company_df : pd.DataFrame
        Company data with comname, comzip
    zipcode_db : dict, optional
        Pre-loaded ZIP code database
    firm_col : str
        Column name for firm identifier
    comname_col : str
        Column name for company identifier
    year_col : str
        Column name for year
    firmzip_col : str
        Column name for firm ZIP code
    comzip_col : str
        Column name for company ZIP code
    amount_col : str, optional
        Column name for investment amount (for weighted mean)
    
    Returns
    -------
    pd.DataFrame
        Firm-year data with distance statistics
        Columns: firmname, year, geo_dist_company_mean, geo_dist_company_min,
        geo_dist_company_max, geo_dist_company_median, geo_dist_company_weighted_mean,
        geo_dist_company_std
    """
    logger.info("=" * 80)
    logger.info("Calculating VC-Company Geographic Distances (firm-year level)...")
    logger.info("=" * 80)
    
    # Build ZIP code database if not provided
    if zipcode_db is None:
        zipcode_db = build_zipcode_database(firm_df, company_df, firmzip_col, comzip_col)
    
    # Merge ZIP codes
    round_with_zips = round_df.merge(
        firm_df[[firm_col, firmzip_col]].drop_duplicates(subset=[firm_col]),
        on=firm_col,
        how='left'
    ).merge(
        company_df[[comname_col, comzip_col]].drop_duplicates(subset=[comname_col]),
        on=comname_col,
        how='left'
    )
    
    # Convert ZIP codes to coordinates (parallelized)
    logger.info("Converting ZIP codes to coordinates (parallelized)...")
    
    def _convert_zip_batch(zip_codes, zipcode_db):
        """Convert a batch of ZIP codes to coordinates"""
        results = []
        for zip_code in zip_codes:
            lat, lng = zip_to_coordinates(zip_code, zipcode_db)
            results.append((lat, lng))
        return results
    
    # Parallel ZIP code conversion
    from vc_analysis.config.parameters import ParallelParameters
    n_jobs = ParallelParameters.n_jobs
    
    # Split into chunks for parallel processing
    chunk_size = max(1000, len(round_with_zips) // (n_jobs * 4) if n_jobs > 0 else len(round_with_zips) // 4)
    
    # Process firm ZIP codes
    firm_zips = round_with_zips[firmzip_col].tolist()
    firm_coords = Parallel(n_jobs=n_jobs)(
        delayed(_convert_zip_batch)(
            firm_zips[i:i+chunk_size], zipcode_db
        )
        for i in range(0, len(firm_zips), chunk_size)
    )
    firm_coords = [coord for batch in firm_coords for coord in batch]
    round_with_zips['firm_lat'] = [c[0] for c in firm_coords]
    round_with_zips['firm_lng'] = [c[1] for c in firm_coords]
    
    # Process company ZIP codes
    com_zips = round_with_zips[comzip_col].tolist()
    com_coords = Parallel(n_jobs=n_jobs)(
        delayed(_convert_zip_batch)(
            com_zips[i:i+chunk_size], zipcode_db
        )
        for i in range(0, len(com_zips), chunk_size)
    )
    com_coords = [coord for batch in com_coords for coord in batch]
    round_with_zips['com_lat'] = [c[0] for c in com_coords]
    round_with_zips['com_lng'] = [c[1] for c in com_coords]
    
    # Calculate distances (vectorized)
    logger.info("Calculating distances (vectorized)...")
    round_with_zips['distance'] = haversine_distance(
        round_with_zips['firm_lat'].values,
        round_with_zips['firm_lng'].values,
        round_with_zips['com_lat'].values,
        round_with_zips['com_lng'].values
    )
    
    # Diagnose ZIP code conversion issues
    logger.info("Diagnosing ZIP code conversion...")
    total_rows = len(round_with_zips)
    missing_firmzip = round_with_zips[firmzip_col].isna().sum()
    missing_comzip = round_with_zips[comzip_col].isna().sum()
    missing_firm_coords = round_with_zips['firm_lat'].isna().sum()
    missing_com_coords = round_with_zips['com_lat'].isna().sum()
    
    logger.info(f"  Total rows: {total_rows:,}")
    logger.info(f"  Missing firmzip: {missing_firmzip:,} ({missing_firmzip/total_rows*100:.1f}%)")
    logger.info(f"  Missing comzip: {missing_comzip:,} ({missing_comzip/total_rows*100:.1f}%)")
    logger.info(f"  Missing firm coordinates: {missing_firm_coords:,} ({missing_firm_coords/total_rows*100:.1f}%)")
    logger.info(f"  Missing company coordinates: {missing_com_coords:,} ({missing_com_coords/total_rows*100:.1f}%)")
    
    # Sample ZIP codes that failed conversion
    if missing_firm_coords > 0:
        failed_firm_samples = round_with_zips[
            round_with_zips['firm_lat'].isna() & round_with_zips[firmzip_col].notna()
        ][firmzip_col].head(5).tolist()
        if failed_firm_samples:
            logger.info(f"  Sample firm ZIP codes that failed conversion: {failed_firm_samples}")
    
    if missing_com_coords > 0:
        failed_com_samples = round_with_zips[
            round_with_zips['com_lat'].isna() & round_with_zips[comzip_col].notna()
        ][comzip_col].head(5).tolist()
        if failed_com_samples:
            logger.info(f"  Sample company ZIP codes that failed conversion: {failed_com_samples}")
    
    # Remove rows with NaN distances before aggregation
    # This ensures we only aggregate valid distances
    valid_distances = round_with_zips[round_with_zips['distance'].notna()].copy()
    
    logger.info(f"  Valid distances: {len(valid_distances):,} / {len(round_with_zips):,} ({len(valid_distances)/len(round_with_zips)*100:.1f}%)")
    
    # Get all firm-year combinations (for left merge later)
    all_firm_years = round_with_zips[[firm_col, year_col]].drop_duplicates()
    
    # Aggregate by firm-year
    logger.info("Aggregating by firm-year...")
    
    # Calculate weighted mean if amount column provided
    if amount_col and amount_col in valid_distances.columns:
        # Calculate weighted mean distance (only for valid distances)
        valid_distances['weighted_dist'] = (
            valid_distances['distance'] * valid_distances[amount_col]
        )
        # Aggregate with weighted mean (excluding median)
        result = valid_distances.groupby([firm_col, year_col]).agg({
            'distance': ['mean', 'min', 'max', 'std'],
            'weighted_dist': 'sum',
            amount_col: 'sum'
        }).reset_index()
        
        # Flatten column names
        result.columns = [firm_col, year_col, 'geo_dist_company_mean', 'geo_dist_company_min',
                         'geo_dist_company_max', 'geo_dist_company_std',
                         'weighted_dist_sum', f'{amount_col}_sum']
        
        # Calculate weighted mean
        result['geo_dist_company_weighted_mean'] = (
            result['weighted_dist_sum'] / result[f'{amount_col}_sum']
        )
        
        # Drop intermediate columns
        result = result.drop(columns=['weighted_dist_sum', f'{amount_col}_sum'])
    else:
        # Aggregate without weighted mean (excluding median)
        result = valid_distances.groupby([firm_col, year_col]).agg({
            'distance': ['mean', 'min', 'max', 'std']
        }).reset_index()
        
        # Flatten column names
        result.columns = [firm_col, year_col, 'geo_dist_company_mean', 'geo_dist_company_min',
                         'geo_dist_company_max', 'geo_dist_company_std']
        
        # Add weighted mean as NaN
        result['geo_dist_company_weighted_mean'] = np.nan
    
    # Merge with all firm-years to preserve rows with no valid distances
    result = all_firm_years.merge(result, on=[firm_col, year_col], how='left')
    
    logger.info(f"✅ Calculated distances for {len(result)} firm-year observations")
    logger.info("=" * 80)
    
    return result


def calculate_vc_copartner_distances(round_df: pd.DataFrame,
                                     firm_df: pd.DataFrame,
                                     zipcode_db: Optional[Dict[str, Dict]] = None,
                                     firm_col: str = 'firmname',
                                     comname_col: str = 'comname',
                                     year_col: str = 'year',
                                     firmzip_col: str = 'firmzip',
                                     amount_col: Optional[str] = None) -> pd.DataFrame:
    """
    Calculate geographic distances between VC firms and their co-investment partners (firm-year level)
    
    For each firm-year, finds all co-investment partners (firms that invested in the same company
    in the same round) and calculates distance statistics.
    
    Computes multiple statistics:
    - Mean distance
    - Min distance
    - Max distance
    - Median distance (recommended: robust to outliers)
    - Weighted mean distance (if amount_col provided)
    - Standard deviation (recommended: distance dispersion)
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Round data with firmname, comname, year
    firm_df : pd.DataFrame
        Firm data with firmname, firmzip
    zipcode_db : dict, optional
        Pre-loaded ZIP code database
    firm_col : str
        Column name for firm identifier
    comname_col : str
        Column name for company identifier
    year_col : str
        Column name for year
    firmzip_col : str
        Column name for firm ZIP code
    amount_col : str, optional
        Column name for investment amount (for weighted mean)
    
    Returns
    -------
    pd.DataFrame
        Firm-year data with distance statistics
        Columns: firmname, year, geo_dist_copartner_mean, geo_dist_copartner_min,
        geo_dist_copartner_max, geo_dist_copartner_median, geo_dist_copartner_weighted_mean,
        geo_dist_copartner_std
    """
    logger.info("=" * 80)
    logger.info("Calculating VC-Co-Partner Geographic Distances (firm-year level)...")
    logger.info("=" * 80)
    
    # Build ZIP code database if not provided
    if zipcode_db is None:
        zipcode_db = build_zipcode_database(firm_df, pd.DataFrame(), firmzip_col, 'comzip')
    
    # Merge firm ZIP codes
    round_with_firmzip = round_df.merge(
        firm_df[[firm_col, firmzip_col]].drop_duplicates(subset=[firm_col]),
        on=firm_col,
        how='left'
    )
    
    # Convert firm ZIP codes to coordinates (parallelized)
    logger.info("Converting firm ZIP codes to coordinates (parallelized)...")
    
    def _convert_zip_batch(zip_codes, zipcode_db):
        """Convert a batch of ZIP codes to coordinates"""
        results = []
        for zip_code in zip_codes:
            lat, lng = zip_to_coordinates(zip_code, zipcode_db)
            results.append((lat, lng))
        return results
    
    # Parallel ZIP code conversion
    from vc_analysis.config.parameters import ParallelParameters
    n_jobs = ParallelParameters.n_jobs
    
    # Split into chunks for parallel processing
    firm_zips = round_with_firmzip[firmzip_col].tolist()
    chunk_size = max(1000, len(firm_zips) // (n_jobs * 4) if n_jobs > 0 else len(firm_zips) // 4)
    
    firm_coords = Parallel(n_jobs=n_jobs)(
        delayed(_convert_zip_batch)(
            firm_zips[i:i+chunk_size], zipcode_db
        )
        for i in range(0, len(firm_zips), chunk_size)
    )
    firm_coords = [coord for batch in firm_coords for coord in batch]
    round_with_firmzip['firm_lat'] = [c[0] for c in firm_coords]
    round_with_firmzip['firm_lng'] = [c[1] for c in firm_coords]
    
    # Find co-investment partners (firms investing in same company in same round)
    logger.info("Identifying co-investment partners...")
    
    # Create round identifier (company + year)
    round_with_firmzip['round_id'] = (
        round_with_firmzip[comname_col].astype(str) + '_' +
        round_with_firmzip[year_col].astype(str)
    )
    
    # Vectorized approach: Calculate all co-partner distances at once
    logger.info("Calculating co-partner distances (vectorized)...")
    
    # Step 1: For each round, create all firm pairs (self-join)
    logger.info("  Step 1: Creating co-partner pairs...")
    
    # Remove rows with missing coordinates
    valid_rounds = round_with_firmzip[
        round_with_firmzip['firm_lat'].notna() & 
        round_with_firmzip['firm_lng'].notna()
    ].copy()
    
    # Self-join on round_id to create all pairs
    # Left side: focal firm, Right side: partner firm
    pairs = valid_rounds.merge(
        valid_rounds,
        on='round_id',
        suffixes=('_focal', '_partner'),
        how='inner'
    )
    
    # Remove self-pairs (focal == partner)
    pairs = pairs[pairs[f'{firm_col}_focal'] != pairs[f'{firm_col}_partner']]
    
    logger.info(f"  Created {len(pairs):,} co-partner pairs")
    
    # Step 2: Vectorized distance calculation
    logger.info("  Step 2: Calculating distances (vectorized)...")
    pairs['distance'] = haversine_distance(
        pairs['firm_lat_focal'].values,
        pairs['firm_lng_focal'].values,
        pairs['firm_lat_partner'].values,
        pairs['firm_lng_partner'].values
    )
    
    # Step 3: Prepare result structure (focal firm-year level)
    copartner_distances = []
    
    # Get amount column if provided
    amount_col_focal = f'{amount_col}_focal' if amount_col and f'{amount_col}_focal' in pairs.columns else None
    
    for (focal_firm, focal_year), group in pairs.groupby([f'{firm_col}_focal', f'{year_col}_focal']):
        distances = group['distance'].values
        
        # Get amount for weighted mean (use partner amount or default to 1)
        if amount_col_focal and amount_col_focal in group.columns:
            amounts = group[amount_col_focal].fillna(1).values
        else:
            amounts = np.ones(len(distances))
        
        # Store all distances for this focal firm-year
        for dist, amt in zip(distances, amounts):
            copartner_distances.append({
                firm_col: focal_firm,
                year_col: focal_year,
                'distance': dist,
                'amount': amt
            })
    
    logger.info(f"  Calculated {len(copartner_distances):,} co-partner distances")
    
    if not copartner_distances:
        logger.warning("No co-partner distances found. Returning empty DataFrame.")
        return pd.DataFrame({
            firm_col: [],
            year_col: [],
            'geo_dist_copartner_mean': [],
            'geo_dist_copartner_min': [],
            'geo_dist_copartner_max': [],
            'geo_dist_copartner_std': [],
            'geo_dist_copartner_weighted_mean': []
        })
    
    copartner_df = pd.DataFrame(copartner_distances)
    
    # Remove rows with NaN distances before aggregation
    valid_copartner = copartner_df[copartner_df['distance'].notna()].copy()
    
    logger.info(f"  Valid co-partner distances: {len(valid_copartner):,} / {len(copartner_df):,} ({len(valid_copartner)/len(copartner_df)*100:.1f}%)")
    
    # Get all firm-year combinations (for left merge later)
    all_firm_years_cp = copartner_df[[firm_col, year_col]].drop_duplicates()
    
    # Aggregate by firm-year
    logger.info("Aggregating by firm-year...")
    
    # Calculate weighted mean if amount column provided
    if amount_col:
        # Calculate weighted mean distance (only for valid distances)
        valid_copartner['weighted_dist'] = valid_copartner['distance'] * valid_copartner['amount']
        # Aggregate with weighted mean (excluding median)
        result = valid_copartner.groupby([firm_col, year_col]).agg({
            'distance': ['mean', 'min', 'max', 'std'],
            'weighted_dist': 'sum',
            'amount': 'sum'
        }).reset_index()
        
        # Flatten column names
        result.columns = [firm_col, year_col, 'geo_dist_copartner_mean', 'geo_dist_copartner_min',
                         'geo_dist_copartner_max', 'geo_dist_copartner_std',
                         'weighted_dist_sum', 'amount_sum']
        
        # Calculate weighted mean
        result['geo_dist_copartner_weighted_mean'] = (
            result['weighted_dist_sum'] / result['amount_sum']
        )
        
        # Drop intermediate columns
        result = result.drop(columns=['weighted_dist_sum', 'amount_sum'])
    else:
        # Aggregate without weighted mean (excluding median)
        result = valid_copartner.groupby([firm_col, year_col]).agg({
            'distance': ['mean', 'min', 'max', 'std']
        }).reset_index()
        
        # Flatten column names
        result.columns = [firm_col, year_col, 'geo_dist_copartner_mean', 'geo_dist_copartner_min',
                         'geo_dist_copartner_max', 'geo_dist_copartner_std']
        
        # Add weighted mean as NaN
        result['geo_dist_copartner_weighted_mean'] = np.nan
    
    # Merge with all firm-years to preserve rows with no valid distances
    result = all_firm_years_cp.merge(result, on=[firm_col, year_col], how='left')
    
    logger.info(f"✅ Calculated co-partner distances for {len(result)} firm-year observations")
    logger.info("=" * 80)
    
    return result


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

