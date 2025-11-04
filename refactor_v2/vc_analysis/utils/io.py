"""Input/output utilities"""

import pandas as pd
import logging
from pathlib import Path

logger = logging.getLogger(__name__)


def save_parquet(df: pd.DataFrame, 
                path: Path,
                compression: str = 'snappy',
                engine: str = 'pyarrow'):
    """
    Save DataFrame to Parquet file
    
    Parameters
    ----------
    df : pd.DataFrame
        Data to save
    path : Path
        Output path
    compression : str, default='snappy'
        Compression method
    engine : str, default='pyarrow'
        Parquet engine
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    df.to_parquet(path, compression=compression, engine=engine)
    
    size_mb = path.stat().st_size / 1024**2
    logger.info(f"Saved {len(df)} rows to {path} ({size_mb:.2f} MB)")


def load_parquet(path: Path, engine: str = 'pyarrow') -> pd.DataFrame:
    """
    Load DataFrame from Parquet file
    
    Parameters
    ----------
    path : Path
        Input path
    engine : str, default='pyarrow'
        Parquet engine
    
    Returns
    -------
    pd.DataFrame
        Loaded data
    """
    df = pd.read_parquet(path, engine=engine)
    logger.info(f"Loaded {len(df)} rows from {path}")
    return df

