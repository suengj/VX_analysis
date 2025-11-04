# VC 네트워크 분석 데이터 플로우

## 개요
이 문서는 원본 Excel 데이터부터 최종 회귀분석용 데이터까지의 전체 데이터 플로우를 상세히 기술합니다.

---

## 전체 파이프라인 개요

```
┌─────────────────────────────────────────────────────────────┐
│                        Phase 1: 데이터 로딩                    │
└─────────────────────────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  Raw Excel Files                        │
        │  • round/*.xlsx (19개 파일, 1970-2022)  │
        │  • comp/*.xlsx (4개 파일)               │
        │  • firm/VC_firm_US.xlsx                 │
        │  • fund_all.xlsx                        │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  Python: data/loader.py                 │
        │  • Excel 파일 읽기 및 병합              │
        │  • 날짜 파싱 (POSIXct → datetime)       │
        │  • dtype 최적화 (메모리 효율)           │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  Merged DataFrames                      │
        │  • round_df: ~100만 rows                │
        │  • company_df: ~10만 rows               │
        │  • firm_df: ~3만 rows                   │
        │  • fund_df: ~5만 rows                   │
        └─────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   Phase 2: 데이터 필터링 & 정제                │
└─────────────────────────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  Python: data/filter.py                 │
        │  • US only 필터                         │
        │  • Angel/Individual 제외                │
        │  • 연령 필터 (firmage >= 0)             │
        │  • 우편번호 검증                        │
        │  • 중복 제거                            │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  Filtered DataFrames                    │
        │  • round_df: ~60만 rows (40% 감소)      │
        │  • company_df: ~8만 rows                │
        │  • firm_df: ~2만 rows                   │
        └─────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                     Phase 3: 네트워크 구성                     │
└─────────────────────────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  Python: network/construction.py        │
        │  • Event 생성 (comname-year)            │
        │  • 2-Mode 네트워크 (VC-Event)           │
        │  • 1-Mode 투영 (VC-VC)                  │
        │  • 연도별 반복 (1980-2022)              │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  Network Objects (per year)             │
        │  • 1980-2022: 43개 네트워크             │
        │  • 평균 nodes: 3,000-5,000              │
        │  • 평균 edges: 10,000-20,000            │
        └─────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                     Phase 4: 중심성 계산                       │
└─────────────────────────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  Python: network/centrality.py          │
        │  • Degree centrality                    │
        │  • Betweenness centrality               │
        │  • Power centrality (3가지 베타)        │
        │  • Constraint (구조적 구멍)             │
        │  • 병렬 처리 (joblib)                   │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  Centrality DataFrame                   │
        │  • ~15만 rows (firmname-year)           │
        │  • 7개 컬럼: dgr, btw, pwr_75, pwr_max, │
        │             pwr_zero, constraint        │
        └─────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                     Phase 5: 거리 계산                         │
└─────────────────────────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  Python: distance/                      │
        │  • geographic.py: 우편번호 거리         │
        │  • industry.py: Blau 지수, 산업 거리    │
        │  • network/distance.py: 네트워크 거리   │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  Distance DataFrames                    │
        │  • network_distance: ~500만 rows        │
        │    (VC1-VC2-year)                       │
        │  • geo_distance: ~500만 rows            │
        │  • industry_distance: ~500만 rows       │
        │  • blau_index: ~15만 rows               │
        └─────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                     Phase 6: 성과 변수 계산                    │
└─────────────────────────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  Python: variables/performance.py       │
        │  • Exit 수 계산 (5년 누적)              │
        │  • IPO 수 계산                          │
        │  • M&A 수 계산                          │
        │  • 투자 금액 집계                       │
        │  • 펀드 수 계산                         │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  Performance DataFrame                  │
        │  • ~15만 rows (firmname-year)           │
        │  • exitNum, ipoNum, MnANum              │
        │  • AmtInvested, fundcnt                 │
        └─────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              Phase 7: 분석별 데이터셋 구성                     │
└─────────────────────────────────────────────────────────────┘
        
        ┌──────────────────────┐    ┌──────────────────────┐
        │   CVC Analysis Path   │    │ Imprinting Analysis  │
        │                       │    │       Path           │
        └──────────────────────┘    └──────────────────────┘
                 ↓                              ↓
     ┌────────────────────────┐    ┌─────────────────────────┐
     │ LeadVC Identification  │    │ Initial Network         │
     │ (sampling/leadvc.py)   │    │ (sampling/initial.py)   │
     └────────────────────────┘    └─────────────────────────┘
                 ↓                              ↓
     ┌────────────────────────┐    ┌─────────────────────────┐
     │ 1:10 Case-Control      │    │ Imprinting Period       │
     │ Sampling               │    │ Filtering               │
     │ (sampling/case_        │    │                         │
     │  control.py)           │    │                         │
     └────────────────────────┘    └─────────────────────────┘
                 ↓                              ↓
     ┌────────────────────────┐    ┌─────────────────────────┐
     │ Variable Merging       │    │ Panel Data              │
     │ • Centrality           │    │ Construction            │
     │ • Distance             │    │ • Focal centrality      │
     │ • Performance          │    │ • Partner centrality    │
     │ • Controls             │    │ • Time-varying vars     │
     └────────────────────────┘    └─────────────────────────┘
                 ↓                              ↓
     ┌────────────────────────┐    ┌─────────────────────────┐
     │ CVC Final Dataset      │    │ Imprinting Final        │
     │ • ~500만 rows          │    │ Dataset                 │
     │ • 50+ variables        │    │ • ~10만 rows            │
     │ • Dyad-quarter level   │    │ • 40+ variables         │
     │                        │    │ • Firm-year level       │
     └────────────────────────┘    └─────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                     Phase 8: 데이터 저장                       │
└─────────────────────────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  Python: utils/io.py                    │
        │  • Parquet 저장 (snappy 압축)           │
        │  • 메타데이터 JSON 저장                 │
        │  • 파일 크기: ~100-500MB                │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  Parquet Files                          │
        │  • cvc_analysis_final.parquet           │
        │  • imprinting_analysis_final.parquet    │
        │  • centrality_data.parquet              │
        │  • network_distance.parquet             │
        └─────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                     Phase 9: R 회귀분석                        │
└─────────────────────────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  R: regression/data_loader.R            │
        │  • Parquet 로드 (arrow 패키지)          │
        │  • data.frame 변환                      │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  R: regression/                         │
        │  • cvc_regression.R: clogit             │
        │  • imprinting_regression.R: pglm        │
        │  • diagnostics.R: VIF, model fit        │
        └─────────────────────────────────────────┘
                              ↓
        ┌─────────────────────────────────────────┐
        │  Results                                │
        │  • 회귀계수, p-value                    │
        │  • 모델 통계량                          │
        │  • Excel/RDS 저장                       │
        └─────────────────────────────────────────┘
```

---

## 상세 데이터 플로우

### 1. CVC 분석 플로우

#### Step 1-1: 데이터 로딩
```python
# Input
round_files = [
    'round_1970-79.xlsx',
    'round_1980-84.xlsx',
    ...
    'round_2022.xlsx'
]

# Process
round_df = load_and_merge_excel_files(round_files)
# • 19개 파일 → 1개 DataFrame
# • 1,045,231 rows × 30 columns
# • 메모리: ~800MB

company_df = load_company_data()
# • 4개 파일 병합
# • 102,451 rows × 25 columns
# • 메모리: ~50MB

firm_df = load_firm_data()
# • 1개 파일
# • 28,932 rows × 20 columns
# • 메모리: ~20MB

# Output
{
    'round': round_df,
    'company': company_df,
    'firm': firm_df,
    'fund': fund_df
}
```

#### Step 1-2: 데이터 정제
```python
# Input
round_df (1,045,231 rows)

# Process
round_df = (
    round_df
    .pipe(filter_us_only)              # US VC & company만
    .pipe(remove_undisclosed)          # Undisclosed 제거
    .pipe(filter_by_age)               # firmage >= 0
    .pipe(validate_zipcode)            # 유효한 우편번호만
    .pipe(remove_angel_investors)      # Angel 제외
)

# Output
round_df (623,847 rows)  # 40% 감소
```

#### Step 2-1: LeadVC 식별
```python
# Input
round_df (623,847 rows)

# Process
leadvc_df = identify_lead_vcs(round_df)
# • 각 company-round 조합에서 LeadVC 1명 선택
# • 기준: FirstRound, InvestmentRatio, TotalAmount

# Output
leadvc_df (52,381 rows)
# columns: ['comname', 'leadVC']
```

#### Step 2-2: 네트워크 구성 (연도별)
```python
# Input
round_df, year_list (1980-2022)

# Process (병렬 처리)
networks = {}
for year in year_list:
    # 5년 time window
    edge_data = round_df[
        (round_df['year'] >= year-5) & 
        (round_df['year'] <= year-1)
    ]
    
    # 2-mode → 1-mode
    networks[year] = construct_vc_network(edge_data)

# Output
networks = {
    1980: Graph(nodes=1,234, edges=3,456),
    1981: Graph(nodes=1,456, edges=4,123),
    ...
    2022: Graph(nodes=8,912, edges=45,678)
}
```

#### Step 2-3: 중심성 계산 (병렬)
```python
# Input
networks (43개 네트워크)

# Process (병렬 처리, 8 cores)
centrality_results = []

with Parallel(n_jobs=8) as parallel:
    results = parallel(
        delayed(compute_centralities)(network, year)
        for year, network in networks.items()
    )

centrality_df = pd.concat(results)

# Output
centrality_df (147,823 rows)
# columns: ['firmname', 'year', 'dgr_cent', 'btw_cent', 
#           'pwr_p75', 'pwr_max', 'pwr_zero', 'constraint']
```

#### Step 3-1: 1:10 샘플링
```python
# Input
round_df, leadvc_df
quarters = ['1985Q1', '1985Q2', ..., '2022Q4']

# Process
sampled_data_list = []

for quarter in quarters:
    quarter_data = round_df[round_df['quarter'] == quarter]
    
    for (leadVC, comname) in get_leadvc_company_pairs(quarter_data):
        # 실현된 파트너
        realized = get_realized_partners(leadVC, comname, quarter_data)
        
        # 잠재적 파트너
        potential = get_potential_partners(leadVC, quarter_data)
        
        # 1:10 샘플링
        unrealized_sample = potential.sample(
            n=len(realized)*10, 
            random_state=123
        )
        
        sampled = pd.concat([realized, unrealized_sample])
        sampled_data_list.append(sampled)

sampled_df = pd.concat(sampled_data_list)

# Output
sampled_df (5,234,891 rows)
# columns: ['leadVC', 'coVC', 'comname', 'quarter', 'realized']
# realized=1: 476,808 rows (9%)
# realized=0: 4,758,083 rows (91%)
```

#### Step 3-2: 변수 병합
```python
# Input
sampled_df (5,234,891 rows)
centrality_df (147,823 rows)
distance_df (4,923,456 rows)
performance_df (147,823 rows)
...

# Process
final_df = (
    sampled_df
    .merge(centrality_df, left_on=['leadVC', 'year'], 
           right_on=['firmname', 'year'], suffixes=('', '_lead'))
    .merge(centrality_df, left_on=['coVC', 'year'], 
           right_on=['firmname', 'year'], suffixes=('', '_co'))
    .merge(distance_df, on=['leadVC', 'coVC', 'year'])
    .merge(performance_df, left_on=['coVC', 'year'], 
           right_on=['firmname', 'year'])
    ...
)

# Output
final_df (5,234,891 rows × 54 columns)
```

#### Step 3-3: Parquet 저장
```python
# Input
final_df (5,234,891 rows × 54 columns)
# Memory: ~2.5GB

# Process
final_df.to_parquet(
    'cvc_analysis_final.parquet',
    compression='snappy',
    engine='pyarrow'
)

# Output
File: cvc_analysis_final.parquet
Size: ~450MB (82% 압축)
```

---

### 2. Imprinting 분석 플로우

#### Step 1: Initial Year 식별
```python
# Input
round_df (623,847 rows)

# Process
initial_year_df = (
    round_df
    .sort_values(['firmname', 'year'])
    .groupby('firmname')
    .first()
    .reset_index()
    [['firmname', 'year']]
    .rename(columns={'year': 'initial_year'})
)

# Output
initial_year_df (18,234 rows)
# 각 VC의 첫 투자 연도
```

#### Step 2: Initial Ties 식별
```python
# Input
round_df, initial_year_df
imprinting_period = 3  # 3년

# Process
initial_ties_list = []

for year in range(1980, 2023):
    # Imprinting period (year ~ year+2)
    period_data = round_df[
        (round_df['year'] >= year) & 
        (round_df['year'] < year + imprinting_period)
    ]
    
    # VC-VC 네트워크
    vc_network = construct_initial_network(period_data)
    
    # 엣지 추출
    ties = extract_edges(vc_network)
    ties['tied_year'] = year
    
    initial_ties_list.append(ties)

initial_ties_df = pd.concat(initial_ties_list)

# Initial year와 병합
initial_ties_df = initial_ties_df.merge(
    initial_year_df, 
    on='firmname'
)

# Imprinting period 필터링
initial_ties_df = initial_ties_df[
    initial_ties_df['tied_year'] - initial_ties_df['initial_year'] < imprinting_period
]

# Output
initial_ties_df (92,341 rows)
# columns: ['firmname', 'initial_partner', 'tied_year', 'initial_year']
```

#### Step 3: Initial Partner Centrality
```python
# Input
initial_ties_df (92,341 rows)
centrality_df (147,823 rows)

# Process
# Partner centrality (초기 파트너들의 중심성)
partner_cent = (
    initial_ties_df
    .merge(centrality_df, 
           left_on=['initial_partner', 'tied_year'],
           right_on=['firmname', 'year'])
    .groupby(['firmname', 'tied_year'])
    .agg({
        'dgr_cent': 'sum',      # Degree는 합
        'btw_cent': 'mean',     # 나머지는 평균
        'pwr_p75': 'mean',
        'pwr_max': 'mean',
        'constraint': 'mean'
    })
    .reset_index()
    .add_prefix('p_')
)

# Focal centrality (본인의 초기 중심성)
focal_cent = (
    initial_ties_df
    .merge(centrality_df, 
           on=['firmname', 'tied_year'])
    .groupby(['firmname', 'tied_year'])
    .agg({
        'dgr_cent': 'mean',
        'btw_cent': 'mean',
        'pwr_p75': 'mean',
        'pwr_max': 'mean',
        'constraint': 'mean'
    })
    .reset_index()
    .add_prefix('f_')
)

# Output
partner_cent (18,234 rows)
focal_cent (18,234 rows)
```

#### Step 4: Panel 데이터 구성
```python
# Input
initial_ties_df, partner_cent, focal_cent
performance_df, centrality_df

# Process
# Firm-Year 레벨 확장 (1980-2022)
firm_years = []
for firmname in initial_year_df['firmname']:
    initial_year = initial_year_df[
        initial_year_df['firmname'] == firmname
    ]['initial_year'].iloc[0]
    
    for year in range(initial_year, 2023):
        firm_years.append({
            'firmname': firmname,
            'year': year,
            'timesince': year - initial_year
        })

panel_df = pd.DataFrame(firm_years)

# 변수 병합
panel_df = (
    panel_df
    .merge(partner_cent, on='firmname')
    .merge(focal_cent, on='firmname')
    .merge(centrality_df, on=['firmname', 'year'])
    .merge(performance_df, on=['firmname', 'year'])
    ...
)

# Output
panel_df (123,456 rows × 42 columns)
# Unbalanced panel (각 firm마다 다른 연도 수)
```

#### Step 5: Parquet 저장
```python
# Input
panel_df (123,456 rows × 42 columns)
# Memory: ~500MB

# Process
panel_df.to_parquet(
    'imprinting_analysis_final.parquet',
    compression='snappy',
    engine='pyarrow'
)

# Output
File: imprinting_analysis_final.parquet
Size: ~85MB (83% 압축)
```

---

## 데이터 크기 예상

### 원본 데이터
| 파일 | Rows | Columns | Size (Excel) |
|------|------|---------|--------------|
| Round (19개) | 1,045,231 | 30 | ~800MB |
| Company (4개) | 102,451 | 25 | ~150MB |
| Firm (1개) | 28,932 | 20 | ~50MB |
| Fund (1개) | 47,823 | 15 | ~30MB |
| **Total** | - | - | **~1.0GB** |

### 중간 데이터 (Python)
| 데이터 | Rows | Columns | Memory |
|--------|------|---------|--------|
| Filtered Round | 623,847 | 30 | ~500MB |
| Centrality | 147,823 | 8 | ~10MB |
| Network Distance | 4,923,456 | 7 | ~250MB |
| Geographic Distance | 4,923,456 | 5 | ~180MB |
| Industry Distance | 4,923,456 | 5 | ~180MB |
| Performance | 147,823 | 10 | ~15MB |
| **Total** | - | - | **~1.1GB** |

### 최종 데이터 (Parquet)
| 파일 | Rows | Columns | Size |
|------|------|---------|------|
| CVC Analysis | 5,234,891 | 54 | ~450MB |
| Imprinting Analysis | 123,456 | 42 | ~85MB |
| Centrality | 147,823 | 8 | ~8MB |
| Network Distance | 4,923,456 | 7 | ~180MB |
| **Total** | - | - | **~720MB** |

**압축률**: 1.1GB → 720MB (약 35% 압축)

---

## 병목 지점 및 최적화 전략

### 1. 네트워크 구성 (가장 느림)
**문제**: 연도별 43번 반복, 각각 1-5분 소요
**해결**: 
- 병렬 처리 (8 cores) → 8배 속도 향상
- igraph Python 사용 → 2-3배 속도 향상
- **예상 시간**: 15-30분 → 5-7분

### 2. 중심성 계산
**문제**: 큰 네트워크에서 betweenness 계산 느림
**해결**:
- Approximate 알고리즘 사용
- 병렬 처리
- **예상 시간**: 10-20분 → 3-5분

### 3. 거리 계산
**문제**: O(n²) 복잡도, 메모리 많이 사용
**해결**:
- Chunking 처리
- Sparse matrix 사용
- **예상 시간**: 5-10분 → 2-3분

### 4. 샘플링
**문제**: 중첩 루프, 메모리 많이 사용
**해결**:
- 벡터화 연산
- Batch 처리
- **예상 시간**: 10-15분 → 3-5분

### 전체 예상 처리 시간
- **원본 R 코드**: 2-3시간
- **최적화된 Python**: **15-25분**
- **개선**: 약 **6-8배 속도 향상**

---

## 다음 단계

1. Python 모듈 구조 생성
2. 각 단계별 함수 구현
3. 단위 테스트
4. 전체 파이프라인 테스트
5. 성능 벤치마킹

