"""
Network centrality calculations

This module implements various centrality measures including:
- Degree centrality
- Betweenness centrality
- Power centrality (Bonacich)
- Constraint (structural holes)
"""

import pandas as pd
import numpy as np
import networkx as nx
from scipy.sparse.linalg import eigs
import logging
from typing import Optional, Dict, List

logger = logging.getLogger(__name__)


def compute_degree_centrality(G: nx.Graph, 
                             normalized: bool = False,
                             weighted: bool = False,
                             weight: str = 'weight') -> Dict[str, float]:
    """
    Compute degree centrality
    
    Parameters
    ----------
    G : nx.Graph
        Network
    normalized : bool, default=False
        If True, normalize by (n-1). If False, return raw degree count.
    weighted : bool, default=False
        If True, use edge weights (strength). If False, use simple degree count.
    weight : str, default='weight'
        Edge weight attribute name
    
    Returns
    -------
    Dict[str, float]
        Degree centrality values
    """
    if weighted:
        # Weighted degree (strength)
        degree_dict = dict(G.degree(weight=weight))
    else:
        # Unweighted degree
        degree_dict = dict(G.degree())
    
    if normalized and not weighted:
        # Normalize by (n-1) for unweighted
        n = G.number_of_nodes()
        if n > 1:
            degree_dict = {node: deg / (n - 1) for node, deg in degree_dict.items()}
    
    return degree_dict


def compute_betweenness_centrality(G: nx.Graph, 
                                  normalized: bool = True,
                                  weighted: bool = False,
                                  weight: str = 'weight',
                                  approximate: bool = True,
                                  k: int = 500) -> Dict[str, float]:
    """
    Compute betweenness centrality
    
    Parameters
    ----------
    G : nx.Graph
        Network
    normalized : bool, default=True
        Normalize by 2/((n-1)(n-2)) for undirected graphs
    weighted : bool, default=False
        If True, use edge weights. If False, treat all edges equally.
    weight : str, default='weight'
        Edge weight attribute name
    approximate : bool, default=True
        Use approximate algorithm for large networks
    k : int, default=500
        Number of nodes to sample for approximation
    
    Returns
    -------
    Dict[str, float]
        Betweenness centrality values
    """
    weight_param = weight if weighted else None
    
    if approximate and G.number_of_nodes() > k:
        return nx.betweenness_centrality(G, k=k, normalized=normalized, weight=weight_param)
    else:
        return nx.betweenness_centrality(G, normalized=normalized, weight=weight_param)


def compute_power_centrality(G: nx.Graph, 
                            beta: float = 0.5, 
                            normalized: bool = False,
                            weighted: bool = False,
                            weight: str = 'weight') -> Dict[str, float]:
    """
    Compute power centrality (Bonacich centrality)
    
    Parameters
    ----------
    G : nx.Graph
        Network
    beta : float, default=0.5
        Beta parameter (should be < 1/λ_max)
    normalized : bool, default=False
        If True, normalize by max value. If False, return raw values.
    weighted : bool, default=False
        If True, use edge weights. If False, use unweighted adjacency matrix.
    weight : str, default='weight'
        Edge weight attribute name
    
    Returns
    -------
    Dict[str, float]
        Power centrality values
    """
    if G.number_of_nodes() == 0:
        return {}
    
    try:
        # Get adjacency matrix (weighted or unweighted)
        if weighted:
            A = nx.adjacency_matrix(G, weight=weight)
        else:
            # Unweighted: ignore edge weights
            A = nx.adjacency_matrix(G, weight=None)
        
        # Get largest eigenvalue
        eigenvalues, _ = eigs(A, k=1, which='LM')
        lambda_max = np.abs(eigenvalues[0].real)
        
        # Adjust beta if needed
        if beta >= 1/lambda_max:
            beta = (1/lambda_max) * 0.99
        
        # Compute power centrality
        # c = (I - βA)^(-1) A 1
        n = G.number_of_nodes()
        I = np.eye(n)
        A_dense = A.todense()
        
        inv_matrix = np.linalg.inv(I - beta * A_dense)
        ones = np.ones(n)
        power_cent = inv_matrix @ A_dense @ ones
        
        # Normalize if requested
        if normalized:
            power_cent = power_cent / np.max(power_cent) if np.max(power_cent) > 0 else power_cent
        
        return dict(zip(G.nodes(), power_cent.flat))
        
    except Exception as e:
        logger.warning(f"Error computing power centrality: {e}")
        return {node: 0.0 for node in G.nodes()}


def compute_constraint(G: nx.Graph, 
                      weighted: bool = False,
                      weight: str = 'weight',
                      cap_at_one: bool = True) -> Dict[str, float]:
    """
    Compute constraint (Burt's structural holes measure)
    
    Parameters
    ----------
    G : nx.Graph
        Network
    weighted : bool, default=False
        If True, use edge weights. If False, treat all edges equally.
    weight : str, default='weight'
        Edge weight attribute name
    cap_at_one : bool, default=True
        If True, cap constraint values at 1.0 (theoretical maximum).
        Values > 1.0 can occur in complete cliques due to numerical precision.
    
    Returns
    -------
    Dict[str, float]
        Constraint values (capped at 1.0 if cap_at_one=True)
    """
    try:
        weight_param = weight if weighted else None
        constraint_dict = nx.constraint(G, weight=weight_param)
        
        # Cap values at 1.0 if requested
        if cap_at_one:
            constraint_dict = {node: min(val, 1.0) if val is not None else val 
                             for node, val in constraint_dict.items()}
        
        return constraint_dict
    except Exception as e:
        logger.warning(f"Error computing constraint: {e}")
        return {node: 0.0 for node in G.nodes()}


def compute_ego_density(G: nx.Graph) -> Dict[str, float]:
    """
    Compute ego network density (unweighted)
    
    Ego network density measures how densely connected a node's neighbors are.
    Density = (actual edges among neighbors) / (possible edges among neighbors)
    
    Parameters
    ----------
    G : nx.Graph
        Network
    
    Returns
    -------
    Dict[str, float]
        Ego network density values (0 to 1)
    """
    ego_density_dict = {}
    
    for node in G.nodes():
        # Get neighbors (ego network)
        neighbors = list(G.neighbors(node))
        
        if len(neighbors) <= 1:
            # Density undefined for 0 or 1 neighbor
            ego_density_dict[node] = 0.0
        else:
            # Create subgraph of neighbors (exclude ego)
            ego_subgraph = G.subgraph(neighbors)
            
            # Count actual edges (unweighted)
            actual_edges = ego_subgraph.number_of_edges()
            
            # Calculate possible edges
            n_neighbors = len(neighbors)
            possible_edges = n_neighbors * (n_neighbors - 1) / 2
            
            # Density
            density = actual_edges / possible_edges if possible_edges > 0 else 0.0
            ego_density_dict[node] = density
    
    return ego_density_dict


def compute_all_centralities(G: nx.Graph,
                            year: int,
                            compute_degree: bool = True,
                            compute_betweenness: bool = True,
                            compute_power: bool = True,
                            compute_constraint_measure: bool = True,
                            compute_ego_density_measure: bool = True,
                            use_weighted_degree: bool = False,
                            use_weighted_betweenness: bool = False,
                            use_weighted_power: bool = False,
                            use_weighted_constraint: bool = False,
                            weight_column: str = 'weight',
                            normalize_degree: bool = False,
                            normalize_betweenness: bool = True,
                            normalize_power: bool = True,
                            constraint_fill_na: bool = True,
                            constraint_fill_value: float = 0.0,
                            constraint_cap_at_one: bool = True,
                            power_beta_values: Optional[List[float]] = None,
                            compute_power_max: bool = True,
                            use_approximate_betweenness: bool = True) -> pd.DataFrame:
    """
    Compute all centrality measures for a network
    
    This implements the R function VC_centralities()
    
    Parameters
    ----------
    G : nx.Graph
        VC network
    year : int
        Year identifier
    compute_degree : bool, default=True
        Compute degree centrality
    compute_betweenness : bool, default=True
        Compute betweenness centrality
    compute_power : bool, default=True
        Compute power centrality
    compute_constraint_measure : bool, default=True
        Compute constraint
    compute_ego_density_measure : bool, default=True
        Compute ego network density
    use_weighted_degree : bool, default=False
        Use edge weights for degree centrality (False = unweighted)
    use_weighted_betweenness : bool, default=False
        Use edge weights for betweenness centrality (False = unweighted)
    use_weighted_power : bool, default=False
        Use edge weights for power centrality (False = unweighted)
    use_weighted_constraint : bool, default=False
        Use edge weights for constraint (False = unweighted)
    weight_column : str, default='weight'
        Edge weight attribute name
    normalize_degree : bool, default=False
        Normalize degree centrality (False = raw count)
    normalize_betweenness : bool, default=True
        Normalize betweenness centrality
    normalize_power : bool, default=True
        Normalize power centrality (True = normalized by max)
    constraint_fill_na : bool, default=True
        Fill NaN constraint values (for isolated nodes with degree=0)
    constraint_fill_value : float, default=0.0
        Value to fill NaN constraint (if constraint_fill_na=True)
    constraint_cap_at_one : bool, default=True
        Cap constraint at 1.0 (theoretical maximum for complete cliques)
    power_beta_values : Optional[List[float]], default=None
        List of beta values for power centrality
        Default: [0.0, 0.75, 0.99] relative to 1/λ_max
    compute_power_max : bool, default=True
        Compute pwr_max (1/lambda_max)
    use_approximate_betweenness : bool, default=True
        Use approximate betweenness for large networks
    
    Returns
    -------
    pd.DataFrame
        Centrality measures for all nodes
    """
    if G.number_of_nodes() == 0:
        return pd.DataFrame()
    
    if power_beta_values is None:
        power_beta_values = [0.0, 0.75, 0.99]
    
    # Initialize result dictionary
    result = {
        'firmname': list(G.nodes()),
        'year': [year] * G.number_of_nodes()
    }
    
    # Degree centrality
    if compute_degree:
        degree_cent = compute_degree_centrality(
            G, 
            normalized=normalize_degree,
            weighted=use_weighted_degree,
            weight=weight_column
        )
        result['dgr_cent'] = [degree_cent.get(node, 0) for node in G.nodes()]
    
    # Betweenness centrality
    if compute_betweenness:
        btw_cent = compute_betweenness_centrality(
            G, 
            normalized=normalize_betweenness,
            weighted=use_weighted_betweenness,
            weight=weight_column,
            approximate=use_approximate_betweenness
        )
        result['btw_cent'] = [btw_cent.get(node, 0) for node in G.nodes()]
    
    # Power centrality (multiple beta values)
    if compute_power:
        # Get max eigenvalue for beta calculation (use unweighted if requested)
        try:
            if use_weighted_power:
                A = nx.adjacency_matrix(G, weight=weight_column)
            else:
                A = nx.adjacency_matrix(G, weight=None)
            
            eigenvalues, _ = eigs(A, k=1, which='LM')
            lambda_max = np.abs(eigenvalues[0].real)
            
            # Add pwr_max (1/lambda_max) if requested
            if compute_power_max:
                result['pwr_max'] = [1/lambda_max] * G.number_of_nodes()
            
            for beta_rel in power_beta_values:
                if beta_rel == 0:
                    beta = 0
                else:
                    beta = (1/lambda_max) * beta_rel
                
                power_cent = compute_power_centrality(
                    G, 
                    beta, 
                    normalized=normalize_power,
                    weighted=use_weighted_power,
                    weight=weight_column
                )
                col_name = f'pwr_p{int(beta_rel*100)}'
                result[col_name] = [power_cent.get(node, 0) for node in G.nodes()]
                
        except Exception as e:
            logger.warning(f"Error computing power centralities: {e}")
            if compute_power_max:
                result['pwr_max'] = [0.0] * G.number_of_nodes()
            for beta_rel in power_beta_values:
                col_name = f'pwr_p{int(beta_rel*100)}'
                result[col_name] = [0.0] * G.number_of_nodes()
    
    # Constraint
    if compute_constraint_measure:
        constraint_vals = compute_constraint(
            G,
            weighted=use_weighted_constraint,
            weight=weight_column,
            cap_at_one=constraint_cap_at_one
        )
        result['constraint'] = [constraint_vals.get(node, np.nan) for node in G.nodes()]
    
    # Ego network density (always unweighted)
    if compute_ego_density_measure:
        ego_dens = compute_ego_density(G)
        result['ego_dens'] = [ego_dens.get(node, 0.0) for node in G.nodes()]
    
    # Create DataFrame
    df_result = pd.DataFrame(result)
    
    # Fill NaN constraint values if requested
    if compute_constraint_measure and constraint_fill_na:
        df_result['constraint'] = df_result['constraint'].fillna(constraint_fill_value)
    
    return df_result


def compute_centralities_for_networks(networks: Dict[int, nx.Graph],
                                     use_parallel: bool = True,
                                     n_jobs: int = -1,
                                     **kwargs) -> pd.DataFrame:
    """
    Compute centralities for multiple networks
    
    Parameters
    ----------
    networks : Dict[int, nx.Graph]
        Dictionary of {year: network}
    use_parallel : bool, default=True
        Use parallel processing
    n_jobs : int, default=-1
        Number of parallel jobs
    **kwargs : dict
        Additional arguments for compute_all_centralities
    
    Returns
    -------
    pd.DataFrame
        Centralities for all years
    """
    logger.info(f"Computing centralities for {len(networks)} networks...")
    
    if use_parallel and len(networks) > 1:
        from joblib import Parallel, delayed
        from tqdm import tqdm
        
        results = Parallel(n_jobs=n_jobs)(
            delayed(compute_all_centralities)(network, year, **kwargs)
            for year, network in tqdm(networks.items(), desc="Computing centralities")
        )
        
        centrality_df = pd.concat(results, ignore_index=True)
    else:
        from tqdm import tqdm
        results = []
        for year, network in tqdm(networks.items(), desc="Computing centralities"):
            df = compute_all_centralities(network, year, **kwargs)
            results.append(df)
        
        centrality_df = pd.concat(results, ignore_index=True)
    
    logger.info(f"Computed centralities: {len(centrality_df)} firm-year observations")
    
    return centrality_df

