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
  - `firmage`, `industry_blau`(comindmnr), `perf_*`(당해 연도), `early_stage_ratio`, `firm_hq`(CA/MA), `inv_amt`, `inv_num`
  - `fill_missing_performance_with_zero(df, ...)` 제공
  - **VC Reputation**: 6개 구성 변수 + Z-score 표준화 + Min-Max 스케일링 [0.01, 100]
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
- 집계: 파트너별 시간 평균 → 파트너 간 mean/max/min(“partner-weighted” 의미 유지)
- 회귀 가이드(식별 주의):
  - Firm FE 사용 시: initial_*는 firm-level 상수 → 완전 공선성으로 식별 불가(모형에서 떨어짐)
  - 대안: firm FE 미사용 + time FE, RE, cohort-by-year FE, 혹은 initial_* × year 상호작용 등 설계
  - 코호트 외 초기연도(예: 1985)인 경우: initial_*는 결측이 정상이며, 이는 설계 상 Control 그룹 해석과 정합

### 3) Firm Basics (Firm-Year)
- `firmage = year − founding_year`(음수 0 캡)
- `industry_blau`: comindmnr 기준 Blau index(연도별)
- `perf_*`: 당해 연도만, 매칭 안 된 firm-year는 머지 후 NaN → 분석 전 0-치환 권장(`fill_missing_performance_with_zero`)
- `early_stage_ratio`: 설정된 Stage set 평균(연도별)
- `inv_amt`, `inv_num`: 연도별 합/건수
- `firm_hq`: CA/MA 더미(firm-level → 모든 연도에 병합)

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

- 2025-11-07: VC Reputation Index 구현 완료 (6개 구성 변수, Z-score 표준화, Min-Max 스케일링), IPO 로직 수정 (투자는 과거, IPO는 [t-4, t]), Merge 방식 left join으로 변경, rep_missing_fund_data 플래그 추가, fundiniclosing 파싱 모니터링 추가.

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
**분석 상태**: 데이터 준비 완료 (VC Reputation 포함), 분석 단계 진입 준비  
**다음 미팅**: 회귀 분석 결과 검토
