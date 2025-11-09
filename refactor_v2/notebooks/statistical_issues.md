## Statistical Issues for Imprinting & VC Network Analysis

Last updated: 2025-11-07

### 📑 Table of Contents
- [Purpose and Scope](#purpose)
- [Study Index Choice: obs.year vs init.year](#index-choice)
- [Recommended Event-Study Specification](#event-study)
- [Fixed Effects: Identification and Pitfalls](#fixed-effects)
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
- Two-way clustered standard errors (VC, calendar year) for panel dependence.
- If clusters are few/imbalanced, consider wild cluster bootstrap.
- For count outcomes, Poisson or Negative Binomial with cluster-robust SE.
- For time-to-event questions, complement with survival models using τ as analysis time.

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
- Firm FE vs initial_*:
  - With γ_i, any firm-level constant (initial_*) drops.
  - Decide ex-ante: either study dynamic τ-effects with γ_i or study cross-sectional initial_* with alternative FE.
- Check VIF and pairwise correlations among centralities and reputation components.

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
1. Event-time windows: vary n (e.g., 1, 2, 3, 5 years).
2. Network window TW: vary [t−TW, t−1]; weighted vs unweighted edges.
3. Alternative partner aggregation: median; top-k partners; winsorized partner averages.
4. Criticality filters: include/exclude Medium; always exclude High; report shares and impacts.
5. Cohort controls: cohort FE and cohort×τ FE; sub-cohort analyses (1990s vs 2000s).
6. Outcome families: Poisson vs NB; linear probability vs logit for binary outcomes; survival models.
7. Outlier handling: winsorization thresholds and log transforms.
8. Alternative merge bases: confirm results when base is `firm_vars_df_filtered` vs network base (sanity check).
9. Reputation: include/exclude reputation; swap in individual components.
10. Standard errors: two-way clustering vs wild bootstrap sensitivity.

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
- [ ] Define τ horizon n (e.g., 2 or 3 years) and ensure adequate coverage.
- [ ] Use VC–obs.year panel; add event-time dummies for τ ∈ [0..n].
- [ ] Include γ_i (VC FE) and γ_t (year FE); omit firm-level constants that would be collinear (initial_*).
- [ ] Include `in_network` dummy; avoid post-treatment controls.
- [ ] Apply criticality filters: exclude High; decide on Medium inclusion; document.
- [ ] Confirm window settings: centrality [t−TW, t−1]; imprinting t1..t3; perf lookback 0; reputation [t−4, t].
- [ ] Address censoring: balanced τ window sensitivity; survivorship checks.
- [ ] Handle outliers/scaling: winsorize, z-score or log transforms as appropriate.
- [ ] Cluster SE by (VC, year); consider wild bootstrap if needed.
- [ ] Run robustness menu; pre-register primary outcomes/measures where feasible.

---

If desired, I can generate a ready-to-run event-study code cell template (with τ dummies, two-way clustering, and missingness filters) tailored to your current `analysis_df` columns.


