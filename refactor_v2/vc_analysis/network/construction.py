"""
Network construction functions

This module implements the VC network construction algorithm,
converting VC-Company bipartite networks to VC-VC one-mode networks.
"""

import pandas as pd
import numpy as np
import networkx as nx
from networkx.algorithms import bipartite
import logging
from typing import Optional, Tuple

from ..config import parameters

logger = logging.getLogger(__name__)


def create_event_identifier(df: pd.DataFrame,
                            company_col: str = 'comname',
                            year_col: str = 'year') -> pd.DataFrame:
    """
    Create event identifier for bipartite network
    
    Parameters
    ----------
    df : pd.DataFrame
        Investment data
    company_col : str, default='comname'
        Company name column
    year_col : str, default='year'
        Year column
    
    Returns
    -------
    pd.DataFrame
        Data with event column
    """
    df = df.copy()
    df['event'] = df[company_col].astype(str) + '_' + df[year_col].astype(str)
    return df


def construct_bipartite_network(edgelist: pd.DataFrame,
                                firm_col: str = 'firmname',
                                event_col: str = 'event') -> nx.Graph:
    """
    Construct bipartite network (VC-Event)
    
    Parameters
    ----------
    edgelist : pd.DataFrame
        Edge list with firm and event columns
    firm_col : str, default='firmname'
        Firm column name
    event_col : str, default='event'
        Event column name
    
    Returns
    -------
    nx.Graph
        Bipartite network
    """
    # Create bipartite graph
    B = nx.Graph()
    
    # Get unique firms and events
    firms = edgelist[firm_col].unique()
    events = edgelist[event_col].unique()
    
    # Add nodes with bipartite attribute
    B.add_nodes_from(firms, bipartite=0)
    B.add_nodes_from(events, bipartite=1)
    
    # Add edges
    edges = list(zip(edgelist[firm_col], edgelist[event_col]))
    B.add_edges_from(edges)
    
    return B


def project_to_onemode(bipartite_network: nx.Graph,
                      node_set: int = 0) -> nx.Graph:
    """
    Project bipartite network to one-mode network
    
    Parameters
    ----------
    bipartite_network : nx.Graph
        Bipartite network
    node_set : int, default=0
        Which node set to project (0=firms, 1=events)
    
    Returns
    -------
    nx.Graph
        One-mode projected network
    """
    # Get nodes of specified set
    nodes = {n for n, d in bipartite_network.nodes(data=True) 
             if d.get('bipartite') == node_set}
    
    # Project
    G = bipartite.weighted_projected_graph(bipartite_network, nodes)
    
    return G


def filter_edges_by_weight(G: nx.Graph, min_weight: int = 1) -> nx.Graph:
    """
    Filter edges by weight threshold
    
    Parameters
    ----------
    G : nx.Graph
        Network with edge weights
    min_weight : int, default=1
        Minimum edge weight
    
    Returns
    -------
    nx.Graph
        Filtered network
    """
    if min_weight <= 1:
        return G
    
    # Remove edges below threshold
    edges_to_remove = [(u, v) for u, v, d in G.edges(data=True) 
                       if d.get('weight', 0) < min_weight]
    
    G_filtered = G.copy()
    G_filtered.remove_edges_from(edges_to_remove)
    
    # Remove isolated nodes
    isolated_nodes = list(nx.isolates(G_filtered))
    G_filtered.remove_nodes_from(isolated_nodes)
    
    logger.info(f"Edge filtering (weight>={min_weight}): "
                f"{G.number_of_edges()} → {G_filtered.number_of_edges()} edges, "
                f"{G.number_of_nodes()} → {G_filtered.number_of_nodes()} nodes")
    
    return G_filtered


def construct_vc_network(round_df: pd.DataFrame,
                        year: int,
                        time_window: Optional[int] = 5,
                        edge_cutpoint: Optional[int] = None,
                        firm_col: str = 'firmname',
                        event_col: str = 'event',
                        year_col: str = 'year') -> nx.Graph:
    """
    Construct VC network for a specific year
    
    This implements the R function VC_matrix():
    1. Filter investments by time window
    2. Create bipartite network (VC-Event)
    3. Project to one-mode network (VC-VC)
    4. Filter edges by weight threshold (optional)
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Investment round data
    year : int
        Target year
    time_window : Optional[int], default=5
        Time window in years (uses year-time_window to year-1)
        If None, uses only year-1
    edge_cutpoint : Optional[int], default=None
        Minimum edge weight threshold
    firm_col : str, default='firmname'
        Firm column name
    event_col : str, default='event'
        Event column name
    year_col : str, default='year'
        Year column name
    
    Returns
    -------
    nx.Graph
        VC network
    """
    # Filter by time window
    if time_window is not None:
        edgelist = round_df[
            (round_df[year_col] >= year - time_window) & 
            (round_df[year_col] <= year - 1)
        ].copy()
    else:
        edgelist = round_df[round_df[year_col] == year - 1].copy()
    
    if len(edgelist) == 0:
        logger.warning(f"No data for year {year}")
        return nx.Graph()
    
    # Create event identifier if not present
    if event_col not in edgelist.columns:
        edgelist = create_event_identifier(edgelist)
        event_col = 'event'
    
    # Construct bipartite network
    bipartite_net = construct_bipartite_network(edgelist, firm_col, event_col)
    
    # Project to one-mode
    vc_network = project_to_onemode(bipartite_net, node_set=0)
    
    # Filter edges
    if edge_cutpoint is not None and edge_cutpoint > 1:
        vc_network = filter_edges_by_weight(vc_network, edge_cutpoint)
    
    logger.info(f"Year {year}: {vc_network.number_of_nodes()} VCs, "
                f"{vc_network.number_of_edges()} edges")
    
    return vc_network


def construct_networks_for_years(round_df: pd.DataFrame,
                                 years: list,
                                 time_window: int = 5,
                                 edge_cutpoint: Optional[int] = None,
                                 use_parallel: bool = True,
                                 n_jobs: int = -1) -> dict:
    """
    Construct VC networks for multiple years
    
    Parameters
    ----------
    round_df : pd.DataFrame
        Investment round data
    years : list
        List of years
    time_window : int, default=5
        Time window
    edge_cutpoint : Optional[int], default=None
        Edge weight threshold
    use_parallel : bool, default=True
        Use parallel processing
    n_jobs : int, default=-1
        Number of parallel jobs
    
    Returns
    -------
    dict
        Dictionary of {year: network}
    """
    logger.info(f"Constructing networks for {len(years)} years...")
    
    if use_parallel and len(years) > 1:
        from joblib import Parallel, delayed
        from tqdm import tqdm
        
        results = Parallel(n_jobs=n_jobs)(
            delayed(construct_vc_network)(round_df, year, time_window, edge_cutpoint)
            for year in tqdm(years, desc="Constructing networks")
        )
        
        networks = dict(zip(years, results))
    else:
        from tqdm import tqdm
        networks = {}
        for year in tqdm(years, desc="Constructing networks"):
            networks[year] = construct_vc_network(round_df, year, time_window, edge_cutpoint)
    
    return networks

