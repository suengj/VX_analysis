## Statistical Issues for Imprinting & VC Network Analysis

Last updated: 2024-12-15

### 📑 Table of Contents
- [Purpose and Scope](#purpose)
- [Study Index Choice: obs.year vs init.year](#index-choice)
- [Recommended Event-Study Specification](#event-study)
- [Fixed Effects: Identification and Pitfalls](#fixed-effects)
- [Model Specification: Zero-Inflated Negative Binomial (ZINB) with Mundlak Terms](#model-specification)
- [Missingness Handling using initial_xxx_missing](#missingness)
- [Measurement Windows and Alignment](#windows)
- [Censoring, Truncation, and Sample Construction](#censoring)
- [Inference and Standard Errors](#inference)
- [Outliers, Scaling, and Transformations](#scaling)
- [Multiple Testing and Dimensionality](#multi-testing)
- [Collinearity and Dropped Variables](#collinearity)
- [Selection Bias and In-Network Issues](#selection-bias)
- [Data Quality and Merge Integrity](#data-quality)
- [Robustness Checks (Menu)](#robustness)
- [Reporting and Reproducibility](#reporting)
- [Practical Checklist](#checklist)

---

### Purpose and Scope <a id="purpose"></a>
- Consolidate statistical considerations for the imprinting analysis:
  - VC firm’s initial network partners and whether their attributes persist for n years after the true initial year.
  - Social network measures (centrality, partner-weighted initial status), firm basics, and VC reputation.
  - Designed to align with our current codebase: `vc_analysis/network/*`, `vc_analysis/variables/firm_variables.py`, and notebook pipeline.

---

### Study Index Choice: obs.year vs init.year <a id="index-choice"></a>
- Observation panel index options:
  - VC–obs.year: canonical panel with calendar-year fixed effects (γ_t). Recommended for macro-shock control and comparability.
  - VC–init.year: aligns rows to each VC’s true initial year; harder to control for calendar shocks consistently across VCs.
- Recommendation:
  - Use VC–obs.year as the primary panel and add an event-time dimension τ = year − init_year (event-study).
  - This preserves year fixed effects (γ_t) while modeling dynamic persistence via τ dummies/splines.

---

### Recommended Event-Study Specification <a id="event-study"></a>
- Baseline model (count outcome example; adapt to DV):
  
```text
y_{i,t} = Σ_{k=0..n} β_k · 1[τ = k] + γ_i + γ_t + X_{i,t}·δ + ε_{i,t}
```

- Where:
  - τ = year − init_year; event-time indicating years since initial network formation.
  - γ_i: VC fixed effects; γ_t: calendar-year fixed effects.
  - X_{i,t}: time-varying controls (avoid "bad controls" that absorb the treatment channel).
  - Include leads (k < 0) for pre-trend checks where possible; otherwise, explicitly report limitations.
- Why this works here:
  - Handles staggered initial years while controlling for macro conditions (γ_t).
  - Maps cleanly to our generated variables: centrality by [t−TW, t−1], initial partner status, firm basics, and reputation.

---

### Fixed Effects: Identification and Pitfalls <a id="fixed-effects"></a>
- Using VC–init.year as the panel index complicates γ_t (calendar-year FE) definition; cohort FE (γ_init_year) can help but macro shocks remain imperfectly controlled.
- With VC–obs.year, γ_t is standard and interpretable; use τ to capture dynamic effects.
- Firm FE with initial_*:
  - initial_* variables are firm-level constants → with γ_i (firm FE), initial_* drop by collinearity.
  - Workarounds:
    - Exclude γ_i and use alternative FE (e.g., time FE + cohort-by-year FE).
    - Interact initial_* with time-varying elements (e.g., cohort or τ) if theoretical.
    - Model initial_* effects in a cross-section or in a two-step approach.

---

### Model Specification: Zero-Inflated Negative Binomial (ZINB) with Mundlak Terms <a id="model-specification"></a>

#### Why ZINB for Count Outcomes?

Our dependent variables (`perf_IPO`, `perf_all`, `perf_MnA`) are count outcomes (number of exits/IPOs/M&As). Count data often exhibit:
- **Overdispersion**: Variance exceeds the mean (common in count data)
- **Excess zeros**: Many firms have zero exits in a given year

**Zero-Inflated Negative Binomial (ZINB)** addresses both issues:
- **Negative Binomial component**: Handles overdispersion via a dispersion parameter (θ)
- **Zero-inflation component**: Models excess zeros separately via a logit process

#### Model Structure

The ZINB model consists of two parts:

**1. Conditional (Count) Model:**
```text
y_{i,t} | y_{i,t} > 0 ~ Negative Binomial(μ_{i,t}, θ)
log(μ_{i,t}) = X_{i,t}·β + γ_t + u_i
```

**2. Zero-Inflation Model:**
```text
P(y_{i,t} = 0) = π_{i,t} + (1 - π_{i,t}) · P(NB = 0 | μ_{i,t})
logit(π_{i,t}) = α_0  (intercept-only in our specification)
```

Where:
- `μ_{i,t}`: Expected count for firm i in year t
- `θ`: Dispersion parameter (larger θ = less overdispersion)
- `π_{i,t}`: Probability of structural zero (firm is "not at risk")
- `X_{i,t}`: Time-varying covariates (controls, initial conditions, Mundlak terms)
- `γ_t`: Year fixed effects
- `u_i`: Firm random intercept (captures unobserved firm heterogeneity)

#### Mundlak Terms: Controlling for Unobserved Firm Heterogeneity

**Problem**: Random Effects (RE) models assume that firm-specific unobserved heterogeneity (`u_i`) is uncorrelated with covariates. This is often violated in practice.

**Solution**: Mundlak (1978) approach — include firm-level means of time-varying covariates as additional regressors.

**How it works**:
1. For each time-varying covariate `X_{i,t}`, compute firm-level mean: `X̄_i = (1/T_i) Σ_t X_{i,t}`
2. Include `X̄_i` as an additional regressor in the model
3. This controls for correlation between `u_i` and time-varying covariates

**Example**:
```r
# Time-varying variable: early_stage_ratio
# Firm A: 2020=0.3, 2021=0.4, 2022=0.5 → mean = 0.4
# Firm B: 2020=0.6, 2021=0.7, 2022=0.8 → mean = 0.7

# Mundlak term created:
# early_stage_ratio_firm_mean
# All observations for Firm A: 0.4
# All observations for Firm B: 0.7
```

**Why use Mundlak terms instead of Fixed Effects?**
- **Fixed Effects (FE)**: Absorbs all firm-level constants, including `initial_*` variables (which are firm-level constants)
- **Mundlak + RE**: Allows inclusion of firm-level constants (`initial_*`) while controlling for unobserved heterogeneity
- **Trade-off**: Mundlak terms require stronger assumptions than FE, but enable estimation of initial condition effects

#### Our Implementation

**Model specification**:
```r
# Conditional model
perf_IPO_{i,t} ~ ZINB(μ_{i,t}, θ)
log(μ_{i,t}) = β_0 + β_1·initial_pwr_p75_mean_i + 
               β_2·years_since_init_{i,t} +        # No lag (time-adjusted)
               β_3·after7_{i,t} +                  # No lag (dummy)
               β_4·firmage_log_{i,t} +             # No lag (already time-adjusted)
               β_5·early_stage_ratio_{i,t-1} +    # Lagged by 1 period
               β_6·industry_blau_{i,t-1} +         # Lagged by 1 period
               β_7·inv_amt_log_{i,t-1} +           # Lagged by 1 period
               β_8·dgr_cent_{i,t-1} +              # Lagged by 1 period
               β_k·early_stage_ratio_firm_mean_i + 
               ... (other Mundlak terms) +
               γ_t + u_i

# Zero-inflation model
logit(π_{i,t}) = α_0
```

**Key features**:
- **Firm random intercept** (`u_i`): Captures unobserved firm heterogeneity
- **Year fixed effects** (`γ_t`): Controls for calendar-year macro shocks
- **Mundlak terms**: Firm-level means of time-varying covariates (e.g., `early_stage_ratio_firm_mean`)
- **Initial condition variables**: Firm-level constants (e.g., `initial_pwr_p75_mean`) — can be included because we use RE, not FE

**Variables included**:
- **Initial conditions**: `initial_pwr_p75_mean` (or `p0`/`p99` based on `INIT_SET`) — **no lag** (firm-level constants)
- **Time-varying controls (lagged)**: `early_stage_ratio_lag1`, `industry_blau_lag1`, `inv_amt_log_lag1`, `dgr_cent_lag1` — **lagged by 1 period** (`X_{i,t-1}` predicts `y_{i,t}`)
- **Time-adjusted/dummy variables (no lag)**: `years_since_init`, `after7`, `firmage_log` — **no lag** (already time-adjusted or dummy)
  - `firmage_log`: Already reflects time difference (firmage = year - founding_year), so lagging would be redundant
  - `years_since_init`: Already time-adjusted variable (years since initial network formation)
  - `after7`: Dummy variable (no temporal ordering issue)
- **Mundlak terms**: `early_stage_ratio_firm_mean`, `industry_blau_firm_mean`, `inv_amt_log_firm_mean`, `dgr_cent_firm_mean` — **no lag** (firm-level constants)

**Why lag time-varying covariates?**
- **Simultaneity bias**: Using contemporaneous (`X_{i,t}`) and outcome (`y_{i,t}`) variables can create reverse causality issues
- **Causal interpretation**: `X_{i,t-1}` → `y_{i,t}` provides clearer causal interpretation (past characteristics predict future outcomes)
- **Standard practice**: Panel data analysis typically uses lagged predictors to establish temporal precedence

**Why some variables don't need lagging?**
- **`firmage_log`**: Already reflects time difference (firmage = year - founding_year). Lagging would be redundant since the variable itself already captures the temporal dimension.
- **`years_since_init`**: Already time-adjusted variable (years since initial network formation). Similar to `firmage_log`, it already reflects temporal distance.
- **`after7`**: Dummy variable indicating whether 7+ years have passed since initial network formation. No temporal ordering issue.

#### Interpretation

**Coefficients**:
- **Initial condition effects** (`β_1`): Persistent effect of initial partner status on future performance
- **Time-varying effects (lagged)** (`β_3`, ...): Effects of past firm characteristics (t-1) on current performance (t)
  - Example: `early_stage_ratio_lag1` coefficient shows how last year's early-stage investment ratio affects this year's exits
- **Time-adjusted effects (no lag)** (`β_2`, ...): Effects of time-adjusted variables on current performance
  - Example: `firmage_log` coefficient shows how firm age (already reflecting time difference) affects performance
  - Example: `years_since_init` coefficient shows how time since initial network formation affects performance
- **Mundlak terms** (`β_k`, ...): Control for correlation between unobserved firm heterogeneity and time-varying covariates

**Zero-inflation probability** (`π_{i,t}`):
- Intercept-only specification assumes constant probability of structural zeros across firms/years
- Can be extended to include covariates if theoretically justified

#### Robustness Checks

1. **Poisson Fixed Effects**: Firm FE + Year FE (excludes initial conditions due to collinearity)
2. **Negative Binomial (no ZI)**: Tests robustness to zero-inflation assumption
3. **Alternative Mundlak specifications**: Include/exclude specific Mundlak terms
4. **Different aggregation types**: Test `_mean` vs `_max` vs `_min` for initial conditions

---

### Missingness Handling using initial_xxx_missing <a id="missingness"></a>
- Flags (see notebook history for full definitions):
  - Summary: `initial_status_missing`
  - Low criticality: `initial_missing_outside_cohort` (design-consistent control)
  - Medium criticality: `initial_missing_no_partners` (solo investments), `rep_missing_fund_data`
  - High criticality: `initial_missing_no_centrality`, `initial_missing_other` (consider exclusion)
- Recommended sampling:
  - Include Low + Medium; exclude High by default.
  - Always report missingness shares by τ and by cohort to rule out informative missingness.
- In-network `in_network` dummy:
  - Include as a control in outcome models to mitigate selection into the networked sample.

---

### Measurement Windows and Alignment <a id="windows"></a>
- Network centrality for year t is computed on [t−TIME_WINDOW, t−1] (lagged network) to mitigate simultaneity.
- Initial partner status:
  - True initial year from full history.
  - Imprinting window t1..t3; partner centrality measured on lagged networks; aggregated partner-weighted (mean/max/min).
- Firm basics:
  - Performance `perf_*`: lookback 0 (current year only); fill zeros post-merge if needed.
  - Early-stage ratio: based on `comstage1/2/3` with configured early-stage definitions.
- VC Reputation:
  - Six variables over [t−4, t] with year-wise z-score and min-max [0.01, 100].
  - `rep_missing_fund_data` marks years with insufficient fund info.

---

### Censoring, Truncation, and Sample Construction <a id="censoring"></a>
- Left-censoring:
  - Firms with initial years before earliest data risk mismeasured τ; our full-history approach reduces this but does not eliminate pre-1970 censoring.
  - Consider restricting to cohorts with reliable pre-period coverage (e.g., require availability of τ ∈ {−L..0} for some L).
- Right-censoring:
  - For large τ, surviving firms are over-represented → survivorship bias. Use balanced τ windows or survival controls.
- Balanced τ-window sensitivity:
  - Report results where all VCs have observations for τ ∈ [0..n] to ensure comparability.

---

### Inference and Standard Errors <a id="inference"></a>
- **ZINB models**: Use robust standard errors clustered by firm (to account for within-firm correlation)
- **Two-way clustering**: Consider clustering by (firm, calendar year) if year-level shocks are correlated across firms
- **Wild cluster bootstrap**: If clusters are few/imbalanced (e.g., < 50 firms), consider wild cluster bootstrap for inference
- **Robustness**: Compare results with Poisson Fixed Effects (firm FE + year FE) and Negative Binomial (no ZI) models
- For time-to-event questions, complement with survival models using τ as analysis time

---

### Outliers, Scaling, and Transformations <a id="scaling"></a>
- Scale centrality by year (z-score) if mixing across years; already done for reputation.
- Winsorize extreme values for skewed measures (betweenness, amounts).
- Log transforms for amounts if using linear models (handle zeros separately).

---

### Multiple Testing and Dimensionality <a id="multi-testing"></a>
- Many centrality measures and partner aggregations (mean/max/min) → control FDR or summarize via factors/indices.
- Pre-specify primary outcomes (e.g., exits, IPOs) and primary measures to minimize data mining concerns.

---

### Collinearity and Dropped Variables <a id="collinearity"></a>
- **Firm FE vs initial_***:
  - With γ_i (firm FE), any firm-level constant (initial_*) drops by collinearity.
  - **ZINB with Mundlak + RE**: Allows inclusion of initial_* variables because we use random intercepts, not fixed effects
  - **Poisson FE**: Excludes initial_* variables (use only for robustness checks)
  - Decide ex-ante: either study dynamic τ-effects with γ_i or study cross-sectional initial_* with RE + Mundlak
- **Mundlak terms**: Highly correlated with their time-varying counterparts by construction (firm mean vs. time-varying value)
  - This is intentional and expected — Mundlak terms control for firm-level heterogeneity
  - VIF may be high for Mundlak terms, but this is not a concern (they serve a specific control purpose)
- Check VIF and pairwise correlations among centralities and reputation components.
- **Initial condition aggregation**: Choose aggregation type (`_mean`, `_max`, `_min`) based on theoretical considerations; avoid including all three simultaneously due to high correlation

---

### Selection Bias and In-Network Issues <a id="selection-bias"></a>
- `in_network` = 0 rows differ systematically; include `in_network` dummy and/or analyze networked subsample with caution.
- Post-treatment controls:
  - Avoid controlling for time-varying centrality measured contemporaneously with outcome (bad control).
  - Prefer lagged network measures or baseline (τ=0) levels where theoretically justified.

---

### Data Quality and Merge Integrity <a id="data-quality"></a>
- Preprocessing standards implemented:
  - Undisclosed filtering, firm/company dedup, round exact-duplicate removal, firm registry filtering.
  - Industry column: `comindmnr`; early-stage: `comstage1/2/3`.
  - Performance metrics aligned to R logic; `firm_hq` consistent; missing perf filled to 0 as needed.
- Known caveats:
  - IPO counting uses past-invested firms with IPO in [t−4, t]; ensure company matching quality.
  - Fund date parsing from `dd.mm.yyyy`; failures logged; `rep_missing_fund_data` flagged.

---

### Robustness Checks (Menu) <a id="robustness"></a>
1. **Model specification**:
   - ZINB (main) vs Poisson FE vs Negative Binomial (no ZI)
   - With/without Mundlak terms
   - Zero-inflation: intercept-only vs. covariate-dependent
2. **Initial condition aggregation**: `_mean` vs `_max` vs `_min` vs combinations
3. Event-time windows: vary n (e.g., 1, 2, 3, 5 years).
4. Network window TW: vary [t−TW, t−1]; weighted vs unweighted edges.
5. Alternative partner aggregation: median; top-k partners; winsorized partner averages.
6. Criticality filters: include/exclude Medium; always exclude High; report shares and impacts.
7. Cohort controls: cohort FE and cohort×τ FE; sub-cohort analyses (1990s vs 2000s).
8. Outcome families: Poisson vs NB; linear probability vs logit for binary outcomes; survival models.
9. Outlier handling: winsorization thresholds and log transforms.
10. Alternative merge bases: confirm results when base is `firm_vars_df_filtered` vs network base (sanity check).
11. Reputation: include/exclude reputation; swap in individual components.
12. Standard errors: two-way clustering vs wild bootstrap sensitivity.
13. **Mundlak specification**: Include/exclude specific Mundlak terms; test sensitivity to Mundlak variable selection

---

### Reporting and Reproducibility <a id="reporting"></a>
- Always report:
  - Cohort definition, τ window, and coverage by τ.
  - Shares of missingness by flag and τ; the applied filters.
  - FE structure; whether firm FE included; implications for initial_* identification.
  - SE clustering scheme and any bootstrap choices.
- Reproducibility:
  - Log all settings: TIME_WINDOW, τ horizon n, filters, and standardization choices.
  - Save analysis-ready datasets with timestamped filenames (already implemented).

---

### Practical Checklist <a id="checklist"></a>
- [ ] **Model selection**: Choose ZINB (main) with Mundlak + RE, or Poisson FE (robustness)
- [ ] **Initial conditions**: Select aggregation type (`_mean`, `_max`, `_min`) based on theory; default to `_mean`
- [ ] **Mundlak terms**: Specify which time-varying covariates get Mundlak terms (default: `early_stage_ratio`, `industry_blau`, `inv_amt_log`, `dgr_cent`)
- [ ] Define τ horizon n (e.g., 2 or 3 years) and ensure adequate coverage.
- [ ] Use VC–obs.year panel; add event-time dummies for τ ∈ [0..n].
- [ ] **ZINB specification**: Include firm random intercept (`u_i`), year FE (`γ_t`), Mundlak terms, and initial conditions
- [ ] **FE specification**: If using Poisson FE, omit initial conditions (they drop by collinearity)
- [ ] Include `in_network` dummy; avoid post-treatment controls.
- [ ] Apply criticality filters: exclude High; decide on Medium inclusion; document.
- [ ] Confirm window settings: centrality [t−TW, t−1]; imprinting t1..t3; perf lookback 0; reputation [t−4, t].
- [ ] Address censoring: balanced τ window sensitivity; survivorship checks.
- [ ] Handle outliers/scaling: winsorize, z-score or log transforms as appropriate.
- [ ] Cluster SE by firm (or firm + year); consider wild bootstrap if clusters are few.
- [ ] Run robustness menu (ZINB vs Poisson FE vs NB no-ZI); pre-register primary outcomes/measures where feasible.

---

If desired, I can generate a ready-to-run event-study code cell template (with τ dummies, two-way clustering, and missingness filters) tailored to your current `analysis_df` columns.


