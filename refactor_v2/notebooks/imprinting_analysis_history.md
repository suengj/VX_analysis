# Imprinting Analysis History

## 📑 목차 (TOC)
- [현재 상태 (코드 구조, 진행 현황, 다음 단계)](#status)
- [구현 방식 (변수 계산 윈도우, 전처리, 회귀 분석 가이드라인)](#implementation)
- [논의 및 합의 사항 (2025-10-28)](#discussion-2025-10-28)
- [히스토리 (요약 타임라인)](#history)
- [주요 파일 구조](#files)
- [핵심 성과](#highlights)

---

<a id="status"></a>
## ✅ 현재 상태 (코드 구조, 진행 현황, 다음 단계)

### 코드 구조(핵심 모듈)
- `vc_analysis/data/loader.py`
  - Excel serial → datetime 변환(`rnddate`)
  - `Undisclosed Firm/Company` 선제 제거
  - Firm dedup(최초 설립연도 우선 → 동일 시 `firmzip` 보유 우선), Company dedup(비결측 스코어 최대)
  - Round exact duplicates 제거
  - `filter_round_by_firm_registry(mode='strict'|'nation_select', nation_codes=[...])`
- `vc_analysis/network/construction.py`
  - 연도 t의 네트워크는 [t−TIME_WINDOW, t−1] 래그 윈도우로 생성
- `vc_analysis/network/centrality.py`
  - 중심성: `dgr_cent`, `btw_cent`, `pwr_max`, `pwr_p0`, `pwr_p75`, `pwr_p99`, `constraint`, `ego_dens`
  - 지표별 가중/무가중, 정규화 옵션
  - `constraint` NaN 채움(옵션), 1.0 상한(capping)
  - `pwr_max`(최대 고유값 역수)
- `vc_analysis/network/imprinting.py`
  - `initial_year`(Full History) 식별
  - t1~t3 임프린팅 기간 파트너 추출
  - 각 t의 파트너 중심성(5년 래그 윈도우) 계산 병합
  - 파트너별 시간 평균 → 파트너 집계(Mean/Max/Min)
- `vc_analysis/variables/firm_variables.py`
  - `firmage`, `industry_blau`(comindmnr), `perf_*`(당해 연도), `early_stage_ratio`, `firm_hq`(CA/MA), `firm_hq_CA`, `firm_hq_MA`, `firm_hq_NY`, `inv_amt`, `inv_num`
  - `fill_missing_performance_with_zero(df, ...)` 제공
  - **VC Reputation**: 6개 구성 변수 + Z-score 표준화 + Min-Max 스케일링 [0.01, 100]
  - **Market Heat**: Industry-level 변수, 과거 3년 대비 당해 연도 fund raising 상대적 활성도 (ln ratio)
  - **New Venture Funding Demand**: Industry-level 변수, 당해 연도 첫 라운드 US 벤처 개수 (ln, current year, panel 분석 시 lagging 필요)
  - **Years Since Initial Network**: `years_since_init = year - initial_year` (event-time 기준 분석용)
    - `rep_portfolio_count`: [t-4, t] 기간 동안 투자한 unique portfolio companies 수
    - `rep_total_invested`: [t-4, t] 기간 동안 총 투자 금액
    - `rep_avg_fum`: t 시점에서 관리 중인 fund들의 평균 size (fundiniclosing 고려)
    - `rep_funds_raised`: [t-4, t] 기간 동안 raising한 fund 개수
    - `rep_ipos`: 과거 투자한 회사들 중 [t-4, t] 기간 동안 IPO한 회사 수
    - `fundingAge`: t - 첫 번째 fund raising year
    - `VC_reputation`: 6개 변수 Z-score 합산 후 연도별 Min-Max 스케일링
    - `rep_missing_fund_data`: fund 데이터 누락 플래그 (최종 샘플링 시 제외용)
- `vc_analysis/config/parameters.py`
  - 중심성 정규화 및 가중치 토글
  - `constraint` NA 채움/상한 토글
  - 중심성 결측 처리용 토글: `create_in_network_dummy`, `fill_missing_centrality_as_zero`, `zero_fill_columns`

### 진행 현황
- 데이터 로딩/정합성 강화, 네트워크/중심성/임프린팅/펌 변수 생성 및 노트북 통합 완료
- 최종 머지(`final_df`): Firm-Year 레벨, (firmname, year) 키
- `in_network` 더미와 선택적 중심성 0-치환 후처리 셀 추가

### 다음 단계
- 기술통계/상관/회귀 본 분석 및 로버스트 체크(정규화/가중/윈도우/코호트/사양)
- 추가 변수(예: Syndication Rate, 누적 경험, 지리/산업 다양성, 과거 성공률) 확장
- 성능 최적화(병렬/샘플링), 매칭 표준화(법인명 정규화), 로그 기록 강화

---

<a id="implementation"></a>
## 🛠️ 구현 방식 (변수 계산 윈도우, 전처리, 회귀 분석 가이드라인)

### 1) 네트워크 중심성 (Firm-Year)
- 계산 대상: `dgr_cent`, `btw_cent`, `pwr_max`, `pwr_p0`, `pwr_p75`, `pwr_p99`, `constraint`, `ego_dens`
- 네트워크 윈도우: 연도 t → [t−TIME_WINDOW, t−1] 데이터로 네트워크 구성(래그드 네트워크)
- 가중치/정규화: 지표별 토글 (기본은 unweighted, 필요한 경우 weighted)
- `constraint`: NaN 채움 옵션(기본 0), 1.0 상한(capping) 옵션
- 후처리: `in_network` 더미(어떤 중심성이라도 관측되면 1), 특정 지표 0-치환(선택)
- 해석 가이드: 중심성은 과거창 기반이므로 t의 성과를 예측할 때 동시성 우려가 상대적으로 적음(암묵적 래그 포함). 추가 래깅은 식별전략에 따라 결정.

### 2) Initial Partner Status (Firm-Level Constant)
- 대상: `initial_*_{mean,max,min}`(8개 중심성 × 3개 집계), `initial_year`, `n_initial_partners`, `n_partner_years`
- `initial_year`: 전체 역사(Full History)에서의 진짜 첫 연결 연도
- 임프린팅 기간: t1~t3(3개년), 각 t의 파트너 중심성은 [t−TIME_WINDOW, t−1] 래그 네트워크에서 산출
- 집계: 파트너별 시간 평균 → 파트너 간 mean/max/min("partner-weighted" 의미 유지)
- 회귀 가이드(식별 주의):
  - Firm FE 사용 시: initial_*는 firm-level 상수 → 완전 공선성으로 식별 불가(모형에서 떨어짐)
  - 대안: firm FE 미사용 + time FE, RE, cohort-by-year FE, 혹은 initial_* × year 상호작용 등 설계
  - 코호트 외 초기연도(예: 1985)인 경우: initial_*는 결측이 정상이며, 이는 설계 상 Control 그룹 해석과 정합

#### Initial Status Missing 플래그 (6개 컬럼)

**목적**: `initial_*` 변수가 NaN인 이유를 분류하여 분석에서 적절히 처리

| 컬럼명 | Criticality | 정의 | 분석 처리 |
|--------|-------------|------|-----------|
| `initial_status_missing` | Summary | `initial_*` 컬럼들이 모두 NaN인 경우 (종합 플래그) | 위 5개 중 하나라도 1이면 1 |
| `initial_missing_outside_cohort` | **Low** | 코호트 밖 초기연도<br>- Full history에서 `initial_year_full`은 있지만 START_YEAR~END_YEAR 범위 밖<br>- `initial_year`는 NaN | ✅ **분석 포함 가능**<br>- 설계상 정상 (Control 그룹)<br>- `initial_*`는 NaN 유지 |
| `initial_missing_no_partners` | **Medium** | 설립 시점에 파트너가 없음<br>- `initial_year`는 있지만 `n_initial_partners`나 `n_partner_years`가 0이거나 NaN<br>- 또는 `initial_ties_df`에 해당 firm이 없음 | ⚠️ **조건부 포함**<br>- "Solo investment" 그룹으로 해석 가능<br>- 분석 포함 가능하나 해석 주의 |
| `initial_missing_no_centrality` | **High** | 파트너는 있지만 중심성 값이 모두 NaN<br>- `initial_year`는 있고 파트너도 있지만 `initial_*` 컬럼들이 모두 NaN | ❌ **제외 고려**<br>- 데이터 문제 가능성 (매칭/계산 오류)<br>- 제외 또는 별도 조사 필요 |
| `initial_missing_other` | **High** | 위 세 가지에 해당하지 않는 기타 케이스 | ❌ **제외 고려**<br>- 원인 불명, 조사 필요<br>- 제외 또는 별도 조사 필요 |
| `rep_missing_fund_data` | **Medium** | VC Reputation 변수 중 fund 기반 변수 누락<br>- `rep_avg_fum`, `rep_funds_raised`, `fundingAge` 중 하나라도 NaN | ⚠️ **조건부 포함**<br>- 최종 샘플링 시 제외 가능<br>- Fund 데이터 없이도 분석 가능 (round 기반 변수는 존재) |

**Criticality 기반 샘플링 가이드**:
- **Low + Medium 포함**: `initial_missing_outside_cohort`, `initial_missing_no_partners`, `rep_missing_fund_data` 포함
- **High 제외**: `initial_missing_no_centrality`, `initial_missing_other` 제외
- **권장 필터**: `analysis_df[(analysis_df['initial_missing_no_centrality'] == 0) & (analysis_df['initial_missing_other'] == 0)]`

#### Initial Period Variables (Firm-Level Constant, t1~t3 기간 투자 행위/특성)
- `initial_early_stage_ratio`: t1~t3 기간 동안의 평균 early stage 투자 비율
- `initial_industry_blau`: t1~t3 기간 동안의 평균 산업 다양성 (Blau index)
- `initial_inv_num`: t1~t3 기간 동안의 총 투자 횟수 (합계)
- `initial_inv_amt`: t1~t3 기간 동안의 총 투자 금액 (합계)
- `initial_firmage`: t1 시점의 조직 나이 (initial_year에서의 firmage)
- `initial_market_heat`: t1~t3 기간 동안의 평균 market heat
- `initial_new_venture_demand`: t1~t3 기간 동안의 평균 new venture demand
- `initial_geo_dist_copartner_*` (6개 변수): t1~t3 기간 동안의 평균 공동 투자 파트너 거리
  - `initial_geo_dist_copartner_mean`: 평균 거리
  - `initial_geo_dist_copartner_min`: 최소 거리
  - `initial_geo_dist_copartner_max`: 최대 거리
  - `initial_geo_dist_copartner_median`: 중앙값 거리
  - `initial_geo_dist_copartner_weighted_mean`: 가중 평균 거리
  - `initial_geo_dist_copartner_std`: 거리 표준편차

**계산 방식**:
- Firm-year 변수: t1~t3 기간 동안 평균(비율/다양성) 또는 합계(투자 횟수/금액)
- Market-level 변수: t1~t3 기간 동안 평균
- Firm age: t1 시점 값 (초기 시점 조직 나이)
- Geographic distances: t1~t3 기간 동안의 firm-year level co-partner 거리 변수들의 평균

**Imprinting 효과 해석**:
- 초기 투자 행위/특성이 이후 VC firm의 투자 패턴에 지속적 영향을 미칠 수 있음
- 예: 초기 early stage 투자 비율이 높으면 이후에도 early stage 투자 선호도가 높을 수 있음
- 초기 기간 동안의 공동 투자 파트너와의 지리적 거리가 이후 네트워크 형성에 지속적 영향을 미칠 수 있음
- 예: 초기에 가까운 거리의 파트너와 투자한 VC는 이후에도 지역적 네트워크를 유지할 수 있음

### 3) Firm Basics (Firm-Year)
- `firmage = year − founding_year`(음수 0 캡)
- `industry_blau`: comindmnr 기준 Blau index(연도별)
- `perf_*`: 당해 연도만, 매칭 안 된 firm-year는 머지 후 NaN → 분석 전 0-치환 권장(`fill_missing_performance_with_zero`)
- `early_stage_ratio`: 설정된 Stage set 평균(연도별)
- `inv_amt`, `inv_num`: 연도별 합/건수
- `firm_hq`, `firm_hq_CA`, `firm_hq_MA`, `firm_hq_NY`: HQ 더미 변수 (firm-level → 모든 연도에 병합)
  - `firm_hq`: CA 또는 MA = 1 (기존 변수, 하위 호환성 유지)
  - `firm_hq_CA`: California = 1
  - `firm_hq_MA`: Massachusetts = 1
  - `firm_hq_NY`: New York = 1

### 3-1) Geographic Distance (Firm-Year Level)
- **VC-Company 거리**: VC firm과 투자한 회사 간 물리적 거리 (ZIP 코드 기반 Haversine 거리)
  - `geo_dist_company_mean`: 평균 거리
  - `geo_dist_company_min`: 최소 거리
  - `geo_dist_company_max`: 최대 거리
  - `geo_dist_company_median`: 중앙값 거리 (추천: 이상치에 덜 민감)
  - `geo_dist_company_weighted_mean`: 투자 금액 가중 평균 거리
  - `geo_dist_company_std`: 거리 표준편차 (추천: 거리 분산 측정)

- **VC-Co-Partner 거리**: VC firm과 공동 투자 파트너 간 물리적 거리
  - `geo_dist_copartner_mean`: 평균 거리
  - `geo_dist_copartner_min`: 최소 거리
  - `geo_dist_copartner_max`: 최대 거리
  - `geo_dist_copartner_median`: 중앙값 거리 (추천: 이상치에 덜 민감)
  - `geo_dist_copartner_weighted_mean`: 투자 금액 가중 평균 거리
  - `geo_dist_copartner_std`: 거리 표준편차 (추천: 거리 분산 측정)

**계산 방식**:
- ZIP 코드 정규화: 5자리 문자열로 변환 (leading zeros 처리)
- ZIP → 위경도 변환: `uszipcode` 라이브러리 사용 (없으면 빈 데이터베이스 반환)
- Haversine 공식: 지구 표면의 대원 거리 계산 (단위: km)
- 집계: Firm-year 기준으로 평균/최소/최대/중앙값/표준편차 계산
- 가중 평균: 투자 금액(`RoundAmountDisclosedThou`)으로 가중

**추천 변수**:
- **중앙값 (median)**: 이상치에 덜 민감하여 평균보다 robust
- **가중 평균 (weighted_mean)**: 큰 투자에 더 많은 가중치 부여
- **표준편차 (std)**: 거리 분산 측정 (지리적 집중도/분산도)

### 3-2) Market Heat (Industry-Year Level)
- **정의**: VC fund raising 활동의 상대적 활성도 측정 (industry-level)
- **공식**: `Market heat_t = ln((VC funds raised_t × 3) / Σ_{k=t-3}^{t-1} VC funds raised_k)`
  - 분자: 당해 연도(t) unique VC fund 개수 × 3
  - 분모: 과거 3년(t-3, t-2, t-1) VC fund 개수 합계
- **해석**:
  - `market_heat > 0`: Hot market (활발한 시장)
  - `market_heat < 0`: Cold market (침체된 시장)
- **계산 방식**:
  - `fund_df`에서 연도별(`fundyear`) unique `fundname` 개수 계산
  - 과거 3년 합계는 `shift(1).rolling(window=3)`로 계산 (t-3 ~ t-1)
  - 분모=0 또는 ratio≤0인 경우 `NaN` 처리
- **통합**: Industry-level 변수이므로 같은 연도면 모든 firm-year에 동일한 값으로 merge
- **함수**: `calculate_market_heat(fund_df, year_col='year', fundyear_col='fundyear', fundname_col='fundname')`

### 3-3) New Venture Funding Demand (Industry-Year Level, Current Year)
- **정의**: VC 펀딩 수요 측정 (industry-level, current year)
- **공식**: `new_venture_demand_t = ln(count of first-round US ventures in year t)`
  - 기준: 미국에서 첫 라운드 VC 펀딩을 받은 새로운 벤처의 총 개수
  - 시점: 당해 연도(current calendar year, t) - **Raw 데이터셋이므로 lagged 아님**
  - 자연 로그 변환
- **계산 방식**:
  - `round_df`에서 `RoundNumber == min(RoundNumber)` per company로 첫 라운드 식별
  - `company_df`와 merge하여 `comnation == 'United States'` 필터링
  - 연도별 unique `comname` 개수 계산 (당해 연도 기준)
  - 자연 로그 변환 (`ln(count)`)
- **통합**: Industry-level 변수이므로 같은 연도면 모든 firm-year에 동일한 값으로 merge
- **Panel 분석 시 주의**: Raw 데이터셋이므로 회귀 분석 시 lagging 필요 (예: year t-1 사용)
- **함수**: `calculate_new_venture_funding_demand(round_df, company_df, year_col='year', roundnumber_col='RoundNumber', ...)`

### 3-4) Years Since Initial Network (Firm-Year Level)
- **정의**: Initial network 형성 이후 경과 연수
- **공식**: `years_since_init = year - initial_year`
- **계산 방식**:
  - `initial_year`가 있는 경우: `year - initial_year`
  - `initial_year`가 없는 경우: `NaN` (established firms)
- **용도**: Panel 분석 시 event-time 기준 분석에 사용 (예: years since initial network = 0, 1, 2, ...)
- **변수명**: `years_since_init` (짧고 직관적)

### 4) VC Reputation (Firm-Year)
- **구성 변수** (6개, 5-year rolling window [t-4, t]):
  - `rep_portfolio_count`: [t-4, t] 기간 동안 투자한 unique `comname` 개수
  - `rep_total_invested`: [t-4, t] 기간 동안 `RoundAmountDisclosedThou` 합계 (NaN → 0)
  - `rep_avg_fum`: t 시점에서 관리 중인 fund들의 평균 `fundsize`
    - 조건: `fundyear < t` AND (`fundiniclosing` 비어있음 OR `fundiniclosing_year > t`)
    - `fundiniclosing` 파싱: dd.mm.yyyy 형식 (예: 23.05.2022) → 연도 추출
    - 파싱 실패 모니터링: 로깅으로 실패 비율 출력
  - `rep_funds_raised`: [t-4, t] 기간 동안 raising한 unique `fundname` 개수
  - `rep_ipos`: 과거 투자한 회사들 중 [t-4, t] 기간 동안 IPO한 unique `comname` 개수
    - 로직: 투자는 과거에 했고, IPO는 [t-4, t] 동안 일어난 것만 카운트
  - `fundingAge`: t - min(`fundyear`) per firm (fund 데이터 기준)
- **Reputation Index 계산**:
  1. 각 변수를 연도별로 Z-score 표준화: `z = (x - mean) / std` (std=0이면 0)
  2. 6개 Z-score 합산: `rep_index_raw = Σ(z_i)`
  3. 연도별 Min-Max 스케일링: `VC_reputation = 0.01 + (raw - min) / (max - min) × 99.99`
- **Missing 처리**:
  - Fund 기반 변수(`rep_avg_fum`, `rep_funds_raised`, `fundingAge`) 누락 시 `rep_missing_fund_data = 1` 플래그 생성
  - 최종 샘플링 시 `rep_missing_fund_data = 1`인 관측치 제외 가능
- **Merge 방식**: `how='left'` (round_df 기반 firm-year 구조 유지)

### 5) 전처리/정합성
- `Undisclosed Firm/Company` 선제 제거(라운드/머지 전)
- Firm dedup: earliest founding → 동률 시 zip 보유 우선
- Company dedup: 비결측 스코어 최댓값 선택
- Round: 전체 컬럼 동치인 exact duplicates 제거
- Registry 필터: `filter_round_by_firm_registry('strict' | 'nation_select', nation_codes=[...])`
- Angel/Other/Null 제외(요청에 따름)

### 6) 모델링 가이드(요약)
- 패널 모형(예):
  - 기본: y_{i,t} = β1·centrality_{i,t} + γ_t + X_{i,t}·β + ε
  - initial_* 포함: firm FE 없이 time FE, 또는 RE/다른 FE 구성
  - 로버스트 체크: 정규화/가중, 윈도우 길이, 코호트, 변환(로그/표준화), 선택편의(in_network) 통제(in_network 더미 동시 투입) 등

### 7) 파이프라인(요약, Mermaid)
```mermaid
flowchart TD
  A[Raw Round/Company/Firm] --> B[Preprocess: Undisclosed 제거, Dedup]
  B --> C[Filtered Round (Angel/Other/Null 제외)]
  C --> D[Networks for years t: (t-TW .. t-1)]
  D --> E[Centrality (firm-year)]
  C --> F[Initial Year 식별 (Full History)]
  F --> G[Imprinting Period t1..t3]
  G --> H[Partner Centrality at each t]
  H --> I[Partner-weighted Status (firm-level)]
  C --> J[Firm Basics (firm-year)]
  C --> L[VC Reputation (firm-year)]
  E --> K[Final Panel]
  J --> K
  I --> K
  L --> K
```

---

<a id="discussion-2025-10-28"></a>
## 🧩 논의 및 합의 사항 (2025-10-28)

### 추가 업데이트 (Missing 플래그 Criticality 분류 - 2025-11-07)
- **Initial Status Missing 플래그 정의 및 Criticality 분류**: 6개 missing 플래그 컬럼의 정의와 분석상 중요도를 Low/Medium/High로 분류
  - Low Criticality: `initial_missing_outside_cohort` (설계상 정상, Control 그룹)
  - Medium Criticality: `initial_missing_no_partners`, `rep_missing_fund_data` (조건부 포함)
  - High Criticality: `initial_missing_no_centrality`, `initial_missing_other` (제외 고려)
  - Summary: `initial_status_missing` (종합 플래그)
- **샘플링 가이드**: Criticality 기반 필터링 권장사항 추가 (High 제외, Low+Medium 포함)

### 추가 업데이트 (Market Heat 및 New Venture Funding Demand 변수 추가 - 2025-11-07)
- **Market Heat 변수 구현**: Industry-level 변수로 VC fund raising 활동의 상대적 활성도 측정
  - 공식: `Market heat_t = ln((VC funds raised_t × 3) / Σ_{k=t-3}^{t-1} VC funds raised_k)`
  - 해석: >0 = Hot market, <0 = Cold market
  - Edge cases: 분모=0 또는 ratio≤0인 경우 `NaN` 처리
  - 함수: `calculate_market_heat(fund_df, ...)` → year-level 출력, firm-year 패널에 merge 시 같은 연도면 동일 값
- **New Venture Funding Demand 변수 구현**: Industry-level 변수로 VC 펀딩 수요 측정 (current year, NOT lagged)
  - 공식: `new_venture_demand_t = ln(count of first-round US ventures in year t)`
  - 기준: RoundNumber == min(RoundNumber) per company로 첫 라운드 식별, US만 필터링
  - 시점: 당해 연도 값 사용 (Raw 데이터셋이므로 lagged 아님, panel 분석 시 lagging 필요)
  - 함수: `calculate_new_venture_funding_demand(round_df, company_df, ...)` → year-level 출력, firm-year 패널에 merge 시 같은 연도면 동일 값
- **Years Since Initial Network 변수 추가**: `years_since_init = year - initial_year`
  - 용도: Event-time 기준 분석 (years since initial network = 0, 1, 2, ...)
  - 변수명: `years_since_init` (짧고 직관적)
- **HQ 더미 변수 확장**: `firm_hq_CA`, `firm_hq_MA`, `firm_hq_NY` 추가 (기존 `firm_hq` 유지)

### 추가 업데이트 (VC Reputation 구현 - 2025-11-07)
- **VC Reputation Index 구현**: 6개 구성 변수를 5-year rolling window [t-4, t]로 계산
  - 변수 1-2, 4: Portfolio count, Total invested, Funds raised (round 데이터 기반)
  - 변수 3: Average FUM (fund 데이터 기반, fundiniclosing 파싱 포함)
  - 변수 5: IPOs (투자는 과거, IPO는 [t-4, t] 동안 발생한 것만 카운트)
  - 변수 6: Funding age (fundyear 기준 첫 fund raising year)
- **Reputation 계산**: 연도별 Z-score 표준화 → 합산 → 연도별 Min-Max 스케일링 [0.01, 100]
- **Missing 처리**: `rep_missing_fund_data` 플래그 추가 (fund 기반 변수 누락 시 1, 최종 샘플링 시 제외 가능)
- **Merge 방식**: `how='left'` 사용 (round_df 기반 firm-year 구조 유지)
- **파싱 모니터링**: fundiniclosing 파싱 실패 비율 로깅 추가

### 추가 업데이트 (Geographic Distance 변수 추가 - 2025-11-07)
- **Geographic Distance 변수 구현**: ZIP 코드 기반 Haversine 거리 계산
  - **VC-Company 거리** (6개 변수): 평균, 최소, 최대, 중앙값, 가중 평균, 표준편차
  - **VC-Co-Partner 거리** (6개 변수): 평균, 최소, 최대, 중앙값, 가중 평균, 표준편차
  - **Initial Period Co-Partner 거리** (6개 변수): t1~t3 기간 동안의 공동 투자 파트너 거리 집계
  - ZIP 코드 정규화: 5자리 문자열로 변환 (leading zeros 처리)
  - ZIP → 위경도 변환: `uszipcode` 라이브러리 사용
  - Haversine 공식: 지구 표면의 대원 거리 계산 (단위: km)
  - 추천 변수: 중앙값 (robust), 가중 평균 (investment-weighted), 표준편차 (dispersion)
  - 함수: `calculate_vc_company_distances()`, `calculate_vc_copartner_distances()` in `vc_analysis/distance/geographic.py`
  - Initial period 함수: `calculate_initial_period_geographic_distances()` in `vc_analysis/network/imprinting.py`

### 추가 업데이트 (Final sampling + export)
- 분석 가능 샘플 필터 추가: 연도/기본변수/네트워크(in_network)/초기상태/성과 조건을 토글로 구성하여 `analysis_df` 생성.
- 저장 포맷: Parquet(기본), Feather(가능 시), CSV는 용량 제한을 위해 샘플링 저장(`CSV_SAMPLE_N`, 무작위/상위 N 선택 지원).
- R 호환성: arrow 패키지(`read_parquet`, `read_feather`)로 즉시 로딩 가능하도록 저장.
- 인덱스 정리: `analysis_df.reset_index(drop=True)` 적용.
- 파일명 스탬프: 날짜시간 스탬프 추가 (예: `final_analysis_1990_2000_251107_0033.parquet`)


### 추가 업데이트 (2025-10-28)
- Initial status NaN 진단: ‘outside_cohort’ 외 11% ‘other’의 주요 원인은 코호트 내 최초연도는 존재하나(t1~t3) 파트너가 0인 경우가 많음. `initial_ties_df`에 해당 firm이 없음을 활용해 ‘no_partners’로 재분류 로직을 제시.
- 진단 코드 보강: `initial_year_full`을 `final_df`에 병합하여 진단 셀의 KeyError 해소. 이름 불일치/매칭 이슈 탐지용 분해 지표 추가.
- Merge 기준 확정: 최종 병합은 `firm_vars_df_filtered`(투자 집행 firm-year)를 기준으로 수행, `centrality_df`와 `initial_ties_df`를 좌결합.
- 중앙성 NA 처리: `in_network` 더미 생성과 선택적 zero-fill을 파라미터로 제어. 회귀 시 in_network를 통제변수로 함께 투입 권장.

- in_network=1 & initial_*=NaN이 가능한 이유
  - 시간축 불일치: 분석 기간 firm-year에서는 등장(in_network=1), 초기연도는 코호트 밖 → initial_* 미산출(머지 후 NaN)
  - 래그 네트워크: 임프린팅 계산은 [t−TIME_WINDOW, t−1] 기반. 특정 파트너가 해당 래그 네트워크에 없을 수 있어 부분 결측 발생 가능(매칭/컷포인트/명칭 표준화 이슈 포함)
- 파라미터/노트북 반영
  - 중앙성 NA 처리 토글: `create_in_network_dummy`, `fill_missing_centrality_as_zero`, `zero_fill_columns`
  - 노트북: in_network 생성/선택적 0-치환 셀 추가
  - 로더: Undisclosed 제거, firm/company dedup, round 중복 제거, firm registry 필터 추가
  - 펌 변수: `fill_missing_performance_with_zero()`로 perf_* 0-치환 후처리 지원

---

<a id="history"></a>
## 🕒 히스토리 (요약 타임라인)

- 2025-11-07: Market Heat 변수 추가 (industry-level, 과거 3년 대비 당해 연도 fund raising 상대적 활성도, ln ratio), New Venture Funding Demand 변수 추가 (industry-level, lagged, 전년도 첫 라운드 US 벤처 개수 ln), HQ 더미 변수 확장 (firm_hq_CA, firm_hq_MA, firm_hq_NY 추가). Missing 플래그 Criticality 분류 완료 (6개 컬럼 정의 및 Low/Medium/High 분류, 샘플링 가이드 추가). VC Reputation Index 구현 완료 (6개 구성 변수, Z-score 표준화, Min-Max 스케일링), IPO 로직 수정 (투자는 과거, IPO는 [t-4, t]), Merge 방식 left join으로 변경, rep_missing_fund_data 플래그 추가, fundiniclosing 파싱 모니터링 추가. Geographic Distance 변수 추가 완료 (ZIP 코드 기반 Haversine 거리, VC-Company 6개 변수, VC-Co-Partner 6개 변수, Initial Period Co-Partner 거리 6개 변수, 추천 변수: median, weighted_mean, std).

- 2025-10-28: 코호트 내 initial_* 결측 진단 및 재분류 제안(‘other’→‘no_partners’), 진단 셀 안정화(`initial_year_full` 보강), merge 기준 확정, centrality NA 후처리 가이드 반영.

- 네트워크 분석 기반 구축: START/END 연도 범위, time_window 도입, Excel serial 처리, firmtype2 모듈 병합
- 중심성 고도화: 지표별 정규화/가중 토글, `pwr_max`, `ego_dens`, `constraint` NA 채움/1.0 상한
- 임프린팅: Full History 기반 `initial_year` 식별, t1~t3 파트너, 5년 래그 중심성, 파트너-가중 집계(mean/max/min)
- 펌 변수: age, Blau(comindmnr), perf(당해만), early ratio, HQ(CA/MA), inv_amt/num, 0-치환 헬퍼
- 노트북 통합: 기준 데이터 firm_vars_df_filtered → centrality left join → initial_ties left join → 후처리

---

<a id="files"></a>
## 📁 주요 파일 구조
```
refactor_v2/
├── notebooks/
│   ├── preprc_imprint.ipynb          # 메인 분석 노트북
│   └── imprinting_analysis_history.md # 이 파일
├── vc_analysis/
│   ├── data/loader.py                 # 데이터 로딩/정합성/필터
│   ├── network/
│   │   ├── construction.py            # 네트워크 생성
│   │   ├── centrality.py              # 중심성 계산
│   │   └── imprinting.py              # 임프린팅 변수
│   ├── variables/firm_variables.py    # 펌 레벨 변수 및 헬퍼
│   └── config/
│       ├── parameters.py              # 설정(정규화/가중/NA/후처리 토글)
│       └── constants.py               # 상수 정의
└── research_history.md                # 전체 연구 히스토리
```

---

<a id="highlights"></a>
## 🎯 핵심 성과
1. 방법론: 파트너-가중 임프린팅 정의(시간평균→파트너 집계)
2. 기술: 모듈화된 파이프라인 및 설정 토글(재현성/확장성)
3. 데이터 품질: Undisclosed 제거, dedup 표준, NA 처리 가이드 제공
4. 분석 준비: Firm-Year 패널 `final_df` 완성, 회귀 바로 수행 가능

---

**최종 업데이트**: 2025-11-07  
**분석 상태**: 데이터 준비 완료 (VC Reputation, Market Heat, New Venture Funding Demand 포함), Years Since Initial Network 변수 추가 완료, Missing 플래그 Criticality 분류 완료, HQ 더미 변수 확장 완료, Initial Period Variables (7개) 추가 완료, Geographic Distance 변수 추가 완료 (VC-Company 6개, VC-Co-Partner 6개, Initial Period 6개), Raw 데이터셋 준비 완료 (panel 분석 시 lagging 필요), 분석 단계 진입 준비  
**다음 미팅**: 회귀 분석 결과 검토
