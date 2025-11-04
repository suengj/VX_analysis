"""
VC Network Analysis: Python Preprocessing Pipeline

This package provides efficient Python implementations for VC network analysis,
replacing the original R preprocessing code with vectorized and parallelized operations.

Main modules:
- config: Configuration management (paths, constants, parameters)
- data: Data loading, merging, and filtering
- network: Network construction and centrality calculation
- distance: Distance calculations (network, geographic, industry)
- sampling: LeadVC identification and case-control sampling
- variables: Variable creation (performance, investment, diversity)
- utils: Utility functions (parallel processing, validation, I/O)
"""

__version__ = "0.1.0"
__author__ = "Research Team"

# Import main components for easy access
from .config import paths, constants, parameters
from .data import loader, merger, filter as data_filter
from .network import construction, centrality, distance as network_distance
from .distance import geographic, industry
from .sampling import leadvc, case_control
from .variables import performance, investment, diversity
from .utils import parallel, validation, io

__all__ = [
    'paths',
    'constants',
    'parameters',
    'loader',
    'merger',
    'data_filter',
    'construction',
    'centrality',
    'network_distance',
    'geographic',
    'industry',
    'leadvc',
    'case_control',
    'performance',
    'investment',
    'diversity',
    'parallel',
    'validation',
    'io',
]

