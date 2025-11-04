# Recommended Additional Variables for VC Analysis

**Date**: 2025-10-18  
**Purpose**: Suggest additional firm-level variables based on VC research literature

---

## Currently Implemented Variables

✅ **Firm Age** (`firmage`): year - founding year  
✅ **Investment Diversity** (`industry_blau`): Blau index by industry  
✅ **Performance** (`perf_all`, `perf_IPO`, `perf_MnA`): Exit counts  
✅ **Early Stage Ratio** (`early_stage_ratio`): % of early-stage investments  
✅ **Firm HQ** (`firm_hq_CAMA`): Dummy for CA/MA location  
✅ **Investment Amount** (`inv_amt`): Total investment amount (yearly)  
✅ **Investment Number** (`inv_num`): Total investment count (yearly)

---

## Highly Recommended Additional Variables

### 1. **Syndication Behavior**

#### 1.1 Syndication Rate
```python
# Ratio of syndicated investments to total investments
syndication_rate = # rounds with >1 investor / total rounds
```
**Rationale**: 
- Measures collaboration tendency
- High syndication → Risk sharing, information exchange
- Low syndication → Independent strategy, proprietary deals

**Literature**: Lerner (1994), Sorenson & Stuart (2001)

#### 1.2 Average Syndicate Size
```python
# Mean number of co-investors per round
avg_syndicate_size = mean(# investors per round)
```
**Rationale**:
- Larger syndicates → More diverse expertise
- Smaller syndicates → More control, less coordination costs

---

### 2. **Experience & Reputation**

#### 2.1 Cumulative Experience
```python
# Total number of investments up to year t
cumulative_investments = sum(inv_num[year <= t])
```
**Rationale**:
- Experience → Better deal selection, valuation
- Learning curve effects
- Non-linear relationship (diminishing returns?)

**Literature**: Gompers et al. (2020)

#### 2.2 Success Rate (Historical)
```python
# Cumulative IPO rate up to year t
historical_ipo_rate = sum(perf_IPO[year < t]) / sum(inv_num[year < t])
```
**Rationale**:
- Reputation signal
- Attracts better deals
- Path dependence

---

### 3. **Portfolio Characteristics**

#### 3.1 Geographic Diversity
```python
# Blau index by company state
geo_blau = 1 - Σ(p_state^2)
```
**Rationale**:
- Local vs national strategy
- Information advantages vs diversification
- Regional expertise

**Literature**: Sorenson & Stuart (2001)

#### 3.2 Stage Diversity
```python
# Blau index by investment stage
stage_blau = 1 - Σ(p_stage^2)
```
**Rationale**:
- Specialist vs generalist strategy
- Stage-specific expertise
- Risk-return profile

#### 3.3 Portfolio Concentration (HHI)
```python
# Herfindahl index by company
portfolio_hhi = Σ(investment_share^2)
```
**Rationale**:
- Diversification vs focus
- Risk management
- Resource allocation

---

### 4. **Timing & Market Conditions**

#### 4.1 Market Timing (Hot/Cold Markets)
```python
# Investment activity relative to market average
market_timing = inv_num[firm, year] / mean(inv_num[all_firms, year])
```
**Rationale**:
- Pro-cyclical vs counter-cyclical investing
- Market timing ability
- Valuation discipline

**Literature**: Gompers & Lerner (2000)

#### 4.2 Entry Timing (Round Participation)
```python
# Average round number participated
avg_entry_round = mean(round_number)
```
**Rationale**:
- Early vs late-stage focus
- Risk appetite
- Value-add strategy

---

### 5. **Network Position (Time-Varying)**

#### 5.1 Network Growth Rate
```python
# Change in degree centrality
dgr_growth = (dgr_cent[t] - dgr_cent[t-1]) / dgr_cent[t-1]
```
**Rationale**:
- Network expansion strategy
- Relationship building
- Market penetration

#### 5.2 Brokerage Potential
```python
# Betweenness relative to degree
brokerage_ratio = btw_cent / dgr_cent
```
**Rationale**:
- Structural position beyond connectivity
- Information brokerage
- Strategic positioning

**Literature**: Burt (1992), Podolny (2001)

#### 5.3 Clustering Coefficient
```python
# Proportion of closed triads
clustering = # closed triads / # possible triads
```
**Rationale**:
- Embeddedness in dense clusters
- Trust and reputation
- Information redundancy

---

### 6. **Investment Strategy Indicators**

#### 6.1 Follow-on Investment Rate
```python
# % of portfolio companies receiving multiple rounds
followon_rate = # companies with >1 round / total companies
```
**Rationale**:
- Commitment to portfolio
- Staging strategy
- Success signal

**Literature**: Gompers (1995)

#### 6.2 Lead Investor Rate
```python
# % of investments as lead investor
lead_rate = # lead investments / total investments
```
**Rationale**:
- Leadership role
- Due diligence capability
- Influence in syndicate

#### 6.3 Investment Pace
```python
# Time between consecutive investments
avg_investment_interval = mean(days between investments)
```
**Rationale**:
- Deal flow
- Resource constraints
- Investment discipline

---

### 7. **Firm Characteristics (Time-Invariant)**

#### 7.1 Firm Type Stability
```python
# Dummy: Has firm changed type? (CVC → IVC, etc.)
type_change = 1 if firmtype changed, 0 otherwise
```
**Rationale**:
- Organizational change
- Strategy shift
- Identity consistency

#### 7.2 Founding Team Size
```python
# Number of founding partners (if available)
founding_team_size = # founders
```
**Rationale**:
- Human capital
- Decision-making structure
- Expertise diversity

---

## Priority Ranking

### **Tier 1 (Highly Recommended - Immediate Implementation)**
1. ✅ Syndication Rate
2. ✅ Cumulative Experience
3. ✅ Geographic Diversity
4. ✅ Historical Success Rate

### **Tier 2 (Recommended - Next Phase)**
5. Average Syndicate Size
6. Stage Diversity
7. Network Growth Rate
8. Follow-on Investment Rate

### **Tier 3 (Optional - Future Research)**
9. Market Timing
10. Brokerage Ratio
11. Portfolio Concentration
12. Lead Investor Rate

---

## Implementation Considerations

### Data Requirements

**Already Available**:
- Round data (firmname, comname, year, amount)
- Company data (state, industry, exits)
- Firm data (founding, type, location)
- Network data (centrality measures)

**May Need**:
- Round number/sequence (for entry timing)
- Lead investor indicator (for lead rate)
- Founding team data (external source)

### Computational Complexity

**Low** (< 1 min):
- Syndication rate
- Geographic/stage diversity
- Cumulative experience

**Medium** (1-5 min):
- Historical success rate
- Network growth rate
- Follow-on rate

**High** (> 5 min):
- Clustering coefficient (requires network construction)
- Brokerage ratio (requires betweenness)

---

## Usage Example

```python
from vc_analysis.variables import firm_variables

# Calculate all basic variables
basic_vars = firm_variables.calculate_all_firm_variables(
    round_df, company_df, firm_df
)

# Add Tier 1 recommended variables
from vc_analysis.variables import advanced_firm_variables

advanced_vars = advanced_firm_variables.calculate_tier1_variables(
    round_df, company_df, firm_df, networks_df
)

# Merge
final_df = basic_vars.merge(advanced_vars, on=['firmname', 'year'])
```

---

## References

**Key Papers**:
1. Lerner, J. (1994). The syndication of venture capital investments. *Financial Management*, 16-27.
2. Sorenson, O., & Stuart, T. E. (2001). Syndication networks and the spatial distribution of venture capital investments. *American Journal of Sociology*, 106(6), 1546-1588.
3. Gompers, P. A. (1995). Optimal investment, monitoring, and the staging of venture capital. *The Journal of Finance*, 50(5), 1461-1489.
4. Gompers, P., Gornall, W., Kaplan, S. N., & Strebulaev, I. A. (2020). How do venture capitalists make decisions? *Journal of Financial Economics*, 135(1), 169-190.
5. Burt, R. S. (1992). *Structural Holes: The Social Structure of Competition*. Harvard University Press.
6. Podolny, J. M. (2001). Networks as the pipes and prisms of the market. *American Journal of Sociology*, 107(1), 33-60.

---

**Document Version**: 1.0  
**Total Variables Recommended**: 15 (7 basic + 15 additional)  
**Priority Tier 1**: 4 variables  
**Estimated Implementation Time**: 2-3 hours for Tier 1





