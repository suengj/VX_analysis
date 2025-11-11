# VC 네트워크 분석 핵심 알고리즘 추출

## 개요
이 문서는 `CVC_preprcs_v4.R`과 `imprinting_Dec18.R`의 핵심 알고리즘을 추출하여 Python 구현을 위한 상세한 로직을 문서화합니다.

---

## 1. 네트워크 구성 알고리즘

### 1.1 `VC_matrix()` - VC 네트워크 생성

**목적**: VC-Company 투자 관계를 VC-VC 공동투자 네트워크로 변환

**입력**:
- `round`: 투자 라운드 데이터 (firmname, event, year)
- `year`: 대상 연도
- `time_window`: 시간 윈도우 (기본값: 5년)
- `edge_cutpoint`: 최소 연결 강도 (옵션)

**알고리즘**:
```
1. 시간 필터링:
   IF time_window is NULL:
       edgelist = round[year == year-1]  # t-1만
   ELSE:
       edgelist = round[year-time_window <= year <= year-1]  # t-5 ~ t-1
   
2. 2-Mode 네트워크 생성:
   nodes = {firmname} ∪ {event}
   edges = {(firmname, event) for each investment}
   bipartite_graph = create_bipartite(nodes, edges)
   
3. 1-Mode 투영 (VC-VC 네트워크):
   vc_network = bipartite_projection(bipartite_graph, mode="vc")
   # 두 VC가 같은 event에 투자했으면 연결
   # edge weight = 공동 투자 횟수
   
4. Edge 필터링 (옵션):
   IF edge_cutpoint is not NULL:
       remove edges where weight < edge_cutpoint
   
5. 반환:
   return vc_network (igraph object)
```

**Python 구현 포인트**:
- `networkx.bipartite.projected_graph()` 사용
- 또는 `igraph` Python 라이브러리 사용 (속도 향상)
- edge weight 계산은 자동으로 처리됨
- 메모리 효율을 위해 sparse matrix 활용

**데이터 구조**:
```python
# 입력
edgelist = pd.DataFrame({
    'firmname': ['VC_A', 'VC_B', 'VC_A', 'VC_C'],
    'event': ['Event1', 'Event1', 'Event2', 'Event2'],
    'year': [1995, 1995, 1996, 1996]
})

# 출력
vc_network = nx.Graph()
# nodes: ['VC_A', 'VC_B', 'VC_C']
# edges: [('VC_A', 'VC_B', {'weight': 1}), 
#         ('VC_A', 'VC_C', {'weight': 1})]
```

---

### 1.2 `VC_centralities()` - 네트워크 중심성 계산

**목적**: VC 네트워크에서 각 노드의 중심성 지표 계산

**입력**:
- `round`: 투자 라운드 데이터
- `year`: 대상 연도
- `time_window`: 시간 윈도우
- `edge_cutpoint`: 최소 연결 강도

**계산 지표**:

#### a) Degree Centrality (연결 중심성)
```
degree(v) = number of edges connected to v
```

#### b) Betweenness Centrality (매개 중심성)
```
betweenness(v) = Σ(shortest_paths_through_v / total_shortest_paths)
```

#### c) Power Centrality (파워 중심성) - Bonacich Power Centrality

**Theoretical Foundation**:
- Bonacich (1987) power centrality measures actor status based on status of those deferring to them
- Status diffuses through social relations based on diffusion parameter β

**Calculation Formula**:
```
c = (I - βA)^(-1) A 1
where:
  I: Identity matrix
  A: Adjacency matrix
  β: Diffusion parameter (β = ρ × (1/λ_max))
  1: Column vector of ones
```

**Beta Parameter Selection**:
```
# 최대 고유값 계산
λ_max = max(eigenvalues(adjacency_matrix))
pwr_max = 1 / λ_max  # β의 상한값 (upper bound)

# β 값 계산: β = ρ × (1/λ_max)
beta_0 = 0 × (1/λ_max) = 0          # ρ = 0 (unweighted status)
beta_75 = 0.75 × (1/λ_max)         # ρ = 0.75 (weighted status, Podolny 2005)
beta_99 = 0.99 × (1/λ_max)         # ρ = 0.99 (high diffusion)
beta_max = (1 - 1e-10) × (1/λ_max) # ρ ≈ 1 (near maximum)
```

**Alpha Scaling (Optional)**:
- Bonacich (1987) suggests scaling constant α so that squared length of status vector equals n
- **Current Implementation**: α scaling is **omitted** (optional for cross-network comparison)
- Status values are normalized by maximum value instead

**Power Centrality Measures**:
- `pwr_max`: 1/λ_max (reference value, not a centrality measure)
- `pwr_p0`: Power centrality with β=0 (equivalent to degree centrality)
- `pwr_p75`: Power centrality with β=0.75×(1/λ_max) (primary robustness check)
- `pwr_p99`: Power centrality with β=0.99×(1/λ_max) (high diffusion sensitivity)

#### d) Constraint (구조적 제약)
```
constraint(v) = Σ(p_vq + Σ(p_vj * p_jq))^2
where p_vq = proportion of v's connections to q
```

**알고리즘**:
```
1. 네트워크 생성:
   network = VC_matrix(round, year, time_window, edge_cutpoint)

2. 고유값 계산 (Power Centrality용):
   adjacency_matrix = to_adjacency_matrix(network)
   eigenvalues = compute_eigenvalues(adjacency_matrix)
   lambda_max = max(eigenvalues)  # 최대 고유값
   pwr_max = 1 / lambda_max        # β의 상한값

3. 중심성 계산:
   degree_cent = compute_degree(network)
   betweenness_cent = compute_betweenness(network)
   
   # Power centrality (Bonacich power centrality)
   # β = ρ × (1/λ_max) where ρ ∈ [0, 1)
   power_p0 = compute_power_centrality(network, beta=0)                    # ρ = 0
   power_p75 = compute_power_centrality(network, beta=0.75 * pwr_max)    # ρ = 0.75
   power_p99 = compute_power_centrality(network, beta=0.99 * pwr_max)    # ρ = 0.99
   # Note: pwr_max is stored as reference value (1/λ_max), not a centrality measure
   
   constraint = compute_constraint(network)
   sh = compute_structural_holes(network)  # Burt effective size

4. 결과 병합:
   result = DataFrame({
       'firmname': node_names,
       'year': year,
       'dgr_cent': degree_cent,
       'btw_cent': betweenness_cent,
       'pwr_max': pwr_max,        # Reference value (1/λ_max), not a centrality measure
       'pwr_p0': power_p0,        # β = 0 (equivalent to degree centrality)
       'pwr_p75': power_p75,      # β = 0.75 × (1/λ_max)
       'pwr_p99': power_p99,      # β = 0.99 × (1/λ_max)
       'constraint_value': constraint,
       'sh': sh                   # Burt structural holes (effective size)
   })

5. 반환:
   return result
```

**Python 구현 포인트**:
- `networkx.degree_centrality()`, `betweenness_centrality()` 사용
- Power centrality는 직접 구현 필요 (또는 `igraph` 사용)
- 병렬 처리 가능: `joblib.Parallel()` 활용
- 큰 네트워크는 approximate 알고리즘 사용

---

## 2. 샘플링 알고리즘

### 2.1 `leadVC_identifier()` - LeadVC 식별

**목적**: 각 투자 라운드에서 LeadVC 식별

**입력**:
- `data`: 투자 라운드 데이터 (firmname, comname, year, RoundNumber, RoundAmount)

**판단 기준** (우선순위):
1. **FirstRound**: 최초 라운드 투자자
2. **firm_inv_ratio**: 회사별 투자 비율이 가장 높은 VC
3. **TotalAmountPerCompany**: 총 투자 금액이 가장 큰 VC

**알고리즘**:
```
1. 데이터 전처리:
   # 회사별 총 투자자 수
   data['comInvested'] = data.groupby('comname')['firmname'].transform('count')
   
   # 최초 라운드 식별
   data['FirstRound'] = (data['RoundNumber'] == data.groupby('comname')['RoundNumber'].transform('min'))
   
   # 회사별 VC 투자 횟수
   data['firm_comInvested'] = data.groupby(['firmname', 'comname']).size()
   data['firm_inv_ratio'] = data['firm_comInvested'] / data['comInvested']
   
   # 투자 금액
   data['RoundAmount'] = np.maximum(data['RoundAmountDisclosedThou'], 
                                    data['RoundAmountEstimatedThou'])
   data['TotalAmountPerCompany'] = data.groupby(['firmname', 'comname'])['RoundAmount'].transform('sum')

2. LeadVC 점수 계산:
   data['leadVC1'] = (data['FirstRound'] == 1).astype(int)
   data['leadVC2'] = (data['firm_inv_ratio'] == data.groupby('comname')['firm_inv_ratio'].transform('max')).astype(int)
   data['leadVC3'] = (data['TotalAmountPerCompany'] == data.groupby('comname')['TotalAmountPerCompany'].transform('max')).astype(int)
   
   data['leadVCsum'] = data['leadVC1'] + data['leadVC2'] + data['leadVC3']

3. LeadVC 결정 (조건문):
   def identify_leadvc(group):
       # Case 1: FirstRound 투자자가 1명
       if (group['leadVC1'] == 1).sum() == 1 and (group['leadVC1'] == 1).any():
           return group[group['leadVC1'] == 1].index[0]
       
       # Case 2: FirstRound + 투자 비율 최고가 1명
       if ((group['leadVC1'] == 1) & (group['leadVC2'] == 1)).sum() == 1:
           return group[(group['leadVC1'] == 1) & (group['leadVC2'] == 1)].index[0]
       
       # Case 3: FirstRound + 투자 비율 + 금액 최고가 1명
       if ((group['leadVC1'] == 1) & (group['leadVC2'] == 1) & (group['leadVC3'] == 1)).sum() == 1:
           return group[(group['leadVC1'] == 1) & (group['leadVC2'] == 1) & (group['leadVC3'] == 1)].index[0]
       
       # Case 4: leadVCsum이 최대인 FirstRound 투자자 중 랜덤 선택
       max_sum = group[group['leadVC1'] == 1]['leadVCsum'].max()
       candidates = group[(group['leadVC1'] == 1) & (group['leadVCsum'] == max_sum)]
       return candidates.sample(n=1, random_state=123).index[0]
   
   leadVC_list = data.groupby('comname').apply(identify_leadvc)

4. 반환:
   return leadVC_list (firmname, comname, leadVC=1)
```

**Python 구현 포인트**:
- `groupby().transform()` 활용하여 벡터화
- `random_state=123` 설정으로 재현성 보장
- 메모리 효율을 위해 categorical dtype 활용

---

### 2.2 `VC_sampling_opt1()` - 1:n Case-Control 샘플링

**목적**: LeadVC-PartnerVC 관계에서 실현된 tie와 미실현 tie를 1:n 비율로 샘플링

**입력**:
- `v_dta`: 실현된 투자 데이터 (leadVC, coVC, comname, realized)
- `v_coVC_unique`: 잠재적 파트너 VC 리스트
- `ratio`: 샘플링 비율 (기본값: 10)

**알고리즘**:
```
1. 잠재적 파트너 리스트 생성:
   all_ties = pd.DataFrame({
       'coVC': v_coVC_unique,
       'leadVC': v_dta['leadVC'].iloc[0],  # 동일한 leadVC
       'comname': v_dta['comname'].iloc[0]  # 동일한 comname
   })
   
   # realized 정보 병합
   all_ties = all_ties.merge(
       v_dta[['coVC', 'realized']], 
       on='coVC', 
       how='left'
   )
   all_ties['realized'] = all_ties['realized'].fillna(0)
   
   # leadVC를 coVC로 선택하는 경우 제외
   all_ties = all_ties[all_ties['coVC'] != all_ties['leadVC']]

2. Realized/Unrealized 분리:
   realized_ties = all_ties[all_ties['realized'] == 1]
   unrealized_ties = all_ties[all_ties['realized'] == 0]

3. 샘플링:
   n_realized = len(realized_ties)
   n_sample = ratio * n_realized
   
   if n_sample >= len(unrealized_ties):
       # 복원 추출 (replacement)
       unrealized_sample = unrealized_ties.sample(
           n=n_sample, 
           replace=True, 
           random_state=123
       )
   else:
       # 비복원 추출
       unrealized_sample = unrealized_ties.sample(
           n=n_sample, 
           random_state=123
       )

4. 결합 및 반환:
   sampled_data = pd.concat([realized_ties, unrealized_sample])
   return sampled_data
```

**Python 구현 포인트**:
- `pd.sample()` 사용하여 효율적 샘플링
- `random_state=123` 설정으로 재현성 보장
- 벡터화 연산으로 속도 최적화
- 메모리 효율을 위해 한 번에 하나의 leadVC-company 조합만 처리

---

## 3. 거리 계산 알고리즘

### 3.1 Blau Index (산업 다양성)

**목적**: VC의 투자 포트폴리오 산업 다양성 측정

**입력**:
- `b_df`: 산업별 투자 횟수 (firmname, year, industry1, industry2, ...)

**수식**:
```
Blau Index = 1 - Σ(p_i^2)
where p_i = proportion of investments in industry i
```

**알고리즘**:
```
1. 총 투자 횟수 계산:
   b_df['sum'] = b_df.iloc[:, 2:].sum(axis=1)

2. 비율 계산:
   b_df.iloc[:, 2:] = b_df.iloc[:, 2:].div(b_df['sum'], axis=0)

3. 제곱 계산:
   b_df.iloc[:, 2:] = b_df.iloc[:, 2:] ** 2

4. Blau 지수 계산:
   b_df['blau'] = 1 - b_df.iloc[:, 2:-1].sum(axis=1)

5. 결과 반환:
   return b_df[['firmname', 'year', 'blau', 'TotalInvest']]
```

**Python 구현 포인트**:
- 완전 벡터화 가능
- `pandas` 연산으로 매우 빠름
- 메모리 효율적

---

### 3.2 네트워크 거리

**목적**: VC 간 네트워크 최단 경로 계산

**알고리즘**:
```
1. 네트워크 생성:
   network = VC_matrix(round, year, time_window, edge_cutpoint)

2. 최단 경로 계산:
   distance_matrix = compute_shortest_paths(network)
   # Floyd-Warshall 또는 Dijkstra 알고리즘

3. 거리 범주화:
   geoDist1 = (distance_matrix == 1).astype(int)
   geoDist2 = (distance_matrix == 2).astype(int)
   geoDist3 = (distance_matrix > 2).astype(int)
   
   # Infinite distance (연결 안 됨) → 9999
   distance_matrix[np.isinf(distance_matrix)] = 9999

4. 데이터프레임 변환:
   result = pd.DataFrame({
       'VC1': vc1_list,
       'VC2': vc2_list,
       'year': year,
       'geoDist': distance_list,
       'geoDist1': geodist1_list,
       'geoDist2': geodist2_list,
       'geoDist3': geodist3_list
   })

5. 반환:
   return result
```

**Python 구현 포인트**:
- `networkx.shortest_path_length()` 사용
- 병렬 처리 가능
- sparse matrix로 메모리 효율화

---

### 3.3 지리적 거리 (우편번호 기반)

**목적**: VC 간, VC-Company 간 지리적 거리 계산

**알고리즘**:
```
1. 우편번호 → 위경도 변환:
   # zipcodeR 패키지 또는 geopy 사용
   zipcode_db = load_zipcode_database()
   
   data = data.merge(
       zipcode_db[['zipcode', 'lat', 'lng']], 
       left_on='firmzip', 
       right_on='zipcode'
   )

2. Haversine 거리 계산:
   def haversine_distance(lat1, lon1, lat2, lon2):
       R = 6371  # Earth radius in km
       
       dlat = radians(lat2 - lat1)
       dlon = radians(lon2 - lon1)
       
       a = sin(dlat/2)**2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon/2)**2
       c = 2 * atan2(sqrt(a), sqrt(1-a))
       
       return R * c

3. 벡터화 계산:
   distance = haversine_distance(
       data['lat1'], data['lng1'],
       data['lat2'], data['lng2']
   )

4. 반환:
   return distance
```

**Python 구현 포인트**:
- `geopy` 또는 `zipcodeR` 파이썬 버전 사용
- numpy 벡터화로 속도 향상
- 또는 `uszipcode` 라이브러리 활용

---

## 4. Imprinting 분석 알고리즘

### 4.1 `VC_initial_ties()` - 초기 네트워크 관계 식별

**목적**: VC의 첫 투자 라운드에서 형성된 파트너십 관계 식별

**입력**:
- `edge_raw`: 투자 엣지 데이터 (firmname, event, year)
- `y`: 시작 연도
- `time_window`: 초기 기간 (기본값: 1년)

**알고리즘**:
```
1. 시간 필터링:
   if time_window is not None:
       edge_df = edge_raw[(edge_raw['year'] >= y) & 
                          (edge_raw['year'] < y + time_window)]
   else:
       edge_df = edge_raw[edge_raw['year'] == y]

2. 연도별 반복:
   initial_ties_list = []
   
   for year in edge_df['year'].unique():
       year_data = edge_df[edge_df['year'] == year]
       
       # 2-mode 네트워크 생성
       bipartite = create_bipartite_network(
           year_data[['firmname', 'event']]
       )
       
       # VC-VC 투영
       vc_network = bipartite_projection(bipartite, mode='vc')
       
       # 엣지 추출
       edges = get_edges(vc_network)
       edges['tied_year'] = year
       
       # 양방향 엣지 생성
       edges_reverse = edges.copy()
       edges_reverse.columns = ['V2', 'V1', 'tied_year']
       
       all_edges = pd.concat([edges, edges_reverse])
       initial_ties_list.append(all_edges)

3. 결합 및 컬럼명 변경:
   initial_ties = pd.concat(initial_ties_list)
   initial_ties.columns = ['firmname', 'initial_partner', 'tied_year']

4. 반환:
   return initial_ties
```

**Python 구현 포인트**:
- `networkx` 사용하여 bipartite projection
- 벡터화 연산으로 속도 향상
- 양방향 엣지 생성 주의

---

### 4.2 `VC_initial_period()` - Imprinting 기간 필터링

**목적**: Imprinting 기간 내의 네트워크 관계만 필터링

**입력**:
- `df`: 초기 관계 데이터 (firmname, initial_partner, tied_year, initial_year)
- `period`: Imprinting 기간

**알고리즘**:
```
1. 기간 체크:
   df['check'] = df['tied_year'] - df['initial_year']
   df = df[df['check'] < period]

2. 정리:
   df = df.drop('check', axis=1)

3. 반환:
   return df
```

**Python 구현 포인트**:
- 간단한 벡터화 필터링
- 매우 빠름

---

## 5. 성능 최적화 포인트

### 5.1 벡터화 연산
```python
# Bad: Loop
for i in range(len(df)):
    df.loc[i, 'result'] = df.loc[i, 'a'] + df.loc[i, 'b']

# Good: Vectorized
df['result'] = df['a'] + df['b']
```

### 5.2 병렬 처리
```python
from joblib import Parallel, delayed

# 네트워크 중심성 계산 병렬화
def compute_centrality_for_year(year):
    network = VC_matrix(round_data, year, 5, None)
    return VC_centralities(network, year)

results = Parallel(n_jobs=-1)(
    delayed(compute_centrality_for_year)(year) 
    for year in years
)
```

### 5.3 메모리 최적화
```python
# dtype 최적화
df['year'] = df['year'].astype('int16')
df['firmname'] = df['firmname'].astype('category')

# chunking
for chunk in pd.read_csv('large_file.csv', chunksize=10000):
    process(chunk)
```

### 5.4 캐싱
```python
from functools import lru_cache

@lru_cache(maxsize=100)
def compute_network(year, time_window):
    return VC_matrix(round_data, year, time_window, None)
```

---

## 6. 데이터 구조 요약

### 입력 데이터
```python
# Company data
company_df = pd.DataFrame({
    'comname': str,
    'comsitu': str,  # 'Went Public', 'Merger', 'Acquisition'
    'date_sit': datetime,
    'date_ipo': datetime,
    'comindmnr': str,  # 산업 분류
    'comnation': str,
    'comzip': str
})

# Firm data
firm_df = pd.DataFrame({
    'firmname': str,
    'firmfounding': datetime,
    'firmtype': str,  # 'CVC', 'IVC', 'Angel', ...
    'firmnation': str,
    'firmzip': str
})

# Round data
round_df = pd.DataFrame({
    'firmname': str,
    'comname': str,
    'rnddate': datetime,
    'year': int,
    'RoundNumber': int,
    'RoundAmountDisclosedThou': float,
    'RoundAmountEstimatedThou': float,
    'CompanyStageLevel1': str
})
```

### 중간 데이터
```python
# Network centrality
centrality_df = pd.DataFrame({
    'firmname': str,
    'year': int,
    'dgr_cent': float,
    'btw_cent': float,
    'pwr_p75': float,
    'pwr_max': float,
    'pwr_zero': float,
    'constraint_value': float,
    'sh': float
})

# Sampled data
sampled_df = pd.DataFrame({
    'leadVC': str,
    'coVC': str,
    'comname': str,
    'quarter': str,
    'realized': int  # 0 or 1
})
```

### 최종 출력 데이터
```python
# CVC analysis
cvc_final_df = pd.DataFrame({
    'leadVC': str,
    'coVC': str,
    'comname': str,
    'year': int,
    'quarter': str,
    'realized': int,
    
    # Network variables
    'leadVC_dgr': float,
    'coVC_dgr': float,
    'geoDist1': int,
    'geoDist2': int,
    'geoDist3': int,
    
    # Distance variables
    'VC_zipdist': float,
    'indDist': float,
    'coVC_blau': float,
    
    # Performance variables
    'coVC_exitNum': int,
    'coVC_AmtInv': float,
    
    # Control variables
    'coVC_age': int,
    'coVC_totalInv': int,
    ...
})

# Imprinting analysis
imprinting_final_df = pd.DataFrame({
    'firmname': str,
    'year': int,
    'timesince': int,  # years since initial investment
    
    # Current network
    'dgr_1y': float,
    'btw_1y': float,
    'pwr_max_5y': float,
    'cons_value_1y': float,
    
    # Initial partner characteristics
    'p_dgr_1y': float,
    'p_btw_1y': float,
    'p_pwr_max_5y': float,
    
    # Initial focal characteristics
    'f_dgr_1y': float,
    'f_cons_value_1y': float,
    
    # Performance
    'NumExit': int,
    'InvestAMT': float,
    'blau': float,
    ...
})
```

---

## 다음 단계

이 알고리즘 문서를 기반으로:
1. Python 모듈 구조 설계
2. 각 함수 구현
3. 단위 테스트 작성
4. 성능 벤치마킹
5. R 원본과 결과 비교 검증

