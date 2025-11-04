# VC Analysis Refactor V2 - AI Context Guide

**Purpose**: Quick reference for AI to understand and work with this codebase  
**Token-Optimized**: Core concepts only, no verbose explanations

---

## 🎯 Project Overview

**What**: VC network analysis framework (Python preprocessing + R analysis)  
**From**: Monolithic R scripts (2,858 lines, 4 files)  
**To**: Modular system (41 modules, 10,000 lines)

**Key Analyses**:
1. **CVC**: Corporate VC tie formation (1990-2000)
2. **Imprinting**: Initial network ties effects (1970-2011)

---

## 📁 File Structure (Critical Paths)

```
/VC/
├── refactor_v2/                     # Main project
│   ├── vc_analysis/                 # Python package (21 files)
│   │   ├── config/paths.py          # DATA_DIR, OUTPUT_DIR
│   │   ├── data/loader.py           # load_*_data()
│   │   ├── network/construction.py  # create_bipartite_network()
│   │   └── utils/validation.py      # validate_schema()
│   ├── R/regression/                # R regression scripts
│   ├── testing/                     # Test infrastructure
│   │   ├── cvc_flow/test_cvc_full_flow.R
│   │   └── imprinting_flow/test_imprinting_full_flow.R
│   ├── COMPLETE_DOCUMENTATION.md    # Full reference (5000+ lines)
│   └── CONTEXT.md                   # This file
│
└── R/refactor/                      # R modules
    ├── load_all_modules.R           # Master loader
    ├── R/
    │   ├── config/                  # paths.R, constants.R, parameters.R
    │   ├── core/                    # network_construction.R, centrality_calculation.R, sampling.R
    │   ├── analysis/                # imprinting_analysis.R, performance_analysis.R
    │   └── utils/                   # error_handler.R, checkpoint.R
    └── ERROR_MEMO.md                # All bugs & fixes

**Original Code** (reference only):
- /VC/R/CVC_preprcs_v4.R (1,475 lines)
- /VC/R/imprinting_Dec18.R (883 lines)
```

---

## 🔑 Core Concepts

### Data Flow

```
Raw CSV/Excel
    ↓ (Python: vc_analysis.data)
Filtered & Merged
    ↓ (Python: vc_analysis.network)
Bipartite Network (VC-Company)
    ↓ (R: VC_matrix)
One-Mode Network (VC-VC)
    ↓ (R: VC_centralities)
Centrality Measures
    ↓ (R: VC_sampling_opt1)
Sampled Dataset
    ↓ (R: clogit/pglm)
Statistical Results
```

### Key Data Structures

**Input**:
- `comdta`: Companies (comname, comnation, comsitu, date_sit, ipoExit, MnAExit)
- `firmdta`: VC Firms (firmname, firmnation, firmfounding, firmtype, firmtype2)
- `round`: Investment Rounds (comname, firmname, rnddate, year, month, RoundAmountDisclosedThou)

**Intermediate**:
- `edgeRound`: Network edges (year, firmname, event)
  - `event = paste(comname, year, sep="-")`
- `centrality`: Centrality measures (firmname, year, dgr, btw, pwr_*, constraint, density)

**Output**:
- CVC: Dyad-level (leadVC, coVC, realized, centralities, ages, types)
- Imprinting: Firm-level (firmname, initial_year, partner/focal centralities, exits)

---

## 🛠️ Essential Functions

### R Core Functions

**Network Construction**:
```r
VC_matrix(round, year, time_window = 5, edge_cutpoint = NULL)
# Returns: igraph object (VC-to-VC one-mode projection)
# Logic: Filter rounds → Bipartite → Project → Apply cutpoint
```

**Centrality Calculation**:
```r
VC_centralities(round, year, time_window, edge_cutpoint = NULL)
# Returns: data.table (firmname, year, dgr, btw, pwr_*, constraint, density)
# Metrics: Degree, Betweenness, Power (3 variants), Constraint
```

**Imprinting - Initial Ties**:
```r
VC_initial_ties(edge_raw, y, time_window = 3)
# Returns: data.frame (firmname, initial_partner, tied_year)
# Logic: For each year y, create network → Extract all edges
```

**Imprinting - Partner Centrality**:
```r
VC_initial_partner_centrality(initial_partner_list, cent)
# Returns: data.frame (firmname, initial_year, p_dgr, p_btw, p_pwr_max, ...)
# Aggregation: Degree=SUM, Others=MEAN
```

**Imprinting - Focal Centrality**:
```r
VC_initial_focal_centrality(initial_partner_list, cent)
# Returns: data.frame (firmname, initial_year, f_dgr, f_btw, f_pwr_max, ...)
# Aggregation: All=MEAN
```

**Sampling**:
```r
leadVC_identifier(round)
# Returns: data.frame (comname, firmname, rnddate, dealno)
# Logic: Largest investment + Earliest entry

VC_sampling_opt1(round, LeadVCdta, quarter, ratio = 10, focal_quarter)
# Returns: data.frame (quarter, leadVC, coVC, realized)
# Logic: Cases (realized ties) + Controls (unrealized, 1:10 ratio)
```

**Performance**:
```r
VC_IPO_num(round, comdta)
# Returns: data.frame (firmname, ipo_count)

VC_MnA_num(round, comdta)
# Returns: data.frame (firmname, mna_count)

VC_Blau(categories)
# Returns: numeric (Blau diversity index, 0-1)
```

### Python Functions (Conceptual)

```python
# Data
loader.load_company_data(), load_firm_data(), load_round_data()
filter.filter_us_only(), filter_by_year(), exclude_angels()

# Network
construction.create_bipartite_network(df, year, time_window)
construction.project_to_onemode(G, nodes='firmname')
centrality.calculate_degree(), calculate_betweenness(), calculate_constraint()

# Distance
geographic.calculate_geodesic(coord1, coord2)
industry.calculate_industry_distance(sic1, sic2)

# Variables
performance.calculate_exits(), diversity.calculate_blau_index()
```

---

## 🚀 Common Usage Patterns

### Pattern 1: Basic Network Analysis

```r
# Load
source("load_all_modules.R")
round <- read.csv("round_Mar25.csv")

# Preprocess
round <- round %>%
  filter(firmname != "Undisclosed Firm") %>%
  mutate(year = year(rnddate))

# Analyze
net <- VC_matrix(round, year = 2000, time_window = 5)
cent <- VC_centralities(round, year = 2000, time_window = 5)

# Result: cent has centrality for all firms in 2000
```

### Pattern 2: CVC Analysis Pipeline

```r
# 1. Identify Lead VCs
LeadVCdta <- leadVC_identifier(round)

# 2. Calculate Centrality (parallel)
registerDoParallel(cores = 6)
cent_list <- foreach(y = 1990:2000, .combine = rbind) %dopar% {
  VC_centralities(round, y, time_window = 5)
}

# 3. Case-Control Sampling
sample <- VC_sampling_opt1(round, LeadVCdta, "quarter", ratio = 10, "1990Q1")

# 4. Merge & Model
library(survival)
model <- clogit(realized ~ ln_coVC_dgr + strata(syndicate_id), data = sample)
```

### Pattern 3: Imprinting Analysis Pipeline

```r
# 1. Create edge data
edge_raw <- round %>%
  mutate(event = paste(comname, year, sep = "-")) %>%
  select(firmname, year, event)

# 2. Identify Initial Ties (parallel)
registerDoParallel(cores = 6)
initial_raw <- foreach(y = 1970:2011, .combine = rbind) %dopar% {
  VC_initial_ties(edge_raw, y, time_window = 3)
}

# 3. Calculate Centrality
cent_list <- foreach(y = 1970:2011, .combine = rbind) %dopar% {
  VC_centralities(edge_raw, y, time_window = 3)
}

# 4. Partner & Focal Centrality
partner_cent <- VC_initial_partner_centrality(initial_ties, cent)
focal_cent <- VC_initial_focal_centrality(initial_ties, cent)

# 5. Model
library(pglm)
model <- pglm(n_exits_total ~ ln_p_dgr + ln_f_dgr, data = imp_dta, family = poisson)
```

### Pattern 4: Error Handling

```r
# Safe execution with retry
result <- safe_execute({
  VC_matrix(round, 2000, 5)
}, max_retries = 3)

# Checkpoint for long processes
cent <- checkpoint_execute("cent_2000", {
  VC_centralities(round, 2000, 5)
}, checkpoint_dir = "checkpoints/")
```

---

## ⚠️ Common Issues & Quick Fixes

### Issue: "object not found"
```r
# Fix: Load modules
source("/path/to/load_all_modules.R")
```

### Issue: "Non-bipartite edge found"
```r
# Fix: VC_matrix handles this automatically
# But ensure: event = paste(comname, year, sep = "-")
```

### Issue: "Many-to-many relationship"
```r
# Fix: Remove duplicates
data <- data %>% group_by(firmname) %>% slice(1) %>% ungroup()
```

### Issue: Date format errors
```r
# Fix Excel dates:
rnddate <- as.Date(rnddate, origin = "1899-12-30")

# Fix string dates:
rnddate <- as.Date(rnddate, format = "%Y-%m-%d")
```

### Issue: Missing columns
```r
# Check actual columns:
names(data)

# Common fixes:
# comcountry → comnation
# quar → create quarter manually
```

### Issue: Slow execution
```r
# Fix 1: Parallel processing
registerDoParallel(cores = 6)

# Fix 2: Sample for testing
round_test <- round %>% sample_frac(0.1)

# Fix 3: Use data.table
library(data.table)
setDT(round)
```

---

## 🧪 Testing & Validation

**CVC Test**: `/refactor_v2/testing/cvc_flow/test_cvc_full_flow.R`
- Duration: ~4 minutes
- Output: 6 data files (184 MB) + 6 result files

**Imprinting Test**: `/refactor_v2/testing/imprinting_flow/test_imprinting_full_flow.R`
- Duration: ~40 minutes
- Output: 7 data files (~200 MB) + 4 result files

**Run Tests**:
```bash
cd /path/to/refactor_v2/testing/cvc_flow
Rscript test_cvc_full_flow.R > logs/test.log 2>&1 &

# Monitor
tail -f logs/test.log
```

---

## 📊 Data Requirements

**Minimum Required Columns**:
- `comdta`: comname, comnation, comsitu, date_sit
- `firmdta`: firmname, firmnation, firmfounding, firmtype
- `round`: comname, firmname, rnddate, year

**Critical Preprocessing**:
```r
# 1. Filter Undisclosed
round <- round %>%
  filter(firmname != "Undisclosed Firm",
         comname != "Undisclosed Company")

# 2. US Only
round <- round %>%
  left_join(firmdta %>% select(firmname, firmnation)) %>%
  left_join(comdta %>% select(comname, comnation)) %>%
  filter(!is.na(firmnation), !is.na(comnation))

# 3. Exclude Angels
angel_firms <- firmdta %>% filter(firmtype2 == "Angel") %>% pull(firmname)
round <- round %>% filter(!firmname %in% angel_firms)

# 4. Create event
round <- round %>% mutate(event = paste(comname, year, sep = "-"))
```

---

## 🎓 Key Algorithms

### Bipartite Projection
```
Input: VC-Company edges
1. Create bipartite graph (VC nodes type=0, Company nodes type=1)
2. Project to VC-VC (share company = edge)
3. Edge weight = # shared companies
Output: VC-VC network
```

### Power Centrality
```
Formula: c(α, β) = α(I - βA)⁻¹ A 1
β parameter: Based on max eigenvalue
  pwr_p50: β = 50% of max
  pwr_p75: β = 75% of max
  pwr_max: β ≈ max (near convergence)
```

### Case-Control Sampling
```
For each quarter:
1. Cases: All actual co-investors (realized ties)
2. Controls: Sample from potential ties (unrealized)
   - Same Lead VC
   - Active co-VCs in quarter
   - Exclude actual partners
   - Ratio: 1:10 (1 case : 10 controls)
3. Combine → Binary DV (realized)
```

### Imprinting
```
For each firm:
1. Find initial_year (first year with any tie)
2. Imprinting period: initial_year to initial_year + 3
3. Extract all partners in this period
4. Calculate partner centrality (degree=SUM, others=MEAN)
5. Calculate focal centrality (all=MEAN)
6. Track long-term performance (exits)
```

---

## 💡 AI Assistant Guidelines

**When User Asks to**:

1. **"Add new analysis"**:
   - Check `R/analysis/` for similar functions
   - Follow naming: `VC_<action>_<object>()`
   - Add to appropriate module (core/analysis/utils)
   - Update `load_all_modules.R`

2. **"Fix error"**:
   - Check `ERROR_MEMO.md` first
   - Common fixes: column names, date formats, NA handling
   - Add fix to ERROR_MEMO.md

3. **"Modify pipeline"**:
   - Identify stage in data flow diagram
   - Check test scripts for context
   - Preserve backward compatibility

4. **"Optimize performance"**:
   - Enable parallel processing first
   - Use data.table for large data
   - Add checkpoints for long processes
   - Profile with `Rprof()`

5. **"Understand code"**:
   - Start with COMPLETE_DOCUMENTATION.md sections
   - Check original code for context (CVC_preprcs_v4.R, imprinting_Dec18.R)
   - Compare with refactored version

**Critical Rules**:
- ✅ Never modify original code (`/R/*.R` files outside refactor/)
- ✅ Always update ERROR_MEMO.md when fixing bugs
- ✅ Preserve function signatures (backward compatibility)
- ✅ Add tests for new features
- ✅ Follow original logic (reference CVC_preprcs_v4.R, imprinting_Dec18.R)

---

## 📚 Quick Reference Links

**For Detailed Info, See**:
- Full reference: `COMPLETE_DOCUMENTATION.md` (5000+ lines)
- Quick start: `README.md`
- Usage examples: `USAGE_GUIDE.md`
- All bugs: `ERROR_MEMO.md`
- Test results: `testing/reports/FINAL_REPORT.md`

**Configuration Files**:
- R paths: `R/refactor/R/config/paths.R`
- R constants: `R/refactor/R/config/constants.R`
- R parameters: `R/refactor/R/config/parameters.R`
- Python config: `refactor_v2/vc_analysis/config/`

**Example Scripts**:
- CVC example: `R/refactor/examples/cvc_analysis_example.R`
- Imprinting example: `R/refactor/examples/imprinting_analysis_example.R`
- Full CVC test: `refactor_v2/testing/cvc_flow/test_cvc_full_flow.R`
- Full Imprinting test: `refactor_v2/testing/imprinting_flow/test_imprinting_full_flow.R`

---

**Context Version**: 1.0  
**Last Updated**: 2025-10-12  
**Optimized For**: AI quick understanding  
**Token Count**: ~3,500 tokens (efficient!)

**END OF CONTEXT**






