## 임프린팅·VC 네트워크 분석을 위한 통계 이슈 정리

최종 업데이트: 2025-11-07

### 📑 목차 (TOC)
- [목적과 범위](#purpose)
- [패널 축 선택: obs.year vs init.year](#index-choice)
- [권장 이벤트-스터디(event-study) 사양](#event-study)
- [고정효과(FE): 식별과 유의점](#fixed-effects)
- [Missing 플래그(initial_xxx_missing) 활용](#missingness)
- [측정 윈도우와 정합성](#windows)
- [검열/절단 및 표본 구성](#censoring)
- [추론과 표준오차](#inference)
- [극단치, 스케일링, 변환](#scaling)
- [다중검정과 차원 축소](#multi-testing)
- [공선성 및 드랍 변수](#collinearity)
- [선택편의와 in_network 이슈](#selection-bias)
- [데이터 품질과 머지 정합성](#data-quality)
- [로버스트 체크(메뉴)](#robustness)
- [보고와 재현성](#reporting)
- [실무 체크리스트](#checklist)

---

### 목적과 범위 <a id="purpose"></a>
- 본 문서는 임프린팅 분석(VC의 초기 파트너 네트워크와 그 지속효과)에 필요한 통계적 고려사항을 체계화합니다.
  - 초기 파트너 속성의 n년 지속성 검증(τ = year − init_year 기반).
  - 소셜 네트워크 지표(중심성), 파트너-가중 초기상태, Firm 기초변수, VC 명성(평판) 포함.
  - 현재 코드베이스(`vc_analysis/network/*`, `vc_analysis/variables/firm_variables.py`, 노트북 파이프라인)와 정합.

---

### 패널 축 선택: obs.year vs init.year <a id="index-choice"></a>
- 패널 인덱스 옵션:
  - VC–obs.year: 표준 패널. 캘린더 연도 고정효과(γ_t)로 거시충격 통제가 용이. 권장.
  - VC–init.year: 각 VC의 진짜 초기연도 기준 정렬. 연도 FE의 해석이 모호해지고 매크로 통제가 어려움.
- 권장:
  - 기본은 VC–obs.year를 유지하고, 이벤트-타임 τ = year − init_year를 더미/스플라인으로 모델링(event-study).
  - 연도 FE(γ_t)를 유지하면서 동학적 지속효과(τ)를 추정할 수 있음.

---

### 권장 이벤트-스터디(event-study) 사양 <a id="event-study"></a>
- 기본 모형(예: 카운트형 결과; DV에 맞춰 변경):

```text
y_{i,t} = Σ_{k=0..n} β_k · 1[τ = k] + γ_i + γ_t + X_{i,t}·δ + ε_{i,t}
```

- 정의:
  - τ = year − init_year (초기연도 대비 경과 연도).
  - γ_i: VC 고정효과, γ_t: 캘린더 연도 고정효과.
  - X_{i,t}: 시간가변 통제(“나쁜 통제” 주의).
  - 가능하면 선행값(lead, k<0)을 포함해 사전추세 점검(평행추세).
- 본 맥락에서의 장점:
  - 초기연도가 서로 다른(staggered) 설정에서 거시충격을 γ_t로 통제.
  - 네트워크(과거창 [t−TW, t−1])·임프린팅(t1~t3)·기초변수·평판 변수와 자연스럽게 결합.

---

### 고정효과(FE): 식별과 유의점 <a id="fixed-effects"></a>
- VC–init.year 패널만으로는 γ_t(캘린더 연도 FE)의 정의가 불안정하고 거시충격 통제가 취약.
- VC–obs.year + τ가 실무적으로 안전하고 해석 용이.
- initial_*와 Firm FE:
  - initial_*는 firm-level 상수 → γ_i(VC FE)와 함께 쓰면 공선성으로 드랍됨.
  - 대응:
    - γ_i를 사용하지 않고 대체 FE(예: time FE + cohort-by-year FE)로 설계.
    - initial_* × (τ/코호트) 등 상호작용을 모형화(이론적 근거 필요).
    - 초기상태를 별도 단면 혹은 2단계 모형으로 분석.

---

### Missing 플래그(initial_xxx_missing) 활용 <a id="missingness"></a>
- 플래그(요약):
  - Summary: `initial_status_missing`
  - Low: `initial_missing_outside_cohort`(설계상 정상, Control)
  - Medium: `initial_missing_no_partners`(솔로 투자), `rep_missing_fund_data`
  - High: `initial_missing_no_centrality`, `initial_missing_other`(제외 고려)
- 권장 표본 구성:
  - Low + Medium 포함, High 제외.
  - τ·코호트별 missing 비율을 함께 보고(정보적 결측 가능성 점검).
- `in_network` 더미:
  - 네트워크 참여 여부 차이를 흡수하기 위해 결과모형에 포함 권장.

---

### 측정 윈도우와 정합성 <a id="windows"></a>
- 네트워크 중심성: 연도 t의 지표는 [t−TIME_WINDOW, t−1] 래그 네트워크에서 계산(동시성 완화).
- 초기 파트너 상태:
  - 전체 히스토리로 `initial_year` 식별.
  - 임프린팅 기간 t1~t3, 각 t의 파트너 중심성은 래그 네트워크에서 측정, 파트너-가중(평균/최대/최소) 집계.
- Firm 기초변수:
  - `perf_*`: 당해만(lookback=0), 병합 후 필요 시 0 치환.
  - `early_stage_ratio`: `comstage1/2/3` 기반.
- VC 평판:
  - 6개 변수 [t−4, t] 롤링, 연도별 z-score, Min-Max [0.01, 100].
  - 펀드 정보 결측은 `rep_missing_fund_data`로 명시.

---

### 검열/절단 및 표본 구성 <a id="censoring"></a>
- 좌측 검열:
  - 초기연도가 데이터 시작 이전이면 τ가 과소추정될 수 있음.
  - 사전기간(lead)이 충분한 코호트로 제한하거나, τ 커버리지가 확보된 서브샘플로 보고.
- 우측 검열/생존편향:
  - 큰 τ에서 생존 VC가 과대표집 → 균형 τ 윈도우 서브샘플, 생존 통제/가중 적용.
- 균형 윈도우 감도:
  - 모든 VC가 τ ∈ [0..n]을 관측하는 균형 패널 결과를 함께 보고.

---

### 추론과 표준오차 <a id="inference"></a>
- 이중 클러스터 표준오차(VC, year) 권장.
- 클러스터 수가 적거나 불균형하면 와일드 클러스터 부트스트랩 고려.
- 카운트형 DV: Poisson/NB + 클러스터-로버스트 SE.
- 사건시간 관점 보완: 생존모형(분석시간=τ)으로 보강.

---

### 극단치, 스케일링, 변환 <a id="scaling"></a>
- 중심성은 연도별 표준화(혼합연도 비교 시), 평판은 이미 표준화/스케일링 적용.
- 분포가 긴 지표(매개중심성, 금액)는 윈저라이즈.
- 선형모형에서 금액 로그변환(0 처리 주의) 고려.

---

### 다중검정과 차원 축소 <a id="multi-testing"></a>
- 많은 중심성 지표와 집계(평균/최대/최소) → FDR 통제 또는 요인/지수화.
- 주요 결과/지표를 사전 지정(pre-specify)하여 데이터 마이닝 우려 완화.

---

### 공선성 및 드랍 변수 <a id="collinearity"></a>
- γ_i와 initial_* 동시 사용 시 initial_* 드랍(상수).
- 중심성·평판 구성요소 간 상관/ VIF 점검.

---

### 선택편의와 in_network 이슈 <a id="selection-bias"></a>
- `in_network`=0 집단은 체계적으로 다를 수 있음 → 더미 통제 및 네트워크 참여 표본 분석 시 해석 주의.
- 사후적 통제 금지:
  - 결과와 동시기(혹은 이후) 측정된 네트워크 지표를 통제하지 말 것(전달경로 차단 위험).
  - 래그 지표 또는 초기(τ=0) 기준치 사용을 선호(이론 근거 필요).

---

### 데이터 품질과 머지 정합성 <a id="data-quality"></a>
- 전처리 표준:
  - Undisclosed 제거, firm/company 중복 제거, round 완전중복 제거, firm registry 필터.
  - 산업: `comindmnr`, 초기단계: `comstage1/2/3`.
  - 성과: R 로직 반영(IPO/M&A), `firm_hq` 일치, 성과 결측 0 치환 헬퍼 제공.
- 주의:
  - IPO 집계: 과거 투자한 회사 중 [t−4, t]에 IPO 발생한 건만 카운트 → 회사명 매칭 품질 중요.
  - 펀드 종료일 파싱(`dd.mm.yyyy`) 실패는 로깅, `rep_missing_fund_data` 플래그로 명시.

---

### 로버스트 체크(메뉴) <a id="robustness"></a>
1. 이벤트 창 n(예: 1, 2, 3, 5년) 변화.
2. 네트워크 창 TW 변화([t−TW, t−1]), 가중/무가중 에지 비교.
3. 파트너 집계 대안: 중앙값, 상위 k, 파트너 평균 윈저라이즈.
4. Criticality 필터: Medium 포함/제외; High 항상 제외. 비율 및 결과 영향 보고.
5. 코호트 통제: 코호트 FE, 코호트×τ FE; 1990s vs 2000s 등 서브코호트.
6. 결과모형: Poisson vs NB; 이분형은 LPM vs Logit; 생존모형 보완.
7. 극단치 처리: 윈저라이즈 임계값, 로그 변환 감도.
8. 머지 기준 감도: `firm_vars_df_filtered` 기준 vs 네트워크 기준 비교(건전성 점검).
9. 평판 포함/제외, 구성요소 교체.
10. 표준오차: 이중 클러스터 vs 와일드 부트스트랩.

---

### 보고와 재현성 <a id="reporting"></a>
- 항상 보고:
  - 코호트 정의, τ 창, τ 커버리지.
  - 플래그별 결측 비율과 적용 필터.
  - FE 구조(γ_i 사용 유무)와 initial_* 식별 함의.
  - SE 클러스터링 및 부트스트랩 선택.
- 재현성:
  - TIME_WINDOW, τ horizon n, 필터, 표준화 등 모든 설정 로깅.
  - 타임스탬프 파일 저장(이미 구현)으로 버전 관리.

---

### 실무 체크리스트 <a id="checklist"></a>
- [ ] τ horizon n(예: 2·3년) 정의, 커버리지 점검.
- [ ] VC–obs.year 패널 유지 + τ 더미/스플라인 추가.
- [ ] γ_i(VC FE), γ_t(year FE) 포함; initial_* 공선성 주의.
- [ ] `in_network` 더미 포함; 사후적(동시기) 네트워크 통제 회피.
- [ ] Criticality 필터 적용: High 제외, Medium 포함 여부 결정 및 기록.
- [ ] 윈도우 확인: 네트워크 [t−TW, t−1], 임프린팅 t1~t3, perf(당해), 평판 [t−4, t].
- [ ] 검열/생존편향 점검: 균형 τ 윈도우, 생존 통제/가중.
- [ ] 극단치/스케일링: 윈저라이즈, 연도별 표준화 또는 로그 변환.
- [ ] 표준오차: (VC, year) 이중 클러스터; 필요 시 와일드 부트스트랩.
- [ ] 로버스트 체크 실행 및 결과 보고; 주요 결과/지표 사전 지정.

---

필요 시, 현재 `analysis_df` 컬럼에 맞춰 τ 더미·이중 클러스터·플래그 필터가 포함된 이벤트-스터디 코드 템플릿도 제공 가능합니다.


