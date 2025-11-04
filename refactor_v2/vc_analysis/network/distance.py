"""Network distance calculations"""

import pandas as pd
import networkx as nx
import logging
from typing import Dict

logger = logging.getLogger(__name__)


def compute_network_distances(G: nx.Graph, max_distance: int = 10) -> pd.DataFrame:
    """
    Compute pairwise network distances
    
    Parameters
    ----------
    G : nx.Graph
        Network
    max_distance : int, default=10
        Maximum distance to compute
    
    Returns
    -------
    pd.DataFrame
        Distance matrix in long format
    """
    if G.number_of_nodes() == 0:
        return pd.DataFrame()
    
    # Compute all pairs shortest path lengths
    distances = dict(nx.all_pairs_shortest_path_length(G, cutoff=max_distance))
    
    # Convert to DataFrame
    data = []
    nodes = list(G.nodes())
    
    for source in nodes:
        source_dists = distances.get(source, {})
        for target in nodes:
            if source != target:
                dist = source_dists.get(target, 9999)  # 9999 for infinite distance
                data.append({
                    'vc1': source,
                    'vc2': target,
                    'distance': dist
                })
    
    df = pd.DataFrame(data)
    
    # Create categorical distance variables
    df['dist1'] = (df['distance'] == 1).astype(int)
    df['dist2'] = (df['distance'] == 2).astype(int)
    df['dist3plus'] = (df['distance'] > 2).astype(int)
    
    return df

