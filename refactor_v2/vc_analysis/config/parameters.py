"""
Analysis parameters configuration

This module defines all tunable parameters for the analysis pipeline.
Users can modify these parameters to experiment with different settings.
"""

from dataclasses import dataclass, field
from typing import Optional, List
from . import constants


@dataclass
class NetworkParameters:
    """Parameters for network construction"""
    time_window: int = constants.NETWORK_CONSTANTS['DEFAULT_TIME_WINDOW']
    edge_cutpoint: Optional[int] = constants.NETWORK_CONSTANTS['DEFAULT_EDGE_CUTPOINT']
    min_nodes: int = constants.NETWORK_CONSTANTS['MIN_NODES']
    min_edges: int = constants.NETWORK_CONSTANTS['MIN_EDGES']
    use_weighted: bool = True
    directed: bool = False


@dataclass
class CentralityParameters:
    """Parameters for centrality calculation"""
    compute_degree: bool = True
    compute_betweenness: bool = True
    compute_power: bool = True
    compute_constraint: bool = True
    compute_ego_density: bool = True  # Compute ego network density
    
    # Weighted vs Unweighted network for centrality calculations
    use_weighted_degree: bool = False  # Use edge weights for degree (default: unweighted)
    use_weighted_betweenness: bool = False  # Use edge weights for betweenness (default: unweighted)
    use_weighted_power: bool = False  # Use edge weights for power centrality (default: unweighted)
    use_weighted_constraint: bool = False  # Use edge weights for constraint (default: unweighted)
    weight_column: str = 'weight'  # Edge weight attribute name
    
    # Normalization settings for each centrality measure
    normalize_degree: bool = False  # Use raw degree count
    normalize_betweenness: bool = False  # Raw betweenness (default: False)
    normalize_power: bool = True  # Normalized power centrality (default: True)
    normalize_constraint: bool = False  # Use raw constraint value
    
    # Constraint NaN handling (for isolated nodes with degree=0)
    constraint_fill_na: bool = True  # Fill NaN with 0 (default: True)
    constraint_fill_value: float = 0.0  # Value to fill NaN (if constraint_fill_na=True)
    constraint_cap_at_one: bool = True  # Cap constraint at 1.0 (theoretical max)

    # Post-merge handling of centrality missingness
    # Recommendation: keep missing by default and add an in_network dummy
    create_in_network_dummy: bool = True
    fill_missing_centrality_as_zero: bool = False  # If True, zero-fill selected measures for rows not in network
    zero_fill_columns: List[str] = field(default_factory=list)  # e.g., ['dgr_cent', 'constraint']
    
    # Power centrality beta values
    power_beta_values: List[float] = field(default_factory=lambda: [0.0, 0.75, 0.99])
    compute_power_max: bool = True  # Compute pwr_max (1/lambda_max)
    
    # Approximate betweenness (for large networks)
    use_approximate_betweenness: bool = True
    betweenness_k: int = 500  # Number of nodes to sample
    
    # Parallel processing
    use_parallel: bool = True
    n_jobs: int = constants.N_JOBS_DEFAULT


@dataclass
class SamplingParameters:
    """Parameters for case-control sampling"""
    ratio: int = constants.ANALYSIS_CONSTANTS['DEFAULT_SAMPLING_RATIO']
    replacement: bool = True  # With replacement for unrealized ties
    random_state: int = constants.RANDOM_SEED
    
    # LeadVC identification criteria weights
    first_round_weight: float = 3.0
    investment_ratio_weight: float = 2.0
    total_amount_weight: float = 1.0


@dataclass
class FilterParameters:
    """Parameters for data filtering"""
    us_only: bool = constants.GEOGRAPHIC_CONSTANTS['US_ONLY']
    min_year: int = constants.ANALYSIS_CONSTANTS['MIN_YEAR']
    max_year: int = constants.ANALYSIS_CONSTANTS['MAX_YEAR']
    min_firm_age: int = constants.ANALYSIS_CONSTANTS['MIN_FIRM_AGE']
    
    # Exclude specific VC types
    exclude_vc_types: List[str] = field(default_factory=lambda: ['Angel', 'Individual'])
    
    # Exclude undisclosed data
    exclude_undisclosed: bool = True
    
    # Minimum investment amount (in thousands)
    min_investment_amount: Optional[float] = None


@dataclass
class DistanceParameters:
    """Parameters for distance calculations"""
    # Network distance
    max_network_distance: int = 10
    infinite_distance_value: int = 9999
    
    # Geographic distance
    distance_unit: str = 'km'  # 'km' or 'miles'
    
    # Industry distance (Blau index)
    min_investments_for_blau: int = 1


@dataclass
class PerformanceParameters:
    """Parameters for performance variable calculation"""
    exit_window: int = constants.ANALYSIS_CONSTANTS['DEFAULT_EXIT_WINDOW']
    
    # Exit types to include
    include_ipo: bool = True
    include_ma: bool = True
    
    # Cumulative performance
    cumulative: bool = True


@dataclass
class ImprintingParameters:
    """Parameters for imprinting analysis"""
    imprinting_period: int = constants.ANALYSIS_CONSTANTS['DEFAULT_IMPRINTING_PERIOD']
    
    # Initial ties identification
    initial_ties_time_window: int = 1  # Use 1 year for initial ties
    
    # Partner centrality aggregation
    partner_degree_agg: str = 'sum'  # 'sum' or 'mean'
    partner_other_agg: str = 'mean'  # For betweenness, power, constraint


@dataclass
class ParallelParameters:
    """Parameters for parallel processing"""
    n_jobs: int = constants.N_JOBS_DEFAULT
    backend: str = 'loky'  # 'loky', 'threading', 'multiprocessing'
    verbose: int = 10  # Verbosity level for joblib
    
    # Memory management
    max_nbytes: Optional[str] = '1G'  # Max size for memmapping
    temp_folder: Optional[str] = None


@dataclass
class IOParameters:
    """Parameters for input/output operations"""
    # Parquet settings
    parquet_compression: str = constants.PARQUET_COMPRESSION
    parquet_engine: str = 'pyarrow'
    
    # Pickle settings
    pickle_compression: str = constants.PICKLE_COMPRESSION
    
    # Chunk size for reading large files
    chunk_size: int = 100000
    
    # Cache settings
    use_cache: bool = True
    force_recompute: bool = False


@dataclass
class PipelineParameters:
    """Complete pipeline parameters"""
    network: NetworkParameters = field(default_factory=NetworkParameters)
    centrality: CentralityParameters = field(default_factory=CentralityParameters)
    sampling: SamplingParameters = field(default_factory=SamplingParameters)
    filter: FilterParameters = field(default_factory=FilterParameters)
    distance: DistanceParameters = field(default_factory=DistanceParameters)
    performance: PerformanceParameters = field(default_factory=PerformanceParameters)
    imprinting: ImprintingParameters = field(default_factory=ImprintingParameters)
    parallel: ParallelParameters = field(default_factory=ParallelParameters)
    io: IOParameters = field(default_factory=IOParameters)
    
    def to_dict(self):
        """Convert parameters to dictionary"""
        return {
            'network': self.network.__dict__,
            'centrality': self.centrality.__dict__,
            'sampling': self.sampling.__dict__,
            'filter': self.filter.__dict__,
            'distance': self.distance.__dict__,
            'performance': self.performance.__dict__,
            'imprinting': self.imprinting.__dict__,
            'parallel': self.parallel.__dict__,
            'io': self.io.__dict__
        }


# Default pipeline parameters
DEFAULT_PARAMS = PipelineParameters()


# Quick parameter presets
QUICK_TEST_PARAMS = PipelineParameters(
    filter=FilterParameters(min_year=2015, max_year=2020),  # Test with 5 years only
    centrality=CentralityParameters(use_parallel=False, n_jobs=1),
    parallel=ParallelParameters(n_jobs=1)
)

FULL_ANALYSIS_PARAMS = PipelineParameters(
    filter=FilterParameters(min_year=1980, max_year=2022),
    centrality=CentralityParameters(use_parallel=True, n_jobs=-1),
    parallel=ParallelParameters(n_jobs=-1)
)


def get_params(preset='default'):
    """Get parameter preset"""
    if preset == 'default':
        return DEFAULT_PARAMS
    elif preset == 'quick_test':
        return QUICK_TEST_PARAMS
    elif preset == 'full_analysis':
        return FULL_ANALYSIS_PARAMS
    else:
        raise ValueError(f"Unknown preset: {preset}")

