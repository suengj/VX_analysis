# Research History - refactor_v2 Project

**Purpose**: Track all research activities and analyses conducted using the refactor_v2 framework  
**Last Updated**: 2025-11-07  
**Maintainer**: Suengjae Hong

---

## Table of Contents

1. [Imprinting Analysis](#imprinting-analysis)
2. [Tie Formation Analysis](#tie-formation-analysis) (Planned)

---

# Imprinting Analysis

## Overview

### Update (2025-11-07)

**VC Reputation Index Implementation**

Added comprehensive VC reputation calculation module with 6 component variables:

1. **Component Variables** (5-year rolling window [t-4, t]):
   - `rep_portfolio_count`: Unique portfolio companies invested in [t-4, t]
   - `rep_total_invested`: Total funds invested [t-4, t] (RoundAmountDisclosedThou sum)
   - `rep_avg_fum`: Average funds under management at year t
     - Logic: Funds raised before t that are still open (fundiniclosing parsing: dd.mm.yyyy format)
     - Parsing failure monitoring: Logs failure rate for fundiniclosing date parsing
   - `rep_funds_raised`: Number of funds raised [t-4, t] (unique fundname count)
   - `rep_ipos`: Portfolio firms taken public [t-4, t]
     - Logic: Counts IPOs of companies invested in the past, where IPO occurred in [t-4, t]
   - `fundingAge`: VC age from first fund raising year (t - min(fundyear))

2. **Reputation Index Calculation**:
   - Step 1: Z-score standardize each variable BY YEAR
   - Step 2: Sum all 6 z-scores → `rep_index_raw`
   - Step 3: Min-Max scale to [0.01, 100] BY YEAR → `VC_reputation`

3. **Missing Data Handling**:
   - `rep_missing_fund_data` flag: 1 if any fund-based variable (rep_avg_fum, rep_funds_raised, fundingAge) is missing
   - Can be used to exclude observations in final sampling
   - Merge strategy: `how='left'` to preserve round_df-based firm-year structure

4. **Implementation Details**:
   - Module: `vc_analysis/variables/firm_variables.py`
   - Functions: `calculate_vc_reputation()` (main), 6 individual variable functions
   - Constants: `REPUTATION_SETTINGS` in `constants.py`
   - Integration: Added to `preprc_imprint.ipynb` merge pipeline (Step 4)

### Update (2025-10-28)

Addendum: Final Sampling & Export
- Analysis filter: `analysis_df` created using toggleable requirements (year range, firm basics, centrality presence via `in_network` or any centrality column, optional initial status/performance).
- Export: Parquet (primary), Feather (fallback), and capped CSV sample with `CSV_SAMPLE_N`, random/head options.
- R-ready: Files readable via `arrow::read_parquet` / `arrow::read_feather`.
- Index reset applied prior to export.

- Implemented Full History approach for `initial_year` and partner-weighted initial status (mean/max/min) in `preprc_imprint.ipynb` using `refactor_v2` modules.
- Resolved data loading issues: Excel serial `rnddate` conversion, merged `firmtype2`, removed `Undisclosed Firm/Company`, firm/company dedup, round exact-duplicate removal.
- Centrality config: unweighted defaults; normalization toggles per measure; `constraint` NaN→0 and cap at 1.0; added `pwr_max`, `ego_dens`.
- Final merge base corrected to `firm_vars_df_filtered`; added `in_network` dummy and optional zero-fill per config.
- Diagnostic flags for initial status missing added; reclassified part of “other” into “no_partners” based on absence in `initial_ties_df`.
- Performance metrics fixed to current-year-only; Blau uses `comindmnr`; `firm_hq_CAMA` renamed to `firm_hq`.


**Research Question**: How do initial network partners' characteristics affect VC firm performance?

**Theoretical Framework**: Podolny's status theory + Network imprinting theory

**Key Hypothesis**:
- H1: Initial partners' high centrality → Better focal firm performance
- H2: Maximum partner status provides benefits beyond mean status
- H3: Minimum partner status creates penalties (contamination effect)

---

## Data Preparation

### 1. Data Loading & Filtering

**Date**: 2025-10-18  
**Notebook**: `preprc_imprint.ipynb` (Cell 1)

**Process**:
```python
# Load all data using vc_analysis package
data = loader.load_all_data()

# Critical preprocessing (automatic in loader):
# - Filter "Undisclosed Firm" from round data
# - Filter "Undisclosed Company" from round data
# - Merge firmtype2 to round data
```

**Results**:
- Round data: ~473,000 rows
- Company data: ~63,000 rows
- Firm data: ~15,000 rows
- Fund data: ~8,000 rows

---

### 2. Network Construction

**Date**: 2025-10-18  
**Notebook**: `preprc_imprint.ipynb` (Cell 2)

**Configuration**:
- **Analysis Period**: 2000-2005 (6-year cohort)
- **Network Window**: 5 years (t-5 to t-1)
- **Exclusions**: Angel, Other, Null firmtype2

**Process**:
```python
# 1. Filter by VC type (exclude Angel, Other, Null)
filtered_round = data_filter.filter_by_vc_type(
    data['round'], 
    ['Angel', 'Other'], 
    'firmtype2',
    exclude_null=True
)

# 2. Construct networks for each year
networks = construction.construct_networks_for_years(
    filtered_round, 
    years=list(range(START_YEAR, END_YEAR + 1)), 
    time_window=TIME_WINDOW
)

# 3. Calculate centrality measures
centrality_df = centrality.compute_centralities_for_networks(networks)
```

**Network Statistics** (2000-2005):
```
Year    Nodes   Edges   Density
2000    2109    22611   0.010
2001    1950    20123   0.011
2002    1723    16834   0.011
2003    1598    14892   0.012
2004    1512    13567   0.012
2005    1489    12998   0.012

Average: 1,730 nodes, 16,838 edges
```

**Centrality Measures Calculated**:
- `dgr_cent`: Degree centrality (unweighted, unnormalized)
- `btw_cent`: Betweenness centrality (unweighted, unnormalized)
- `pwr_p0`, `pwr_p75`, `pwr_p99`: Bonacich power centrality (unweighted, normalized)
- `pwr_max`: 1/λ_max (maximum beta for power centrality)
- `constraint`: Burt's structural holes (unweighted, capped at 1.0, NaN → 0)
- `ego_dens`: Ego network density (unweighted, not normalized)

**Key Design Decisions**:
1. **Unweighted networks**: All centrality measures use binary ties (not weighted by co-investment frequency)
2. **Constraint NaN handling**: Isolated nodes (degree=0) have constraint=0 (configurable)
3. **Constraint capping**: Values >1.0 are capped at 1.0 (theoretical maximum for cliques)
4. **Power centrality**: Normalized to [0,1] range for interpretability

---

### 3. Initial Network Partner Characteristics

**Date**: 2025-10-18  
**Notebook**: `preprc_imprint.ipynb` (Cell 3)

**Theoretical Background**:
- **Imprinting Theory**: Initial partnerships have lasting effects on firm trajectory
- **Status Theory** (Podolny): Partner status signals focal firm quality
- **Research Design**: Calculate partner characteristics during "imprinting period" (t1 to t3)

**Methodology: Option A (Full History)**

**Step 1: Identify Initial Year (Full Data)**
```python
# Use ALL available data (1970-2022) to find true initial year
full_initial_year_df = imprinting.identify_initial_year(
    filtered_round,  # All years, Angel/Other/Null excluded
    firm_col='firmname',
    year_col='year'
)

# Result: Each firm's first year with any network ties
# Example: Sequoia Capital → initial_year = 1972
```

**Step 2: Sample Filtering (Cohort Selection)**
```python
# Select cohort: firms with initial ties in START_YEAR ~ END_YEAR
initial_year_df = full_initial_year_df[
    full_initial_year_df['initial_year'].between(START_YEAR, END_YEAR)
].copy()

# For 2000-2005 cohort:
# - Total firms (all history): ~15,000
# - Analysis firms (2000-2005 cohort): ~3,500 (23%)
```

**Step 3: Network Construction (Imprinting Period)**
```python
# Identify needed years for imprinting period (t1, t2, t3)
IMPRINTING_PERIOD = 3

needed_years = set()
for _, row in initial_year_df.iterrows():
    t1 = int(row['initial_year'])
    for offset in range(IMPRINTING_PERIOD):
        needed_years.add(t1 + offset)

# Construct networks ONLY for needed years
imprinting_networks = construction.construct_networks_for_years(
    filtered_round,  # All data (Angel/Other/Null excluded)
    years=sorted(needed_years),
    time_window=TIME_WINDOW  # 5-year window
)

# Calculate centrality for imprinting period
imprinting_centrality_df = centrality.compute_centralities_for_networks(
    imprinting_networks
)
```

**Step 4: Extract Initial Partners**
```python
# For each firm, extract ALL partners during t1~t3
initial_partners_df = imprinting.extract_initial_partners(
    filtered_round,  # All data
    imprinting_networks,  # Networks for t1~t3
    initial_year_df,  # Cohort firms
    imprinting_period=IMPRINTING_PERIOD,
    firm_col='firmname'
)

# Result: Firm-Partner-Year triples
# Example: (Sequoia, Kleiner Perkins, 1972), (Sequoia, Accel, 1973), ...
```

**Step 5: Merge Partner Centrality**
```python
# Link partners to their centrality at tied year
initial_ties_with_cent = imprinting.calculate_partner_centrality_by_year(
    initial_partners_df,
    imprinting_centrality_df,  # Centrality at t1, t2, t3
    firm_col='firmname'
)

# Result: Partner centrality at the time of tie formation
# Example: Kleiner Perkins in 1972 had dgr_cent=25, btw_cent=0.15, ...
```

**Step 6: Compute Initial Partner Status (Partner-Weighted)**

**Calculation Logic** (Updated 2025-10-18):

**Previous Method** (Observation-weighted):
```
Mean: (1 / (3 × |P|)) × Σ_j Σ_t Centrality(P_j, t)
Max:  max_{j,t} Centrality(P_j, t)
Min:  min_{j,t} Centrality(P_j, t)
```

**Current Method** (Partner-weighted):
```python
# Step 1: Calculate each partner's time-averaged centrality
# Partner B: (cent_t1 + cent_t2) / 2 = avg_B
# Partner C: (cent_t1 + cent_t3) / 2 = avg_C
# Partner D: cent_t2 = avg_D

# Step 2: Aggregate across partners
# Option 1 (Mean): (avg_B + avg_C + avg_D) / |P|
# Option 2 (Max):  max(avg_B, avg_C, avg_D)
# Option 3 (Min):  min(avg_B, avg_C, avg_D)
```

**Implementation**:
```python
initial_ties_df = imprinting.compute_all_initial_partner_status(
    initial_ties_with_cent,
    centrality_measures=None,  # All measures
    firm_col='firmname'
)
```

**Output Variables** (for each centrality measure):
- `initial_{measure}_mean`: Mean of partner averages (Option 1 - Control)
- `initial_{measure}_max`: Maximum partner average (Option 2 - Benefit)
- `initial_{measure}_min`: Minimum partner average (Option 3 - Penalty)
- `n_initial_partners`: Number of unique partners
- `n_partner_years`: Total partner-year observations

**Example Output**:
```
firmname          initial_year  n_initial_partners  initial_dgr_cent_mean  initial_dgr_cent_max  initial_dgr_cent_min
Sequoia Capital   1972          5                   18.5                   32.0                  8.0
Kleiner Perkins   1973          7                   22.3                   45.0                  12.0
Accel Partners    1985          3                   15.2                   28.0                  6.0
```

---

## Research Design Rationale

### Why Option A (Full History)?

**Problem with Window-Based Approaches**:
- If we only use 2000-2005 data, we misidentify "initial" ties
- Example: Sequoia's first tie was 1972, not 2000
- Using 2000 as "initial year" creates measurement error

**Option A Solution**:
1. Use ALL data (1970-2022) to find true initial year
2. Calculate partner characteristics at TRUE imprinting period (t1~t3)
3. Then filter to cohort of interest (e.g., 2000-2005)

**Benefits**:
- ✅ Accurate initial year identification
- ✅ True imprinting period measurement
- ✅ Correct partner centrality (at time of tie)
- ✅ Flexible cohort selection

**Trade-offs**:
- Requires full historical data
- More complex computation
- Left-censoring for very early firms (pre-1970)

---

### Why Partner-Weighted Calculation?

**Observation-Weighted** (Previous):
- Treats each partner-year as equal observation
- Problem: Partners appearing in multiple years get more weight
- Example: Partner B (t1, t2) counts twice vs Partner C (t1 only)

**Partner-Weighted** (Current):
- First averages each partner's centrality across years
- Then aggregates across partners
- Benefit: Each partner contributes equally regardless of years
- Example: Partner B and C both count once

**Rationale**:
- Research question is about PARTNER diversity, not temporal diversity
- Partners are the theoretical unit of analysis
- More intuitive interpretation: "average quality of partners"

---

## Key Findings (Preliminary)

### Descriptive Statistics

**Sample**: 2000-2005 cohort (N = 3,500 firms)

**Initial Partners**:
- Mean partners: 4.2 (SD = 3.1)
- Range: 1 - 28 partners
- Mean partner-years: 8.5 (SD = 6.8)

**Partner Status (Degree Centrality)**:
- Mean: 18.5 (SD = 12.3)
- Max: 45.2 (SD = 28.7)
- Min: 6.8 (SD = 5.2)

**Correlation Matrix**:
```
                  Mean    Max     Min
Mean              1.00
Max               0.85    1.00
Min               0.72    0.48    1.00
```

**Interpretation**:
- Max and Min are moderately correlated (0.48)
- Suggests independent variation in "benefit" vs "penalty"
- Supports testing both effects separately

---

## Next Steps

### Planned Analyses

1. **Merge Performance Data**
   - IPO exits (by year)
   - M&A exits (by year)
   - Total exits
   - Survival analysis

2. **Control Variables**
   - Focal firm age
   - Focal firm centrality (during imprinting)
   - Industry diversity
   - Geographic diversity
   - Early stage focus

3. **Statistical Models**
   - DV: Firm performance (exits, survival)
   - IV: Partner status (mean, max, min)
   - Controls: Focal characteristics
   - Method: Poisson regression (count data)

4. **Robustness Checks**
   - Different cohorts (1990-1995, 2005-2010)
   - Different imprinting periods (1-year, 5-year)
   - Different centrality measures (betweenness, power)
   - Different partner aggregations (median, weighted)

---

## Code Modules Used

### Core Modules
- `vc_analysis.data.loader`: Data loading with Undisclosed filtering
- `vc_analysis.data.filter`: VC type filtering
- `vc_analysis.network.construction`: Network building
- `vc_analysis.network.centrality`: Centrality calculation
- `vc_analysis.network.imprinting`: Initial ties identification

### Key Functions
```python
# Data loading
data = loader.load_all_data()

# Filtering
filtered = data_filter.filter_by_vc_type(data['round'], ['Angel', 'Other'], 'firmtype2', True)

# Network construction
networks = construction.construct_networks_for_years(filtered, years, time_window=5)

# Centrality calculation
cent_df = centrality.compute_centralities_for_networks(networks)

# Imprinting analysis
initial_year_df = imprinting.identify_initial_year(filtered, 'firmname', 'year')
initial_partners = imprinting.extract_initial_partners(filtered, networks, initial_year_df, 3, 'firmname')
initial_ties_cent = imprinting.calculate_partner_centrality_by_year(initial_partners, cent_df, 'firmname')
initial_status = imprinting.compute_all_initial_partner_status(initial_ties_cent, None, 'firmname')

# VC Reputation calculation
reputation_df = firm_variables.calculate_vc_reputation(
    round_df=data['round'],
    company_df=data['company'],
    fund_df=data['fund'],
    year_col='year',
    window_years=5
)
```

---

## Files Generated

### Notebook
- `/refactor_v2/notebooks/preprc_imprint.ipynb`

### Data Outputs (Planned)
- `initial_ties_2000_2005.csv`: Initial partner characteristics
- `performance_2000_2005.csv`: Firm performance data
- `analysis_ready_2000_2005.csv`: Merged dataset for regression

### Documentation
- This file: `research_history.md`

---

## References

**Theoretical**:
- Podolny, J. M. (1993). A status-based model of market competition. *American Journal of Sociology*, 98(4), 829-872.
- Marquis, C., & Tilcsik, A. (2013). Imprinting: Toward a multilevel theory. *Academy of Management Annals*, 7(1), 195-245.

**Methodological**:
- Bonacich, P. (1987). Power and centrality: A family of measures. *American Journal of Sociology*, 92(5), 1170-1182.
- Burt, R. S. (1992). *Structural Holes*. Harvard University Press.

---

**End of Imprinting Analysis Section**

---

# Tie Formation Analysis

**Status**: Planned  
**Research Question**: TBD  
**Expected Start Date**: TBD

(This section will be populated when tie formation analysis begins)

---

**Document Version**: 1.1  
**Last Updated**: 2025-11-07  
**Total Lines**: ~550






