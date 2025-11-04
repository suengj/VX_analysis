"""
VC Network Analysis: Quick Start Example

This script demonstrates the basic usage of the VC analysis Python package.
"""

import sys
sys.path.append('..')

import pandas as pd
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)

# Import vc_analysis modules
from vc_analysis.data import loader, filter as data_filter
from vc_analysis.network import construction, centrality
from vc_analysis.config import parameters, paths
from vc_analysis.utils import io

print("=" * 60)
print("VC NETWORK ANALYSIS: QUICK START")
print("=" * 60)

# 1. Configure Parameters
print("\n1. Configuring parameters...")
params = parameters.QUICK_TEST_PARAMS  # Use quick test for faster execution
print(f"   Year range: {params.filter.min_year} - {params.filter.max_year}")

# 2. Load Data
print("\n2. Loading data...")
data = loader.load_data_with_cache(
    use_cache=True,
    force_reload=False,
    parallel=True,
    n_jobs=4
)

for name, df in data.items():
    if not df.empty:
        print(f"   {name}: {len(df)} rows, {len(df.columns)} columns")

# 3. Filter Data
print("\n3. Filtering data...")
filtered_df = data_filter.apply_standard_filters(
    data['round'],
    params.filter
)
print(f"   Filtered: {len(filtered_df)} rows")
print(f"   Unique VCs: {filtered_df['firmname'].nunique()}")
print(f"   Unique companies: {filtered_df['comname'].nunique()}")

# 4. Construct Networks
print("\n4. Constructing networks...")
years = list(range(params.filter.min_year, params.filter.max_year + 1))
networks = construction.construct_networks_for_years(
    round_df=filtered_df,
    years=years,
    time_window=5,
    edge_cutpoint=1,
    use_parallel=True,
    n_jobs=-1
)

for year, network in list(networks.items())[:3]:
    print(f"   Year {year}: {network.number_of_nodes()} nodes, {network.number_of_edges()} edges")

# 5. Compute Centralities
print("\n5. Computing centralities...")
centrality_df = centrality.compute_centralities_for_networks(
    networks=networks,
    use_parallel=True,
    n_jobs=-1,
    use_approximate_betweenness=True
)
print(f"   Centrality data: {len(centrality_df)} firm-year observations")

# 6. Analyze Results
print("\n6. Analysis results:")
print("\n   Top 10 VCs by degree centrality:")
top_vcs = centrality_df.nlargest(10, 'dgr_cent')[['firmname', 'year', 'dgr_cent', 'btw_cent']]
print(top_vcs.to_string(index=False))

# 7. Save Results
print("\n7. Saving results...")
output_path = paths.get_output_path('cvc', 'centrality_test', 'parquet')
io.save_parquet(centrality_df, output_path)
print(f"   Saved to: {output_path}")
print(f"   File size: {output_path.stat().st_size / 1024**2:.2f} MB")

print("\n" + "=" * 60)
print("QUICK START COMPLETED!")
print("=" * 60)
print("\nNext steps:")
print("1. Run full CVC analysis pipeline")
print("2. Run imprinting analysis pipeline")
print("3. Customize parameters for your research")
print("4. Load results in R for regression analysis")

