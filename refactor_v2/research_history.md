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

**Market Heat and New Venture Funding Demand Variables**

Added two industry-level macro variables:

**Market Heat Variable**

1. **Definition**: Measures relative activity of VC fund raising at industry level
2. **Formula**: `Market heat_t = ln((VC funds raised_t × 3) / Σ_{k=t-3}^{t-1} VC funds raised_k)`
   - Numerator: Current year (t) unique VC funds raised × 3
   - Denominator: Sum of VC funds raised in antecedent 3 years (t-3, t-2, t-1)
3. **Interpretation**:
   - `market_heat > 0`: Hot market (active fund raising)
   - `market_heat < 0`: Cold market (sluggish fund raising)
4. **Implementation**:
   - Function: `calculate_market_heat(fund_df, ...)` in `firm_variables.py`
   - Output: Year-level data (year, market_heat columns)
   - Edge cases: `NaN` if denominator = 0 or ratio ≤ 0
   - Integration: Merge to firm-year panel by year (same value for all firms in same year)
5. **Usage**: For Hypothesis 1 analysis (market heat effects on VC behavior)

**New Venture Funding Demand Variable**

Added New Venture Funding Demand calculation as an industry-level macro variable:

1. **Definition**: Measures demand for VC funding based on the natural log of the total number of new ventures that received a first round of VC financing in the United States in the current calendar year
2. **Formula**: `new_venture_demand_t = ln(count of first-round US ventures in year t)`
   - First round identification: `RoundNumber == min(RoundNumber)` per company
   - US filter: `comnation == 'United States'`
   - Current year: Uses year t value (NOT lagged - this is raw dataset)
   - Natural log transformation
3. **Implementation**:
   - Function: `calculate_new_venture_funding_demand(round_df, company_df, ...)` in `firm_variables.py`
   - Output: Year-level data (year, new_venture_demand columns)
   - Edge cases: `NaN` for zero count
   - Integration: Merge to firm-year panel by year (same value for all firms in same year)
4. **Usage**: Control variable for venture-side demand fluctuations
5. **Note**: This is a RAW dataset variable. For panel analysis, lagging should be done during regression analysis (e.g., using year t-1 value)

**Years Since Initial Network Variable**

Added Years Since Initial Network calculation:

1. **Definition**: Number of years since initial network formation
2. **Formula**: `years_since_init = year - initial_year`
3. **Implementation**:
   - Calculated after merging all data into `final_df`
   - `NaN` for firms without `initial_year` (established firms)
4. **Usage**: Event-time based analysis (years since initial network = 0, 1, 2, ...)
5. **Variable name**: `years_since_init` (short and intuitive)

**Initial Period Variables (t1~t3 기간 투자 행위/특성)**

Added 7 initial period variables that capture VC firm investment behavior and characteristics during the imprinting period (t1~t3):

1. **`initial_early_stage_ratio`**: Average early stage investment ratio during t1~t3
   - Imprinting effect: Initial investment style may have lasting influence on future investment patterns

2. **`initial_industry_blau`**: Average industry diversity (Blau index) during t1~t3
   - Imprinting effect: Initial industry portfolio may influence future diversity

3. **`initial_inv_num`**: Total investment count during t1~t3 (sum)
   - Imprinting effect: Initial activity/experience may influence future investment behavior

4. **`initial_inv_amt`**: Total investment amount during t1~t3 (sum)
   - Imprinting effect: Initial investment scale may influence future resource allocation

5. **`initial_firmage`**: Firm age at t1 (initial_year)
   - Imprinting effect: Organizational age at initial period may influence future behavior

6. **`initial_market_heat`**: Average market heat during t1~t3
   - Imprinting effect: Initial market conditions may influence future strategy

7. **`initial_new_venture_demand`**: Average new venture demand during t1~t3
   - Imprinting effect: Initial market demand may influence future investment patterns

8. **`initial_geo_dist_copartner_*`** (6 variables): Average geographic distances to co-investment partners during t1~t3
   - Variables: mean, min, max, median, weighted_mean, std
   - Imprinting effect: Initial geographic proximity to partners may influence future network formation

**Implementation**:
- Function: `calculate_initial_period_variables()` in `vc_analysis/network/imprinting.py`
- Function: `calculate_initial_period_geographic_distances()` in `vc_analysis/network/imprinting.py`
- Notebook: `preprc_imprint.ipynb` Cell 5 (Step 3: Calculation, Step 4-1: Merge, Step 4-2: Geographic Distance Merge)
- Calculation method:
  - Firm-year variables: Average (ratios/diversity) or sum (investment counts/amounts) during t1~t3
  - Market-level variables: Average during t1~t3
  - Firm age: Value at t1 (initial_year)
  - Geographic distances: Average of firm-year level co-partner distances during t1~t3
- Data preservation strategy:
  - Join method: Uses `right` join to preserve all firms in `initial_year_df`
  - Missing handling: Firms in `initial_year_df` that don't exist in `firm_vars_df` or `copartner_dist_df` are still included in results (marked as NaN)
  - Debugging logs: Outputs data size, year range, and non-null counts at each step to track causes of missing values
- Column duplication prevention:
  - `initial_year` column duplication issue resolved: Remove `initial_year` from right DataFrame before merge
  - Reason: Both `result` and merged DataFrames are firm-level, so same `firmname` means same `initial_year` (duplicate)
  - Method: Remove `initial_year` using `drop(columns=['initial_year'], errors='ignore')` before merge, then merge using only `on=[firm_col]`
  - Result: No `initial_year_x`, `initial_year_y` suffixes - only `result`'s `initial_year` is preserved

**Geographic Distance Variables**

Added geographic distance calculations based on ZIP codes using Haversine formula:

1. **VC-Company Distances** (firm-year level):
   - `geo_dist_company_mean`: Average distance to invested companies
   - `geo_dist_company_min`: Minimum distance to invested companies
   - `geo_dist_company_max`: Maximum distance to invested companies
   - `geo_dist_company_median`: Median distance (recommended: robust to outliers)
   - `geo_dist_company_weighted_mean`: Investment amount-weighted average distance
   - `geo_dist_company_std`: Standard deviation of distances (recommended: measures distance dispersion)

2. **VC-Co-Partner Distances** (firm-year level):
   - `geo_dist_copartner_mean`: Average distance to co-investment partners
   - `geo_dist_copartner_min`: Minimum distance to co-investment partners
   - `geo_dist_copartner_max`: Maximum distance to co-investment partners
   - `geo_dist_copartner_median`: Median distance (recommended: robust to outliers)
   - `geo_dist_copartner_weighted_mean`: Investment amount-weighted average distance
   - `geo_dist_copartner_std`: Standard deviation of distances (recommended: measures distance dispersion)

3. **Initial Period Geographic Distances** (t1~t3):
   - `initial_geo_dist_copartner_*`: All 6 co-partner distance variables aggregated during t1~t3

**Implementation**:
- Functions: `calculate_vc_company_distances()`, `calculate_vc_copartner_distances()` in `vc_analysis/distance/geographic.py`
- Initial period function: `calculate_initial_period_geographic_distances()` in `vc_analysis/network/imprinting.py`
- Notebook: `preprc_imprint.ipynb` Cell 4 (calculation), Cell 5 (merge)
- ZIP code handling:
  - Normalization: 5-digit string format with leading zeros
  - Conversion: `uszipcode` library or pre-built database
  - Haversine formula: Great-circle distance calculation (unit: km)
- Recommended variables: Median (robust), weighted mean (investment-weighted), std (dispersion)

**HQ Dummy Variables Expansion**

Extended HQ location dummies to include individual state indicators:
- `firm_hq_CA`: California = 1
- `firm_hq_MA`: Massachusetts = 1
- `firm_hq_NY`: New York = 1
- `firm_hq`: CA or MA = 1 (kept for backward compatibility)

**Missing Flags Criticality Classification**

Added comprehensive documentation for 6 missing flag columns with criticality classification:

1. **Flag Definitions**:
   - `initial_status_missing`: Summary flag (1 if any `initial_*` is NaN)
   - `initial_missing_outside_cohort`: Low criticality (design-consistent, Control group)
   - `initial_missing_no_partners`: Medium criticality (solo investments, conditional inclusion)
   - `initial_missing_no_centrality`: High criticality (data issue, consider exclusion)
   - `initial_missing_other`: High criticality (unknown cause, consider exclusion)
   - `rep_missing_fund_data`: Medium criticality (fund data missing, conditional inclusion)

2. **Criticality-Based Sampling**:
   - Low + Medium: Include in analysis
   - High: Consider exclusion
   - Recommended filter excludes High criticality flags

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

**Step 7: Missing Flags and Criticality Classification**

To handle cases where `initial_*` variables are NaN, 6 diagnostic flag columns are created:

| Column | Criticality | Definition | Analysis Treatment |
|--------|-------------|------------|-------------------|
| `initial_status_missing` | Summary | All `initial_*` columns are NaN (comprehensive flag) | 1 if any of the 5 flags below is 1 |
| `initial_missing_outside_cohort` | **Low** | Initial year outside cohort<br>- `initial_year_full` exists but outside START_YEAR~END_YEAR<br>- `initial_year` is NaN | ✅ **Include in analysis**<br>- Design-consistent (Control group)<br>- Keep `initial_*` as NaN |
| `initial_missing_no_partners` | **Medium** | No partners at founding<br>- `initial_year` exists but `n_initial_partners` or `n_partner_years` is 0 or NaN<br>- Or firm not in `initial_ties_df` | ⚠️ **Conditional inclusion**<br>- Interpretable as "Solo investment" group<br>- Can include but interpret with caution |
| `initial_missing_no_centrality` | **High** | Partners exist but all centrality values are NaN<br>- `initial_year` exists and partners exist but all `initial_*` columns are NaN | ❌ **Consider exclusion**<br>- Possible data issue (matching/calculation error)<br>- Exclude or investigate separately |
| `initial_missing_other` | **High** | Other cases not covered above | ❌ **Consider exclusion**<br>- Unknown cause, needs investigation<br>- Exclude or investigate separately |
| `rep_missing_fund_data` | **Medium** | Missing fund-based VC Reputation variables<br>- Any of `rep_avg_fum`, `rep_funds_raised`, `fundingAge` is NaN | ⚠️ **Conditional inclusion**<br>- Can exclude in final sampling<br>- Analysis possible without fund data (round-based variables exist) |

**Criticality-Based Sampling Guide**:
- **Include Low + Medium**: `initial_missing_outside_cohort`, `initial_missing_no_partners`, `rep_missing_fund_data`
- **Exclude High**: `initial_missing_no_centrality`, `initial_missing_other`
- **Recommended filter**: `analysis_df[(analysis_df['initial_missing_no_centrality'] == 0) & (analysis_df['initial_missing_other'] == 0)]`

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

**Document Version**: 1.5  
**Last Updated**: 2025-11-07  
**Total Lines**: ~690

### Update (2025-11-07 - Initial Period Variables Calculation Improvement)

**Join Method Optimization**

Improved data preservation in initial period variable calculations:

1. **Problem**: Previous `inner` join excluded firms from `initial_year_df` that didn't exist in `firm_vars_df` or `copartner_dist_df`, causing missing values in `initial_*` variables.

2. **Solution**: Changed join method from `inner` to `right` join:
   - `calculate_initial_period_variables()`: Preserves all firms in `initial_year_df`
   - `calculate_initial_period_geographic_distances()`: Preserves all firms in `initial_year_df`
   - Missing firms are included in results with NaN values (allows tracking and analysis)

3. **Debugging Enhancement**:
   - Added comprehensive logging at each calculation step:
     - Input data size and year range
     - After-merge data size
     - Period data (t1~t3) size
     - Non-null value counts
   - Helps identify root causes of missing values (e.g., year range mismatch, missing source data)

4. **Column Duplication Prevention**:
   - **Problem**: When merging firm-level DataFrames, `initial_year` column exists in both `result` and merged DataFrames, causing pandas to create `initial_year_x` and `initial_year_y` suffixes
   - **Root Cause**: Both DataFrames are firm-level, so same `firmname` means same `initial_year` (duplicate by design)
   - **Solution**: Remove `initial_year` from right DataFrame before merge using `drop(columns=['initial_year'], errors='ignore')`, then merge using only `on=[firm_col]`
   - **Impact**: Clean merge without suffix columns, preserving only `result`'s `initial_year` (the authoritative source)

5. **Overall Impact**:
   - All firms in `initial_year_df` are preserved in results
   - Better tracking of missing value causes
   - More transparent data flow for debugging
   - No column duplication issues (`initial_year_x`, `initial_year_y` eliminated)






