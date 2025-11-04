"""Parallel processing utilities"""

from joblib import Parallel, delayed
from tqdm import tqdm


def parallel_apply(func, items, n_jobs=-1, desc="Processing", **kwargs):
    """
    Apply function to items in parallel
    
    Parameters
    ----------
    func : callable
        Function to apply
    items : list
        List of items to process
    n_jobs : int, default=-1
        Number of parallel jobs
    desc : str, default="Processing"
        Description for progress bar
    **kwargs : dict
        Additional arguments for func
    
    Returns
    -------
    list
        Results
    """
    results = Parallel(n_jobs=n_jobs)(
        delayed(func)(item, **kwargs)
        for item in tqdm(items, desc=desc)
    )
    
    return results

