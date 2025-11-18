# VC Analysis Project - Comprehensive Requirements Document

**Purpose**: This document provides comprehensive context for AI assistants working on the VC analysis project. It includes file paths, variable definitions, calculation methods, data structures, and implementation details necessary to understand and modify the codebase.

**Last Updated**: 2025-11-07  
**Project Root**: `/Users/suengj/Documents/Code/Python/Research/VC/refactor_v2`

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Project Structure and File Paths](#project-structure-and-file-paths)
3. [Data Loading and Preprocessing](#data-loading-and-preprocessing)
4. [Network Construction and Centrality](#network-construction-and-centrality)
5. [Initial Period Variables (Imprinting Analysis)](#initial-period-variables-imprinting-analysis)
6. [Geographic Distance Variables](#geographic-distance-variables)
7. [VC Reputation Index](#vc-reputation-index)
8. [Market Heat and New Venture Funding Demand](#market-heat-and-new-venture-funding-demand)
9. [Firm-Level Variables](#firm-level-variables)
10. [Final Dataset Structure](#final-dataset-structure)
11. [Missing Data Handling](#missing-data-handling)
12. [Analysis Pipeline](#analysis-pipeline)
13. [Key Implementation Details](#key-implementation-details)
14. [Common Issues and Solutions](#common-issues-and-solutions)

---

## Project Overview

### Research Question
How do initial network partners' characteristics affect VC firm performance?

### Theoretical Framework
- **Podolny's Status Theory**: Partner status signals focal firm quality
- **Network Imprinting Theory**: Initial partnerships have lasting effects on firm trajectory

### Key Hypotheses
- **H1**: Initial partners' high centrality → Better focal firm performance
- **H2**: Maximum partner status provides benefits beyond mean status
- **H3**: Minimum partner status creates penalties (contamination effect)

### Analysis Design
- **Cohort Selection**: Firms with initial ties formed in START_YEAR ~ END_YEAR (e.g., 1990-2000)
- **Imprinting Period**: First 3 years (t1~t3) after initial network formation
- **Network Window**: 5-year lagged window (t-5 to t-1) for centrality calculation
- **Data Level**: Firm-Year panel data

---

## Project Structure and File Paths

### Root Directory
```
/Users/suengj/Documents/Code/Python/Research/VC/refactor_v2/
```

### Key Directories

#### 1. Source Code (`vc_analysis/`)
```
vc_analysis/
├── __init__.py
├── config/
│   ├── __init__.py
│   ├── constants.py          # Constants (network window, imprinting period, etc.)
│   ├── parameters.py         # Tunable parameters (dataclasses)
│   └── paths.py              # File paths configuration
├── data/
│   ├── __init__.py
│   ├── loader.py             # Data loading with preprocessing
│   ├── merger.py             # Data merging utilities
│   └── filter.py             # Data filtering functions
├── network/
│   ├── __init__.py
│   ├── construction.py       # Network construction (5-year lagged windows)
│   ├── centrality.py         # Centrality calculation (8 measures)
│   ├── distance.py           # Network distance calculations
│   └── imprinting.py         # Initial period variables calculation
├── distance/
│   ├── __init__.py
│   ├── geographic.py         # Geographic distance (Haversine formula)
│   └── industry.py           # Industry distance calculations
├── variables/
│   ├── __init__.py
│   ├── firm_variables.py     # Firm-level variables (age, diversity, performance, etc.)
│   ├── investment.py         # Investment-related variables
│   ├── diversity.py          # Diversity calculations
│   └── performance.py       # Performance metrics
├── sampling/
│   ├── __init__.py
│   ├── leadvc.py             # Lead VC identification
│   └── case_control.py       # Case-control sampling
└── utils/
    ├── __init__.py
    ├── parallel.py           # Parallel processing utilities
    ├── validation.py         # Data validation functions
    └── io.py                 # I/O utilities
```

#### 2. Notebooks (`notebooks/`)
```
notebooks/
├── preprc_imprint.ipynb      # Main preprocessing notebook (CRITICAL)
├── imprinting_analysis_history.md  # Analysis history (Korean)
└── quick_start.py            # Quick start script
```

#### 3. Documentation (`docs/` and root)
```
docs/
├── data_flow.md              # Data flow documentation
├── algorithm_extraction.md   # Algorithm details
└── performance_bottlenecks.md # Performance optimization notes

Root level:
├── research_history.md       # Overall research history (English)
├── requirement.md            # This file
├── README.md                 # Project README
└── USAGE_GUIDE.md            # Usage guide
```

#### 4. Data Directories
```
data/                          # Raw data (parent directory)
├── round_Mar25.csv           # Round data (main investment data)
├── comdta_new.csv            # Company data
├── firmdta_all.xlsx          # Firm data
└── fund_all.xlsx             # Fund data

processed_data/               # Processed data outputs
├── imprinting_analysis/      # Imprinting analysis outputs
└── cvc_analysis/             # CVC analysis outputs

results/                      # Analysis results
cache/                        # Cached intermediate results
logs/                         # Log files
```

### Critical File Paths

**Data Loading**:
- Round data: `data/round_Mar25.csv`
- Company data: `data/comdta_new.csv`
- Firm data: `data/firmdta_all.xlsx`
- Fund data: `data/fund_all.xlsx`

**Main Notebook**:
- Preprocessing: `notebooks/preprc_imprint.ipynb` (THIS IS THE MAIN ENTRY POINT)

**Key Python Modules**:
- Data loader: `vc_analysis/data/loader.py`
- Network construction: `vc_analysis/network/construction.py`
- Centrality: `vc_analysis/network/centrality.py`
- Imprinting: `vc_analysis/network/imprinting.py`
- Geographic distance: `vc_analysis/distance/geographic.py`
- Firm variables: `vc_analysis/variables/firm_variables.py`

---

## Data Loading and Preprocessing

### Main Function
```python
from vc_analysis.data import loader

data = loader.load_all_data()
# Returns: {'round': DataFrame, 'company': DataFrame, 'firm': DataFrame, 'fund': DataFrame}
```

### Preprocessing Steps (Automatic in `loader.py`)

#### 1. Round Data (`round_Mar25.csv`)
- **Excel Serial Date Conversion**: `rnddate` column converted from Excel serial number (origin: 1899-12-30)
  ```python
  round_df['rnddate'] = pd.to_datetime(round_df['rnddate'], unit='D', origin='1899-12-30')
  ```
- **Year Extraction**: `year = rnddate.dt.year`
- **Undisclosed Entity Removal**: 
  - Remove rows where `firmname == 'Undisclosed Firm'`
  - Remove rows where `comname == 'Undisclosed Company'`
- **Exact Duplicate Removal**: Drop rows where all columns are identical
- **Firm Registry Filter**: Filter rounds to only include firms present in firm registry
  ```python
  from vc_analysis.data import loader as data_loader
  data['round'] = data_loader.filter_round_by_firm_registry(
      round_df=data['round'],
      firm_df=data['firm'],
      mode='strict'  # or 'nation_select' with nation_codes=['US', 'CA']
  )
  ```

#### 2. Company Data (`comdta_new.csv`)
- **Deduplication**: Keep company with maximum non-missing score
- **Key Columns**:
  - `comname`: Company name
  - `comnation`: Company nation (e.g., 'United States' → 'US')
  - `comzip`: Company ZIP code (may be 4-digit, needs normalization)
  - `comindmnr`: Industry classification (for Blau index)
  - `comsitu`: Exit status ('Went Public', 'Merger', 'Acquisition')
  - `date_ipo`, `date_sit`: Exit dates

#### 3. Firm Data (`firmdta_all.xlsx`)
- **Deduplication**: 
  - Keep firm with earliest `firmfounding` date
  - If tie, prefer firm with non-null `firmzip`
- **Key Columns**:
  - `firmname`: Firm name
  - `firmfounding`: Founding date
  - `firmzip`: Firm ZIP code (may be 4-digit, needs normalization)
  - `firmtype2`: VC type ('IVC', 'CVC', 'Angel', 'Other', etc.)
  - `firmnation`: Firm nation

#### 4. Fund Data (`fund_all.xlsx`)
- **Key Columns**:
  - `fundname`: Fund name
  - `firmname`: Associated VC firm
  - `fundyear`: Fund raising year
  - `fundsize`: Fund size
  - `fundiniclosing`: Fund closing date (format: dd.mm.yyyy, e.g., "23.05.2022")

### Data Filtering (In Notebook)

**VC Type Filtering**:
```python
from vc_analysis.data import filter as data_filter

filtered_round = data_filter.filter_by_vc_type(
    data['round'], 
    exclude_types=['Angel', 'Other'], 
    type_column='firmtype2',
    exclude_null=True  # Also exclude null firmtype2
)
```

**Result**: Only 'IVC' and 'CVC' firms remain in `filtered_round`

---

## Network Construction and Centrality

### Network Construction (`vc_analysis/network/construction.py`)

#### Time Window Logic
- **Network for year t**: Constructed using data from `[t - TIME_WINDOW, t - 1]`
- **Default TIME_WINDOW**: 5 years (defined in `constants.py`)
- **Example**: Network for 1990 uses rounds from 1985-1989

#### Function
```python
from vc_analysis.network import construction

networks = construction.construct_networks_for_years(
    filtered_round, 
    years=list(range(START_YEAR, END_YEAR + 1)),  # e.g., [1990, 1991, ..., 2000]
    time_window=5
)
# Returns: Dict[int, nx.Graph]  # {year: NetworkX graph}
```

#### Network Properties
- **Type**: Undirected, unweighted (by default)
- **Nodes**: VC firms (`firmname`)
- **Edges**: Co-investment relationships (two firms invest in same company in same round)
- **Edge Creation**: If `firmname_A` and `firmname_B` both appear in same `comname` and `rnddate`, create edge

### Centrality Calculation (`vc_analysis/network/centrality.py`)

#### Function
```python
from vc_analysis.network import centrality

centrality_df = centrality.compute_centralities_for_networks(networks)
# Returns: DataFrame with columns: [firmname, year, dgr_cent, btw_cent, ...]
```

#### Centrality Measures (8 total)

1. **`dgr_cent`**: Degree centrality (unweighted, unnormalized)
   - Count of direct neighbors
   - Default: Unweighted, not normalized

2. **`btw_cent`**: Betweenness centrality (unweighted, unnormalized)
   - Fraction of shortest paths passing through node
   - Uses approximate betweenness for large networks (k=500 samples)

3. **`pwr_max`**: Maximum beta for power centrality (1/λ_max)
   - **Definition**: Inverse of largest eigenvalue (λ_max) of adjacency matrix
   - **Meaning**: Upper bound for β parameter in Bonacich power centrality
   - **Formula**: `pwr_max = 1 / λ_max` where λ_max = largest eigenvalue of adjacency matrix A
   - **Usage**: Reference value for β calculation; not a centrality measure itself
   - Always computed

4. **`pwr_p0`**: Bonacich power centrality (β=0.0)
   - **Definition**: Power centrality with β=0 (unweighted status)
   - **Formula**: β = 0 × (1/λ_max) = 0
   - **Equivalent to**: Degree centrality when β=0
   - **Normalized**: Yes, to [0, 1] range
   - **Usage**: Baseline measure (equivalent to degree centrality)

5. **`pwr_p75`**: Bonacich power centrality (β=0.75)
   - **Definition**: Power centrality with β = 0.75 × (1/λ_max)
   - **Formula**: β = ρ × (1/λ_max) where ρ = 0.75
   - **Meaning**: Weighted status with moderate diffusion (ρ=0.75)
   - **Normalized**: Yes, to [0, 1] range
   - **Usage**: Primary measure for robustness checks (following Podolny 2005)

6. **`pwr_p99`**: Bonacich power centrality (β=0.99)
   - **Definition**: Power centrality with β = 0.99 × (1/λ_max)
   - **Formula**: β = ρ × (1/λ_max) where ρ = 0.99
   - **Meaning**: Weighted status with high diffusion (ρ=0.99, near maximum)
   - **Normalized**: Yes, to [0, 1] range
   - **Usage**: High diffusion sensitivity analysis

**Bonacich Power Centrality Details**:
- **Theoretical Foundation**: Bonacich (1987) power centrality measures actor status based on status of those deferring to them
- **Calculation Formula**: `c = (I - βA)^(-1) A 1`
  - `I`: Identity matrix
  - `A`: Adjacency matrix
  - `β`: Diffusion parameter (β = ρ × (1/λ_max))
  - `1`: Column vector of ones
- **β Parameter Selection**:
  - `β = ρ × (1/λ_max)` where `ρ ∈ [0, 1)`
  - `λ_max`: Largest eigenvalue of adjacency matrix
  - `ρ = 0`: Unweighted status (equivalent to degree centrality)
  - `ρ = 0.75`: Weighted status (following Podolny 2005)
  - `ρ = 0.99`: High diffusion (near maximum)
- **α Scaling**: 
  - Bonacich (1987) suggests scaling constant α so that squared length of status vector equals n (number of actors)
  - **Current Implementation**: α scaling is **omitted** (optional for cross-network comparison)
  - Status values are normalized by maximum value instead (when `normalize_power=True`)
- **Initial Partner Status**: All power measures (`pwr_p0`, `pwr_p75`, `pwr_p99`, `pwr_max`) are used to compute initial partner status variables (`initial_pwr_*_mean/max/min`)

7. **`constraint`**: Burt's structural holes measure
   - Measures network constraint (inverse of structural holes)
   - **NaN Handling**: Isolated nodes (degree=0) → `constraint = 0` (configurable)
   - **Capping**: Values > 1.0 capped at 1.0 (theoretical maximum for cliques)
   - Default: Unweighted, not normalized

8. **`ego_dens`**: Ego network density
   - Density of subgraph induced by node and its neighbors
   - Not normalized

#### Configuration (`vc_analysis/config/parameters.py`)

**CentralityParameters** dataclass:
```python
@dataclass
class CentralityParameters:
    compute_degree: bool = True
    compute_betweenness: bool = True
    compute_power: bool = True
    compute_constraint: bool = True
    compute_ego_density: bool = True
    
    # Weighted vs Unweighted
    use_weighted_degree: bool = False
    use_weighted_betweenness: bool = False
    use_weighted_power: bool = False
    use_weighted_constraint: bool = False
    
    # Normalization
    normalize_degree: bool = False
    normalize_betweenness: bool = False
    normalize_power: bool = True  # Power centrality normalized by default
    normalize_constraint: bool = False
    
    # Constraint NaN handling
    constraint_fill_na: bool = True
    constraint_fill_value: float = 0.0
    constraint_cap_at_one: bool = True
    
    # Post-merge missingness handling
    create_in_network_dummy: bool = True  # Create 'in_network' dummy
    fill_missing_centrality_as_zero: bool = False
    zero_fill_columns: List[str] = field(default_factory=list)
```

#### Missing Centrality Handling

**`in_network` Dummy**:
- Created if `create_in_network_dummy=True`
- `in_network = 1` if ANY centrality measure is non-null
- `in_network = 0` if ALL centrality measures are null
- **Usage**: Include as control variable in regression

**Zero-Fill (Optional)**:
- If `fill_missing_centrality_as_zero=True` and `zero_fill_columns` specified:
  - Fill selected columns with 0 for rows where `in_network=0`
  - Example: `zero_fill_columns=['dgr_cent', 'constraint']`

---

## Initial Period Variables (Imprinting Analysis)

### Overview
Calculate firm-level constant variables capturing VC firm characteristics during the initial investment period (t1~t3).

### Key Functions (`vc_analysis/network/imprinting.py`)

#### 1. Identify Initial Year (Full History)
```python
from vc_analysis.network import imprinting

full_initial_year_df = imprinting.identify_initial_year(
    filtered_round,  # ALL years data (not just cohort)
    firm_col='firmname',
    year_col='year'
)
# Returns: DataFrame with [firmname, initial_year]
```

**Logic**: For each firm, find the first year it appears in `round_df` (across ALL available years, e.g., 1970-2022)

**Example**: Sequoia Capital → `initial_year = 1972` (even if analysis cohort is 1990-2000)

#### 2. Cohort Filtering
```python
# Select firms with initial ties in START_YEAR ~ END_YEAR
initial_year_df = full_initial_year_df[
    full_initial_year_df['initial_year'].between(START_YEAR, END_YEAR)
].copy()
```

**Result**: Only firms with `initial_year` in cohort range (e.g., 1990-2000)

#### 3. Extract Initial Partners (t1~t3)
```python
initial_partners_df = imprinting.extract_initial_partners(
    filtered_round,  # ALL years data
    imprinting_networks,  # Networks for t1, t2, t3 only
    initial_year_df,  # Cohort firms
    imprinting_period=3,  # t1~t3
    firm_col='firmname'
)
# Returns: DataFrame with [firmname, initial_partner, tied_year, initial_year]
```

**Logic**: For each firm in cohort:
- Get `initial_year` (t1)
- Extract all partners from networks at t1, t2, t3
- Record each partnership

#### 4. Calculate Partner Centrality by Year + Partner Reputation
```python
initial_ties_with_cent = imprinting.calculate_partner_centrality_by_year(
    initial_partners_df,
    imprinting_centrality_df,  # Centrality at t1, t2, t3
    firm_col='firmname',
    partner_feature_df=reputation_df[['firmname','year','VC_reputation']],
    partner_feature_cols=['VC_reputation']
)
# Returns: Initial ties with partner centrality + partner VC reputation
```

**Logic**: For each partner-year pair, merge partner's centrality and VC reputation at that year
- Centrality frame now includes Burt structural holes (`sh`, effective size)
- Partner centrality calculated from 5-year lagged network (t-5 to t-1)
- Partner VC reputation is pulled from the firm-year `VC_reputation` dataset and added as `partner_VC_reputation`

#### 5. Compute Initial Partner Status (Partner-Weighted)
```python
initial_ties_df = imprinting.compute_all_initial_partner_status(
    initial_ties_with_cent,
    centrality_measures=None,  # All measures
    firm_col='firmname'
)
# Returns: Firm-level DataFrame with initial_*_mean/max/min columns
```

**Calculation Method (Partner-Weighted)**:

**Step 1**: Calculate each partner's time-averaged centrality
- Partner B: `avg_B = (cent_t1 + cent_t2) / 2`
- Partner C: `avg_C = (cent_t1 + cent_t3) / 2`
- Partner D: `avg_D = cent_t2`

**Step 2**: Aggregate across partners
- **Mean**: `(avg_B + avg_C + avg_D) / |P|` → `initial_{measure}_mean`
- **Max**: `max(avg_B, avg_C, avg_D)` → `initial_{measure}_max`
- **Min**: `min(avg_B, avg_C, avg_D)` → `initial_{measure}_min`

**Output Variables** (for each centrality measure):
- `initial_dgr_cent_mean`, `initial_dgr_cent_max`, `initial_dgr_cent_min`
- `initial_btw_cent_mean`, `initial_btw_cent_max`, `initial_btw_cent_min`
- `initial_pwr_max_mean`, `initial_pwr_max_max`, `initial_pwr_max_min` (reference value: 1/λ_max)
- `initial_pwr_p0_mean`, `initial_pwr_p0_max`, `initial_pwr_p0_min` (β=0, equivalent to degree)
- `initial_pwr_p75_mean`, `initial_pwr_p75_max`, `initial_pwr_p75_min` (β=0.75×(1/λ_max), primary robustness check)
- `initial_pwr_p99_mean`, `initial_pwr_p99_max`, `initial_pwr_p99_min` (β=0.99×(1/λ_max), high diffusion)
- `initial_constraint_mean`, `initial_constraint_max`, `initial_constraint_min`
- `initial_sh_mean`, `initial_sh_max`, `initial_sh_min` (Burt structural holes / effective size)
- `initial_ego_dens_mean`, `initial_ego_dens_max`, `initial_ego_dens_min`
- `initial_VC_reputation_mean`, `initial_VC_reputation_max`, `initial_VC_reputation_min` (partner reputation averaged over t1~t3)

**Note on Power Measures**:
- All Bonacich power centrality measures (`pwr_max`, `pwr_p0`, `pwr_p75`, `pwr_p99`) are automatically included when `centrality_measures=None`
- `pwr_max` represents the reference value (1/λ_max) used for β calculation, not a centrality measure itself
- Each power measure captures different diffusion levels: `pwr_p0` (no diffusion), `pwr_p75` (moderate), `pwr_p99` (high)

**Additional Variables**:
- `n_initial_partners`: Number of unique partners
- `n_partner_years`: Total partner-year observations
- `initial_year`: Focal firm's initial year
- Partner VC reputation is available because `partner_VC_reputation` is included in `initial_ties_with_cent`, so aggregation automatically produces `initial_VC_reputation_*`

**Total**: 8 measures × 3 aggregations = 24 variables + 3 metadata = 27 columns

#### 6. Calculate Initial Period Variables (t1~t3 Investment Behavior)
```python
initial_period_vars_df = imprinting.calculate_initial_period_variables(
    round_df=data['round'],
    company_df=data['company'],
    firm_df=data['firm'],
    fund_df=data['fund'],
    initial_year_df=initial_year_df,
    firm_col='firmname',
    year_col='year',
    imprinting_period=3
)
# Returns: Firm-level DataFrame with initial_* variables
```

**Variables Calculated** (7 total):

1. **`initial_early_stage_ratio`**: Average early stage investment ratio during t1~t3
   - Calculation: Average of `early_stage_ratio` across t1, t2, t3
   - Imprinting effect: Initial investment style may influence future patterns

2. **`initial_industry_blau`**: Average industry diversity (Blau index) during t1~t3
   - Calculation: Average of `industry_blau` across t1, t2, t3
   - Imprinting effect: Initial industry portfolio may influence future diversity

3. **`initial_inv_num`**: Total investment count during t1~t3 (sum)
   - Calculation: Sum of `inv_num` across t1, t2, t3
   - Imprinting effect: Initial activity/experience may influence future behavior

4. **`initial_inv_amt`**: Total investment amount during t1~t3 (sum)
   - Calculation: Sum of `inv_amt` across t1, t2, t3
   - Imprinting effect: Initial investment scale may influence future resource allocation

5. **`initial_firmage`**: Firm age at t1 (initial_year)
   - Calculation: `firmage` at `initial_year`
   - Imprinting effect: Organizational age at initial period may influence future behavior

6. **`initial_market_heat`**: Average market heat during t1~t3
   - Calculation: Average of `market_heat` across t1, t2, t3
   - Imprinting effect: Initial market conditions may influence future strategy

7. **`initial_new_venture_demand`**: Average new venture demand during t1~t3
   - Calculation: Average of `new_venture_demand` across t1, t2, t3
   - Imprinting effect: Initial market demand may influence future investment patterns

**Data Preservation Strategy**:
- Uses `right` join to preserve all firms in `initial_year_df`
- Firms not in source data are included with NaN values (allows tracking)
- Extensive logging at each step (data size, year range, non-null counts)

**Column Duplication Prevention**:
- `initial_year` column exists in both `result` and merged DataFrames
- **Solution**: Remove `initial_year` from right DataFrame before merge using `drop(columns=['initial_year'], errors='ignore')`
- Merge using only `on=[firm_col]` (not `on=[firm_col, 'initial_year']`)
- Result: Only `result`'s `initial_year` is preserved (no `_x`, `_y` suffixes)

#### 7. Calculate Initial Period Geographic Distances
```python
initial_geo_dist_df = imprinting.calculate_initial_period_geographic_distances(
    initial_year_df=initial_year_df,
    geo_dist_copartner_df=geo_dist_copartner_df,  # Firm-year level co-partner distances
    firm_col='firmname',
    year_col='year',
    imprinting_period=3
)
# Returns: Firm-level DataFrame with initial_geo_dist_copartner_* variables
```

**Variables Calculated** (6 total):
- `initial_geo_dist_copartner_mean`: Average distance during t1~t3
- `initial_geo_dist_copartner_min`: Minimum distance during t1~t3
- `initial_geo_dist_copartner_max`: Maximum distance during t1~t3
- `initial_geo_dist_copartner_weighted_mean`: Investment-weighted average distance
- `initial_geo_dist_copartner_std`: Standard deviation of distances
- **Note**: `median` is excluded from all distance calculations (as requested)

**Calculation Method**:
- For each firm, extract co-partner distances for years t1, t2, t3
- Aggregate using mean/min/max/weighted_mean/std across all partner-year observations
- Filter out NaN distances before aggregation

**Data Preservation Strategy**: Same as `calculate_initial_period_variables` (right join, logging, column duplication prevention)

---

## Geographic Distance Variables

### Overview
Calculate physical distances between VC firms and their invested companies/co-investment partners using ZIP codes and Haversine formula.

### Key Functions (`vc_analysis/distance/geographic.py`)

#### 1. Build ZIP Code Database
```python
from vc_analysis.distance import geographic

zipcode_db = geographic.build_zipcode_database(
    firm_df=data['firm'],
    company_df=data['company'],
    firmzip_col='firmzip',
    comzip_col='comzip'
)
# Returns: Dict[str, Dict]  # {zip: {'lat': float, 'lng': float}}
```

**ZIP Code Normalization**:
- Handles 4-digit ZIPs: `1234` → `01234` (pad with leading zeros)
- Handles float inputs: `1234.0` → `1234` → `01234`
- Handles string inputs: `"12345-6789"` → `"12345"` (remove ZIP+4 extension)
- Invalid ZIPs → `None` (not included in database)

**ZIP → Coordinates Conversion**:
- Uses `uszipcode` library (must be installed in conda environment `research`)
- If library not available, returns empty database (with warning)
- Logs conversion success/failure rates and sample failed ZIPs

#### 2. Calculate VC-Company Distances
```python
geo_dist_company_df = geographic.calculate_vc_company_distances(
    round_df=data['round'],
    firm_df=data['firm'],
    company_df=data['company'],
    zipcode_db=zipcode_db,
    firm_col='firmname',
    comname_col='comname',
    year_col='year',
    firmzip_col='firmzip',
    comzip_col='comzip',
    amount_col='RoundAmountDisclosedThou'  # Optional, for weighted mean
)
# Returns: Firm-year level DataFrame
```

**Variables Calculated** (6 total):
- `geo_dist_company_mean`: Average distance to invested companies
- `geo_dist_company_min`: Minimum distance to invested companies
- `geo_dist_company_max`: Maximum distance to invested companies
- `geo_dist_company_weighted_mean`: Investment amount-weighted average distance
- `geo_dist_company_std`: Standard deviation of distances
- **Note**: `median` is excluded (as requested)

**Calculation Method**:
1. Merge firm ZIP and company ZIP to round data
2. Convert ZIPs to coordinates using `zipcode_db`
3. Calculate Haversine distance for each firm-company pair
4. Filter out NaN distances before aggregation
5. Aggregate by `[firmname, year]` using mean/min/max/weighted_mean/std

**Haversine Formula**:
```python
def haversine_distance(lat1, lon1, lat2, lon2, unit='km'):
    # Returns distance in km (or miles)
    # Supports vectorized (numpy array) inputs
```

#### 3. Calculate VC-Co-Partner Distances
```python
geo_dist_copartner_df = geographic.calculate_vc_copartner_distances(
    round_df=data['round'],
    firm_df=data['firm'],
    zipcode_db=zipcode_db,
    firm_col='firmname',
    year_col='year',
    firmzip_col='firmzip',
    amount_col='RoundAmountDisclosedThou'  # Optional, for weighted mean
)
# Returns: Firm-year level DataFrame
```

**Variables Calculated** (6 total):
- `geo_dist_copartner_mean`: Average distance to co-investment partners
- `geo_dist_copartner_min`: Minimum distance to co-investment partners
- `geo_dist_copartner_max`: Maximum distance to co-investment partners
- `geo_dist_copartner_weighted_mean`: Investment amount-weighted average distance
- `geo_dist_copartner_std`: Standard deviation of distances
- **Note**: `median` is excluded (as requested)

**Calculation Method (Vectorized)**:
1. Create all co-partner pairs using `pd.DataFrame.merge` (self-join on `[comname, rnddate]`)
2. Merge firm ZIPs for both focal firm and partner
3. Convert ZIPs to coordinates
4. Calculate Haversine distance vectorized (numpy arrays)
5. Filter out NaN distances before aggregation
6. Aggregate by `[firmname, year]` using mean/min/max/weighted_mean/std

**Performance Optimization**:
- Replaced slow `for` loops with vectorized operations
- Uses `pd.DataFrame.merge` to create all pairs at once
- Vectorized distance calculation using numpy arrays

**Recommended Variables**:
- **Median** (excluded): Robust to outliers (but excluded per user request)
- **Weighted Mean**: Gives more weight to larger investments
- **Standard Deviation**: Measures distance dispersion (geographic concentration/spread)

---

## VC Reputation Index

### Overview
Composite index measuring VC firm reputation based on 6 component variables, calculated using a 5-year rolling window [t-4, t].

### Function (`vc_analysis/variables/firm_variables.py`)
```python
from vc_analysis.variables import firm_variables

reputation_df = firm_variables.calculate_vc_reputation(
    round_df=data['round'],
    company_df=data['company'],
    fund_df=data['fund'],
    year_col='year',
    window_years=5  # [t-4, t]
)
# Returns: Firm-year level DataFrame
```

### Component Variables (6 total)

1. **`rep_portfolio_count`**: Unique portfolio companies invested in [t-4, t]
   - Count of unique `comname` per firm-year
   - Data source: `round_df`

2. **`rep_total_invested`**: Total funds invested [t-4, t]
   - Sum of `RoundAmountDisclosedThou` per firm-year
   - NaN → 0 (treated as zero investment)
   - Data source: `round_df`

3. **`rep_avg_fum`**: Average funds under management at year t
   - Logic: Funds raised before t that are still open at t
   - Condition: `fundyear < t` AND (`fundiniclosing` is empty OR `fundiniclosing_year > t`)
   - `fundiniclosing` parsing: dd.mm.yyyy format (e.g., "23.05.2022") → extract year
   - Parsing failure monitoring: Logs failure rate
   - Average of `fundsize` for open funds
   - Data source: `fund_df`

4. **`rep_funds_raised`**: Number of funds raised [t-4, t]
   - Count of unique `fundname` per firm-year
   - Data source: `fund_df`

5. **`rep_ipos`**: Portfolio firms taken public [t-4, t]
   - Logic: Counts IPOs of companies invested in the PAST, where IPO occurred in [t-4, t]
   - Step 1: Identify all companies invested in before t
   - Step 2: Count IPOs of those companies where `date_ipo` is in [t-4, t]
   - Data source: `round_df` + `company_df`

6. **`fundingAge`**: VC age from first fund raising year
   - Calculation: `t - min(fundyear)` per firm
   - Data source: `fund_df`

### Reputation Index Calculation

**Step 1: Z-Score Standardization (BY YEAR)**
```python
# For each variable, standardize by year
z_score = (value - mean_year) / std_year
# If std_year == 0, z_score = 0
```

**Step 2: Sum Z-Scores**
```python
rep_index_raw = sum(z_score_i for i in 6 variables)
```

**Step 3: Min-Max Scaling (BY YEAR)**
```python
VC_reputation = 0.01 + (rep_index_raw - min_year) / (max_year - min_year) × 99.99
# Range: [0.01, 100]
```

### Missing Data Handling

**`rep_missing_fund_data` Flag**:
- `rep_missing_fund_data = 1` if ANY of `rep_avg_fum`, `rep_funds_raised`, `fundingAge` is NaN
- `rep_missing_fund_data = 0` otherwise
- **Usage**: Can exclude observations in final sampling if fund data is critical

**Merge Strategy**:
- Uses `how='left'` to preserve round_df-based firm-year structure
- Firms without fund data still included (with NaN for fund-based variables)
- Output (`VC_reputation`) is also merged into initial partner ties to compute `initial_VC_reputation_mean/max/min`

### Output Variables (14 total)
- 6 component variables (above)
- `fundingAge`
- `rep_missing_fund_data`
- 6 z-score variables (for debugging): `rep_portfolio_count_z`, `rep_total_invested_z`, etc.
- `rep_index_raw`: Sum of z-scores
- `VC_reputation`: Final index [0.01, 100]

---

## Market Heat and New Venture Funding Demand

### Market Heat (`vc_analysis/variables/firm_variables.py`)

#### Function
```python
market_heat_df = firm_variables.calculate_market_heat(
    fund_df=data['fund'],
    year_col='year',
    fundyear_col='fundyear',
    fundname_col='fundname'
)
# Returns: Year-level DataFrame with [year, market_heat]
```

#### Definition
Measures relative activity of VC fund raising at industry level.

#### Formula
```
Market heat_t = ln((VC funds raised_t × 3) / Σ_{k=t-3}^{t-1} VC funds raised_k)
```

- **Numerator**: Current year (t) unique VC fund count × 3
- **Denominator**: Sum of VC fund counts in antecedent 3 years (t-3, t-2, t-1)

#### Interpretation
- `market_heat > 0`: Hot market (active fund raising)
- `market_heat < 0`: Cold market (sluggish fund raising)

#### Edge Cases
- `NaN` if denominator = 0 or ratio ≤ 0

#### Integration
- Industry-level variable → Same value for all firms in same year
- Merge to firm-year panel by `year` column

### New Venture Funding Demand (`vc_analysis/variables/firm_variables.py`)

#### Function
```python
new_venture_demand_df = firm_variables.calculate_new_venture_funding_demand(
    round_df=data['round'],
    company_df=data['company'],
    year_col='year',
    roundnumber_col='RoundNumber',
    comname_col='comname',
    comnation_col='comnation',
    us_nation='US'  # Changed from 'United States' to 'US'
)
# Returns: Year-level DataFrame with [year, new_venture_demand]
```

#### Definition
Measures demand for VC funding based on natural log of total number of new ventures that received a first round of VC financing in the United States in the current calendar year.

#### Formula
```
new_venture_demand_t = ln(count of first-round US ventures in year t)
```

- **First Round Identification**: `RoundNumber == min(RoundNumber)` per company
- **US Filter**: `comnation == 'US'` (changed from 'United States')
- **Current Year**: Uses year t value (**NOT lagged** - this is raw dataset)
- **Natural Log Transformation**: `ln(count)`

#### Edge Cases
- `NaN` for zero count

#### Integration
- Industry-level variable → Same value for all firms in same year
- Merge to firm-year panel by `year` column

#### Panel Analysis Note
- **Raw dataset variable**: Uses current year (t) value
- **For regression analysis**: Lagging should be done during regression (e.g., use year t-1 value)

---

## Firm-Level Variables

### Overview (`vc_analysis/variables/firm_variables.py`)

Firm-year level variables calculated from round, company, and firm data.

### Key Functions

#### 1. Firm Age
```python
firm_age_df = firm_variables.calculate_firm_age(
    firm_df=data['firm'],
    round_df=data['round'],
    founding_col='firmfounding',
    year_col='year'
)
# Returns: DataFrame with [firmname, year, firmage]
```

**Calculation**:
- `firmage = year - founding_year`
- Negative ages → 0 (capped)

#### 2. Investment Diversity (Blau Index)
```python
diversity_df = firm_variables.calculate_investment_diversity(
    round_df=data['round'],
    company_df=data['company'],
    industry_col='comindmnr',  # Industry classification column
    year_col='year'
)
# Returns: DataFrame with [firmname, year, industry_blau]
```

**Blau Index Formula**:
```
Blau = 1 - Σ(p_i^2)
where p_i = proportion of investments in industry i
```

**Calculation**:
- Group by `[firmname, year, comindmnr]` → count investments per industry
- Calculate proportions
- Apply Blau formula

#### 3. Performance Metrics
```python
performance_df = firm_variables.calculate_performance_metrics(
    round_df=data['round'],
    company_df=data['company'],
    year_col='year'
)
# Returns: DataFrame with [firmname, year, perf_IPO, perf_MnA, perf_all]
```

**Variables**:
- `perf_IPO`: Count of portfolio companies that went public in year t
- `perf_MnA`: Count of portfolio companies that had M&A in year t
- `perf_all`: Count of all exits (IPO + M&A) in year t

**Logic**:
- Only counts exits in **current year** (not cumulative)
- Matches `comname` from `round_df` to `company_df`
- Checks `comsitu` and `date_ipo`/`date_sit` columns

**Missing Handling**:
```python
from vc_analysis.variables import firm_variables

final_df = firm_variables.fill_missing_performance_with_zero(
    final_df,
    columns=['perf_IPO', 'perf_MnA', 'perf_all'],  # Optional: auto-detect if None
    inplace=False
)
```

#### 4. Early Stage Ratio
```python
early_ratio_df = firm_variables.calculate_early_stage_ratio(
    round_df=data['round'],
    year_col='year',
    stage_col='CompanyStageLevel1'
)
# Returns: DataFrame with [firmname, year, early_stage_ratio]
```

**Calculation**:
- Define early stages (e.g., 'Seed', 'Series A', 'Series B')
- For each firm-year: `early_stage_ratio = count(early_stage_investments) / total_investments`

#### 5. Firm HQ Dummy
```python
firm_hq_df = firm_variables.calculate_firm_hq_dummy(
    firm_df=data['firm'],
    hq_col='firmhq'  # Or similar column
)
# Returns: DataFrame with [firmname, firm_hq, firm_hq_CA, firm_hq_MA, firm_hq_NY]
```

**Variables**:
- `firm_hq`: CA or MA = 1 (kept for backward compatibility)
- `firm_hq_CA`: California = 1
- `firm_hq_MA`: Massachusetts = 1
- `firm_hq_NY`: New York = 1

**Note**: Firm-level variable → Merged to all years (same value for all years per firm)

#### 6. Investment Amount
```python
inv_amt_df = firm_variables.calculate_investment_amount(
    round_df=data['round'],
    year_col='year',
    amount_col='RoundAmountDisclosedThou'
)
# Returns: DataFrame with [firmname, year, inv_amt]
```

**Calculation**: Sum of `RoundAmountDisclosedThou` per firm-year

#### 7. Investment Number
```python
inv_num_df = firm_variables.calculate_investment_number(
    round_df=data['round'],
    year_col='year'
)
# Returns: DataFrame with [firmname, year, inv_num]
```

**Calculation**: Count of investments per firm-year

#### 8. Years Since Initial Network
```python
# Calculated in notebook after merging initial_year
final_df['years_since_init'] = final_df['year'] - final_df['initial_year']
# NaN for firms without initial_year (established firms)
```

**Definition**: Number of years since initial network formation

**Usage**: Event-time based analysis (years since initial network = 0, 1, 2, ...)

---

## Final Dataset Structure

### Main Notebook: `notebooks/preprc_imprint.ipynb`

### Data Flow

#### Step 1: Data Loading (Cell 1)
```python
data = loader.load_all_data()
# Filter by firm registry
data['round'] = data_loader.filter_round_by_firm_registry(...)
```

#### Step 2: Network Construction (Cell 2)
```python
filtered_round = data_filter.filter_by_vc_type(...)
networks = construction.construct_networks_for_years(...)
centrality_df = centrality.compute_centralities_for_networks(networks)
```

#### Step 3: Initial Period Variables (Cell 3-5)
```python
# Identify initial year (full history)
full_initial_year_df = imprinting.identify_initial_year(...)
initial_year_df = full_initial_year_df[...]  # Cohort filter

# Extract initial partners and calculate status
initial_ties_df = imprinting.compute_all_initial_partner_status(...)

# Calculate initial period variables
initial_period_vars_df = imprinting.calculate_initial_period_variables(...)
initial_geo_dist_df = imprinting.calculate_initial_period_geographic_distances(...)
```

#### Step 4: Firm Variables (Cell 6)
```python
# Calculate firm-year variables
firm_vars_df = firm_variables.calculate_all_firm_variables(...)

# Calculate VC Reputation
reputation_df = firm_variables.calculate_vc_reputation(...)

# Calculate Market Heat
market_heat_df = firm_variables.calculate_market_heat(...)

# Calculate New Venture Funding Demand
new_venture_demand_df = firm_variables.calculate_new_venture_funding_demand(...)
```

#### Step 5: Geographic Distances (Cell 7)
```python
# Build ZIP code database
zipcode_db = geographic.build_zipcode_database(...)

# Calculate VC-Company distances
geo_dist_company_df = geographic.calculate_vc_company_distances(...)

# Calculate VC-Co-Partner distances
geo_dist_copartner_df = geographic.calculate_vc_copartner_distances(...)
```

#### Step 6: Merge All Data (Cell 8-11)
```python
# Base: Firm-year combinations from firm_vars_df
final_df = firm_vars_df_filtered.copy()

# Merge centrality (left join)
final_df = final_df.merge(centrality_df, on=['firmname', 'year'], how='left')

# Merge initial partner status (left join, firm-level)
final_df = final_df.merge(initial_ties_df, on='firmname', how='left')

# Merge initial period variables (left join, firm-level)
final_df = final_df.merge(initial_period_vars_df_clean, on='firmname', how='left')
# Note: initial_year dropped from right DataFrame before merge

# Merge initial geographic distances (left join, firm-level)
final_df = final_df.merge(initial_geo_dist_df_clean, on='firmname', how='left')
# Note: initial_year dropped from right DataFrame before merge

# Merge VC Reputation (left join)
final_df = final_df.merge(reputation_df, on=['firmname', 'year'], how='left')

# Merge Market Heat (left join, year-level)
final_df = final_df.merge(market_heat_df, on='year', how='left')

# Merge New Venture Funding Demand (left join, year-level)
final_df = final_df.merge(new_venture_demand_df, on='year', how='left')

# Merge geographic distances (left join)
final_df = final_df.merge(geo_dist_company_df, on=['firmname', 'year'], how='left')
final_df = final_df.merge(geo_dist_copartner_df, on=['firmname', 'year'], how='left')
```

#### Step 7: Post-Processing (Cell 12)
```python
# Create in_network dummy
final_df['in_network'] = (final_df[centrality_cols].notna().any(axis=1)).astype(int)

# Optional: Zero-fill selected centrality measures
if fill_missing_centrality_as_zero:
    final_df.loc[final_df['in_network'] == 0, zero_fill_columns] = 0

# Fill missing performance with zero
final_df = firm_variables.fill_missing_performance_with_zero(final_df)

# Calculate years_since_init
final_df['years_since_init'] = final_df['year'] - final_df['initial_year']

# Calculate initial_status_missing flags
initial_status_cols = [c for c in final_df.columns 
                        if c.startswith('initial_') and c.endswith(('_mean', '_max', '_min'))]
final_df['initial_status_all_nan'] = final_df[initial_status_cols].isna().all(axis=1)
final_df['initial_status_missing'] = final_df['initial_status_all_nan'].astype(int)
# ... additional missing flags (see Missing Data Handling section)
```

### Final Dataset: `final_df`

**Level**: Firm-Year panel  
**Key**: `(firmname, year)`  
**Shape**: ~9,800 rows × ~90 columns (varies by cohort)

#### Variable Groups

1. **Key Variables** (2):
   - `firmname`: Firm identifier
   - `year`: Year

2. **Network Centrality** (8):
   - `dgr_cent`, `btw_cent`, `pwr_max`, `pwr_p0`, `pwr_p75`, `pwr_p99`, `constraint`, `ego_dens`

3. **Firm Basics** (8):
   - `firmage`, `industry_blau`, `perf_IPO`, `perf_MnA`, `perf_all`, `early_stage_ratio`, `inv_amt`, `inv_num`

4. **Firm HQ** (4):
   - `firm_hq`, `firm_hq_CA`, `firm_hq_MA`, `firm_hq_NY`

5. **Initial Partner Status** (27):
   - 8 measures × 3 aggregations (mean/max/min) = 24
   - `n_initial_partners`, `n_partner_years`, `initial_year` = 3
   - Total: 27

6. **Initial Period Variables** (7):
   - `initial_early_stage_ratio`, `initial_industry_blau`, `initial_inv_num`, `initial_inv_amt`, `initial_firmage`, `initial_market_heat`, `initial_new_venture_demand`

7. **Initial Geographic Distances** (6):
   - `initial_geo_dist_copartner_mean/min/max/weighted_mean/std`

8. **VC Reputation** (14):
   - 6 component variables, `fundingAge`, `rep_missing_fund_data`, 6 z-scores, `rep_index_raw`, `VC_reputation`

9. **Market Heat** (1):
   - `market_heat`

10. **New Venture Funding Demand** (1):
    - `new_venture_demand`

11. **Geographic Distances** (12):
    - VC-Company: 6 variables (mean/min/max/weighted_mean/std)
    - VC-Co-Partner: 6 variables (mean/min/max/weighted_mean/std)

12. **Missing Flags** (6):
    - `initial_status_missing`, `initial_missing_outside_cohort`, `initial_missing_no_partners`, `initial_missing_no_centrality`, `initial_missing_other`, `rep_missing_fund_data`

13. **Other** (2):
    - `in_network`: Dummy for network participation
    - `years_since_init`: Years since initial network formation

**Total**: ~90 columns

---

## Missing Data Handling

### Missing Flags (6 total)

#### 1. `initial_status_missing` (Summary Flag)
- **Definition**: `1` if ALL `initial_*_mean/max/min` variables are NaN
- **Calculation**: Check all columns matching pattern `initial_*_mean/max/min`
- **Criticality**: Summary flag (not used for filtering directly)

#### 2. `initial_missing_outside_cohort` (Low Criticality)
- **Definition**: Initial year outside cohort range
  - `initial_year_full` exists but outside START_YEAR~END_YEAR
  - `initial_year` is NaN
- **Criticality**: **Low** ✅ **Include in analysis**
- **Rationale**: Design-consistent (Control group)
- **Treatment**: Keep `initial_*` as NaN

#### 3. `initial_missing_no_partners` (Medium Criticality)
- **Definition**: No partners at founding
  - `initial_year` exists but `n_initial_partners` or `n_partner_years` is 0 or NaN
  - Or firm not in `initial_ties_df`
- **Criticality**: **Medium** ⚠️ **Conditional inclusion**
- **Rationale**: Interpretable as "Solo investment" group
- **Treatment**: Can include but interpret with caution

#### 4. `initial_missing_no_centrality` (High Criticality)
- **Definition**: Partners exist but all centrality values are NaN
  - `initial_year` exists and partners exist but all `initial_*` columns are NaN
- **Criticality**: **High** ❌ **Consider exclusion**
- **Rationale**: Possible data issue (matching/calculation error)
- **Treatment**: Exclude or investigate separately

#### 5. `initial_missing_other` (High Criticality)
- **Definition**: Other cases not covered above
- **Criticality**: **High** ❌ **Consider exclusion**
- **Rationale**: Unknown cause, needs investigation
- **Treatment**: Exclude or investigate separately

#### 6. `rep_missing_fund_data` (Medium Criticality)
- **Definition**: Missing fund-based VC Reputation variables
  - Any of `rep_avg_fum`, `rep_funds_raised`, `fundingAge` is NaN
- **Criticality**: **Medium** ⚠️ **Conditional inclusion**
- **Rationale**: Can exclude in final sampling
- **Treatment**: Analysis possible without fund data (round-based variables exist)

### Criticality-Based Sampling Guide

**Recommended Filter**:
```python
analysis_df = final_df[
    (final_df['initial_missing_no_centrality'] == 0) & 
    (final_df['initial_missing_other'] == 0)
].copy()
```

**Include**: Low + Medium criticality flags
- `initial_missing_outside_cohort` (Low)
- `initial_missing_no_partners` (Medium)
- `rep_missing_fund_data` (Medium)

**Exclude**: High criticality flags
- `initial_missing_no_centrality` (High)
- `initial_missing_other` (High)

### Validation Cell (Notebook Bottom)

**Location**: Last cell in `preprc_imprint.ipynb`

**Purpose**: Validate `initial_status_missing` consistency

**Logic**:
- Check rows where `initial_status_missing = 1`
- Verify ALL `initial_*_mean/max/min` variables are NaN
- Report any inconsistencies

**Note**: Validation code should always be placed at the **bottom** of the notebook (per user preference)

---

## Analysis Pipeline

### Complete Workflow

1. **Data Loading** → `data` dictionary
2. **Filtering** → `filtered_round` (Angel/Other/Null excluded)
3. **Network Construction** → `networks` (Dict[int, nx.Graph])
4. **Centrality Calculation** → `centrality_df` (firm-year)
5. **Initial Year Identification** → `initial_year_df` (firm-level)
6. **Initial Partner Status** → `initial_ties_df` (firm-level)
7. **Initial Period Variables** → `initial_period_vars_df` (firm-level)
8. **Initial Geographic Distances** → `initial_geo_dist_df` (firm-level)
9. **Firm Variables** → `firm_vars_df` (firm-year)
10. **VC Reputation** → `reputation_df` (firm-year)
11. **Market Heat** → `market_heat_df` (year-level)
12. **New Venture Funding Demand** → `new_venture_demand_df` (year-level)
13. **Geographic Distances** → `geo_dist_company_df`, `geo_dist_copartner_df` (firm-year)
14. **Merge All** → `final_df` (firm-year panel)
15. **Post-Processing** → Missing flags, `in_network`, zero-fill, etc.
16. **Export** → Parquet/Feather/CSV

### Export Format

**Primary**: Parquet (fast I/O, R-compatible via `arrow::read_parquet`)  
**Fallback**: Feather (R-compatible via `arrow::read_feather`)  
**Sample**: CSV (capped at `CSV_SAMPLE_N` rows, random or head)

**File Naming**:
```
final_analysis_{START_YEAR}_{END_YEAR}_{timestamp}.parquet
final_analysis_{START_YEAR}_{END_YEAR}_{timestamp}.feather
final_analysis_sample_{START_YEAR}_{END_YEAR}_n{CSV_SAMPLE_N}_{timestamp}.csv
```

**Index Reset**: `analysis_df.reset_index(drop=True)` before export

---

## Key Implementation Details

### Column Duplication Prevention

**Problem**: When merging firm-level DataFrames, `initial_year` column exists in both DataFrames, causing pandas to create `initial_year_x` and `initial_year_y` suffixes.

**Solution**:
```python
# Remove initial_year from right DataFrame before merge
right_df_clean = right_df.drop(columns=['initial_year'], errors='ignore').copy()

# Merge using only firm_col (not firm_col + initial_year)
result = result.merge(right_df_clean, on=[firm_col], how='left')
```

**Applied To**:
- `calculate_initial_period_variables()` in `imprinting.py`
- `calculate_initial_period_geographic_distances()` in `imprinting.py`
- Merge cells in `preprc_imprint.ipynb` (Step 4-1, Step 4-2)

### Data Preservation Strategy

**Problem**: Using `inner` join excludes firms from `initial_year_df` that don't exist in source DataFrames.

**Solution**: Use `right` join to preserve all firms in `initial_year_df`
```python
result = source_df.merge(initial_year_df, on=[firm_col], how='right')
```

**Applied To**:
- `calculate_initial_period_variables()` in `imprinting.py`
- `calculate_initial_period_geographic_distances()` in `imprinting.py`

**Result**: All firms in `initial_year_df` are preserved (with NaN for missing source data)

### Vectorization for Performance

**Geographic Distance Calculation**:
- **Old**: Nested `for` loops over firm-year pairs (slow, ~16 hours for 320k pairs)
- **New**: Vectorized using `pd.DataFrame.merge` (self-join) + numpy array operations
- **Result**: Dramatically faster (minutes instead of hours)

**Initial Period Variables**:
- **Old**: `iterrows()` loops
- **New**: Vectorized pandas operations (`groupby().agg()`, `merge()`)
- **Result**: Faster and more memory-efficient

### ZIP Code Normalization

**Handling**:
- 4-digit ZIPs: `1234` → `01234` (pad with leading zeros)
- Float inputs: `1234.0` → `1234` → `01234`
- String inputs: `"12345-6789"` → `"12345"` (remove ZIP+4)
- Invalid: → `None` (excluded from database)

**Function**: `normalize_zip_code()` in `geographic.py`

### Country Code Standardization

**Change**: `'United States'` → `'US'`
- Applied in `calculate_new_venture_funding_demand()` function
- Parameter: `us_nation='US'` (default)
- Updated in both `.py` and `.ipynb` files

### Median Exclusion

**Request**: Exclude `median` metric from all distance calculations

**Applied To**:
- `calculate_vc_company_distances()` in `geographic.py`
- `calculate_vc_copartner_distances()` in `geographic.py`
- `calculate_initial_period_geographic_distances()` in `imprinting.py`

**Result**: Only `mean`, `min`, `max`, `weighted_mean`, `std` are calculated

---

## Common Issues and Solutions

### Issue 1: `initial_year_x`, `initial_year_y` Columns Appear

**Cause**: Merging firm-level DataFrames where both have `initial_year` column

**Solution**: Drop `initial_year` from right DataFrame before merge (see Column Duplication Prevention)

### Issue 2: High Missing Values in Geographic Distances

**Possible Causes**:
1. Missing ZIP codes in source data (`firmzip` or `comzip` is NaN)
2. ZIP code normalization failure (invalid format)
3. `uszipcode` lookup failure (ZIP not in database)

**Debugging**:
- Check `build_zipcode_database()` logs for conversion success/failure rates
- Check `calculate_vc_company_distances()` logs for missing ZIP/coordinate counts
- Verify ZIP code normalization handles 4-digit codes correctly

**Solution**: Ensure ZIP codes are normalized (5-digit with leading zeros) and `uszipcode` library is installed

### Issue 3: Empty `initial_*` Variables

**Cause**: Using `inner` join excludes firms not in source DataFrames

**Solution**: Use `right` join to preserve all firms in `initial_year_df` (see Data Preservation Strategy)

### Issue 4: `initial_status_missing` Inconsistency

**Problem**: `initial_status_missing=1` but some `initial_*` values are present

**Cause**: `initial_status_cols` calculated from `final_df` before all merges complete

**Solution**: Recalculate `initial_status_cols` from `tmp` DataFrame AFTER all merges (see Cell 12 in notebook)

### Issue 5: Slow Geographic Distance Calculation

**Cause**: Nested `for` loops over large datasets

**Solution**: Vectorize using `pd.DataFrame.merge` (self-join) + numpy array operations (see Vectorization for Performance)

### Issue 6: `uszipcode` Library Not Found

**Solution**: Install in conda environment `research`
```bash
conda activate research
pip install uszipcode
```

**Note**: May require downgrading `sqlalchemy_mate` and `SQLAlchemy` for compatibility

### Issue 7: Validation Cell Placement

**User Preference**: Validation code should be placed at the **bottom** of the notebook (not in the middle)

**Solution**: Always append validation cells to the end of `preprc_imprint.ipynb`

---

## Environment Setup

### Conda Environment
- **Name**: `research`
- **Location**: `/opt/homebrew/Caskroom/miniforge/base/envs/research`

### Required Libraries
- `pandas`
- `numpy`
- `networkx`
- `uszipcode` (for geographic distance)
- `joblib` (for parallel processing)
- `tqdm` (for progress bars)
- `pyarrow` (for Parquet I/O)

### Python Version
- Python 3.11 (as indicated by path)

---

## Contact and Maintenance

**Maintainer**: Suengjae Hong  
**Last Updated**: 2025-11-07  
**Document Version**: 1.0

**Related Documents**:
- `research_history.md`: Overall research history
- `notebooks/imprinting_analysis_history.md`: Imprinting analysis history (Korean)
- `README.md`: Project README
- `USAGE_GUIDE.md`: Usage guide

---

**End of Requirements Document**

