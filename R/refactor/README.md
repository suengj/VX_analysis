# VC Network Analysis Refactored Code

## 개요
기존 `CVC_preprcs_v4.R`과 `imprinting_Dec18.R` 파일의 함수들을 모듈화하여 재사용 가능한 함수 라이브러리로 리팩토링했습니다.

## 핵심 원칙
- **기존 로직 보존**: 검증된 코드의 로직을 그대로 유지
- **모듈화**: 중복 함수들을 통합하고 재사용 가능하게 구성
- **설정 분리**: 하드코딩된 값들을 설정 파일로 분리
- **안전성**: 기존 결과와 동일한 결과를 보장

## 폴더 구조

```
refactor/
├── R/
│   ├── config/           # 설정 파일들
│   │   ├── parameters.R  # 분석 파라미터
│   │   ├── constants.R   # 상수값들
│   │   └── paths.R       # 파일 경로들
│   ├── core/             # 핵심 함수들
│   │   ├── network_construction.R    # 네트워크 구성
│   │   ├── centrality_calculation.R  # 중심성 계산
│   │   ├── sampling.R                # 샘플링 함수
│   │   └── data_processing.R         # 데이터 처리
│   ├── analysis/         # 분석 함수들
│   │   ├── diversity_analysis.R      # 다양성 분석
│   │   ├── imprinting_analysis.R     # 임프린팅 분석
│   │   ├── performance_analysis.R    # 성과 분석
│   │   └── regression_analysis.R     # 회귀 분석
│   └── utils/            # 유틸리티 함수들
│       └── validation.R  # 데이터 검증
├── examples/             # 예제 스크립트들
│   ├── cvc_analysis_example.R        # CVC 분석 예제
│   ├── imprinting_analysis_example.R # 임프린팅 분석 예제
│   ├── performance_analysis_example.R # 성과 분석 예제
│   └── regression_analysis_example.R # 회귀 분석 예제
├── load_all_modules.R    # 통합 로더
├── test_refactored_functions.R  # 테스트 스크립트
├── README.md             # 기본 사용법
└── USAGE_GUIDE.md        # 상세 사용법 가이드
```

## 주요 함수들

### 네트워크 구성 (network_construction.R)
- `VC_matrix()`: VC 네트워크 매트릭스 생성 (기존 로직 그대로)
- `create_bipartite_network()`: 이분 네트워크 생성
- `project_network()`: 이분 네트워크를 일분 네트워크로 투영

### 중심성 계산 (centrality_calculation.R)
- `VC_centralities()`: 종합 중심성 측정 계산 (기존 로직 그대로)
- `calculate_power_centrality()`: 파워 중심성 계산
- `calculate_ego_density()`: 이고 네트워크 밀도 계산
- `calculate_constraint()`: 구조적 홀 제약 계산

### 샘플링 (sampling.R)
- `VC_sampling_opt1()`: 케이스-컨트롤 샘플링 (기존 로직 그대로)
- `VC_sampling_opt1_output()`: 샘플링 출력 함수 (기존 로직 그대로)
- `create_case_control_dataset()`: 다중 기간 케이스-컨트롤 데이터셋 생성

### 데이터 처리 (data_processing.R)
- `date_unique_identifier()`: 고유 날짜 식별자 추출 (기존 로직 그대로)
- `leadVC_identifier()`: 리드 VC 식별 (기존 로직 그대로)
- `create_event_identifiers()`: 투자 라운드 이벤트 식별자 생성
- `filter_investment_data()`: 투자 데이터 필터링
- `calculate_investment_stats()`: 투자 통계 계산

### 다양성 분석 (diversity_analysis.R)
- `blau_index()`: Blau 지수 계산 (기존 로직 그대로)
- `calculate_industry_proportion()`: 산업 비율 계산
- `calculate_portfolio_diversity()`: 포트폴리오 다양성 측정
- `calculate_geographic_diversity()`: 지리적 다양성 측정
- `calculate_stage_diversity()`: 단계별 다양성 측정

### 임프린팅 분석 (imprinting_analysis.R)
- `VC_initial_ties()`: 초기 네트워크 연결 식별 (기존 로직 그대로)
- `VC_initial_period()`: 임프린팅 기간 필터링 (기존 로직 그대로)
- `VC_initial_focal_centrality()`: 초점 기업 중심성 계산 (기존 로직 그대로)
- `VC_initial_partner_centrality()`: 초기 파트너 중심성 계산 (기존 로직 그대로)
- `create_imprinting_dataset()`: 임프린팅 분석 데이터셋 생성
- `calculate_imprinting_effects()`: 임프린팅 효과 측정

### 성과 분석 (performance_analysis.R)
- `VC_exit_num()`: VC 출구 수 계산 (기존 로직 그대로)
- `VC_IPO_num()`: VC IPO 수 계산 (기존 로직 그대로)
- `VC_MnA_num()`: VC M&A 수 계산 (기존 로직 그대로)
- `create_exit_data()`: 출구 데이터 생성
- `calculate_performance_metrics()`: 성과 지표 계산
- `welch_t_test()`: Welch's t-test (기존 로직 그대로)
- `calculate_performance_summary()`: 성과 요약 통계

### 회귀 분석 (regression_analysis.R)
- `create_panel_data()`: 패널 데이터 생성
- `run_imprinting_regression()`: 임프린팅 효과 회귀 분석
- `run_cvc_regression()`: CVC 파트너십 회귀 분석
- `calculate_vif()`: VIF 계산
- `run_model_comparison()`: 모델 비교
- `extract_model_results()`: 모델 결과 추출
- `create_regression_formula()`: 회귀 공식 생성
- `run_robustness_checks()`: 견고성 검사

### 설정 파일들
- `parameters.R`: 네트워크, 샘플링, 분석 파라미터
- `constants.R`: 산업 분류, VC 타입, 지리적 상수
- `paths.R`: 데이터 및 결과 파일 경로

## 사용 방법

### 1. 빠른 시작
```r
# 모든 모듈 로드
source("load_all_modules.R")
modules <- load_vc_modules()

# 또는 완전한 설정
modules <- quick_setup()
```

### 2. 선택적 모듈 로드
```r
# 특정 모듈 그룹만 로드
load_module_group("config")    # 설정만
load_module_group("core")      # 핵심 함수만
load_module_group("analysis")  # 분석 함수만
load_module_group("utils")     # 유틸리티만

# 특정 분석 모듈만 로드
load_analysis_module("diversity")     # 다양성 분석만
load_analysis_module("imprinting")    # 임프린팅 분석만
load_analysis_module("performance")   # 성과 분석만
load_analysis_module("regression")    # 회귀 분석만
```

### 3. 기본 사용법
```r
# 네트워크 생성
network <- VC_matrix(round_data, 1995, time_window = 5)

# 중심성 계산
centralities <- VC_centralities(round_data, 1995, 5, NULL)

# 샘플링
sampled_data <- VC_sampling_opt1_output(round_data, leadVC_data, "quarter", 10, "1995Q1")

# 다양성 분석
diversity <- blau_index(industry_data)

# 임프린팅 분석
initial_ties <- VC_initial_ties(edge_data, 1990, time_window = 3)
imprinting_dataset <- create_imprinting_dataset(edge_data, centrality_data, initial_year_data)

# 성과 분석
exit_data <- create_exit_data(company_data)
performance <- calculate_performance_metrics(round_data, company_data, 1990:2000)

# 회귀 분석
panel_data <- create_panel_data(analysis_data)
model <- run_imprinting_regression(panel_data, "H1")
```

### 4. 예제 스크립트 실행
```r
# CVC 분석 전체 워크플로우
source("examples/cvc_analysis_example.R")

# 임프린팅 분석 전체 워크플로우
source("examples/imprinting_analysis_example.R")

# 성과 분석 전체 워크플로우
source("examples/performance_analysis_example.R")

# 회귀 분석 전체 워크플로우
source("examples/regression_analysis_example.R")
```

### 5. 테스트 실행
```r
source("test_refactored_functions.R")
```

## 예제 스크립트

### CVC 분석 예제 (`examples/cvc_analysis_example.R`)
- **목적**: CVC 파트너십 분석의 완전한 워크플로우
- **주요 단계**: 데이터 로드 → 네트워크 분석 → 샘플링 → 다양성 분석 → 성과 분석 → CVC 특화 분석 → 회귀 분석
- **출력**: 중심성, 다양성, 성과, 회귀 모델 결과

### 임프린팅 분석 예제 (`examples/imprinting_analysis_example.R`)
- **목적**: 네트워크 임프린팅 효과 분석의 완전한 워크플로우
- **주요 단계**: 초기 연도 식별 → 네트워크 중심성 → 초기 연결 → 임프린팅 필터링 → 파트너/포커스 중심성 → 회귀 분석 → 견고성 검사
- **출력**: 임프린팅 데이터셋, 회귀 모델, 견고성 검사 결과

### 성과 분석 예제 (`examples/performance_analysis_example.R`)
- **목적**: VC 성과 분석의 완전한 워크플로우
- **주요 단계**: 출구 데이터 생성 → 성과 지표 → 투자 데이터 → 네트워크 분석 → 다양성 분석 → VC 타입별 분석 → 통계 검정 → 시계열 분석
- **출력**: 성과 지표, 통계 검정, 시계열 트렌드

### 회귀 분석 예제 (`examples/regression_analysis_example.R`)
- **목적**: 종합 회귀 분석의 완전한 워크플로우
- **주요 단계**: 데이터 통합 → 임프린팅 회귀 → CVC 회귀 → 모델 비교 → VIF 분석 → 견고성 검사 → 결과 추출
- **출력**: 회귀 모델, 모델 비교, 진단 결과

## 기존 코드와의 호환성

### 동일한 결과 보장
- `VC_matrix()`: 기존 함수와 동일한 로직
- `VC_centralities()`: 기존 함수와 동일한 로직
- `VC_sampling_opt1()`: 기존 함수와 동일한 로직
- `VC_sampling_opt1_output()`: 기존 함수와 동일한 로직
- `date_unique_identifier()`: 기존 함수와 동일한 로직
- `leadVC_identifier()`: 기존 함수와 동일한 로직
- `blau_index()`: 기존 함수와 동일한 로직
- `VC_initial_ties()`: 기존 함수와 동일한 로직
- `VC_initial_period()`: 기존 함수와 동일한 로직
- `VC_initial_focal_centrality()`: 기존 함수와 동일한 로직
- `VC_initial_partner_centrality()`: 기존 함수와 동일한 로직
- `VC_exit_num()`: 기존 함수와 동일한 로직
- `VC_IPO_num()`: 기존 함수와 동일한 로직
- `VC_MnA_num()`: 기존 함수와 동일한 로직
- `welch_t_test()`: 기존 함수와 동일한 로직
- igraph 중심성 계산 부분은 원본 그대로 유지

### 주요 차이점
- 설정값들이 외부 파일로 분리됨
- 함수들이 모듈별로 분리됨
- 검증 함수들이 추가됨
- 통합 로더 함수 제공
- 새로운 분석 함수들 추가
- 완전한 예제 스크립트 제공
- 상세한 사용법 문서 제공

## 완료된 모듈

### ✅ Phase 1: 기본 모듈화
- 설정 파일들 (parameters.R, constants.R, paths.R)
- 네트워크 구성 함수 (network_construction.R)
- 중심성 계산 함수 (centrality_calculation.R)
- 기본 유틸리티 (validation.R)

### ✅ Phase 2: 확장 모듈화
- 샘플링 함수 (sampling.R)
- 데이터 처리 함수 (data_processing.R)
- 다양성 분석 함수 (diversity_analysis.R)
- 통합 로더 (load_all_modules.R)

### ✅ Phase 3: 고급 분석 모듈화
- 임프린팅 분석 함수 (imprinting_analysis.R)
- 성과 분석 함수 (performance_analysis.R)
- 회귀 분석 함수 (regression_analysis.R)
- 업데이트된 로더 및 테스트

### ✅ Phase 4: 예제 스크립트 및 문서화
- CVC 분석 예제 스크립트 (cvc_analysis_example.R)
- 임프린팅 분석 예제 스크립트 (imprinting_analysis_example.R)
- 성과 분석 예제 스크립트 (performance_analysis_example.R)
- 회귀 분석 예제 스크립트 (regression_analysis_example.R)
- 상세한 사용법 가이드 (USAGE_GUIDE.md)
- 완전한 문서화

## 사용 가능한 함수들

- **Core functions**: 14개 (네트워크, 중심성, 샘플링, 데이터 처리)
- **Analysis functions**: 25개 (다양성, 임프린팅, 성과, 회귀 분석)
- **Utility functions**: 4개 (검증 함수)
- **Example scripts**: 4개 (완전한 워크플로우)
- **Documentation**: 2개 (기본 및 상세 가이드)

## 주의사항

1. **igraph 패키지**: 네트워크 중심성 계산에 필수
2. **기존 로직 보존**: 검증된 코드의 로직을 그대로 유지
3. **설정 파일**: 분석 전에 설정 파일들을 먼저 로드
4. **테스트**: 새로운 분석 전에 테스트 스크립트 실행 권장
5. **모듈 로더**: `load_all_modules.R`을 사용하여 모든 모듈을 한 번에 로드
6. **패키지 의존성**: plm, pglm, lme4, car 패키지 필요
7. **예제 스크립트**: 완전한 워크플로우를 보려면 examples 폴더 참조
8. **상세 가이드**: 고급 사용법은 USAGE_GUIDE.md 참조

## 문제 해결

### 일반적인 오류
1. **패키지 누락**: `quick_setup()` 실행
2. **경로 오류**: `paths.R`에서 경로 확인
3. **데이터 형식**: `validation.R`의 검증 함수 사용
4. **모듈 로드 오류**: `load_all_modules.R` 사용
5. **회귀 분석 오류**: 패키지 설치 확인 (plm, pglm, lme4, car)
6. **예제 실행 오류**: 데이터 파일 경로 확인
7. **메모리 부족**: 병렬 처리 코어 수 조정

### 지원
기존 코드의 로직을 그대로 유지하면서 모듈화했으므로, 기존 분석 결과와 동일한 결과를 얻을 수 있습니다.

## 추가 리소스

- **USAGE_GUIDE.md**: 상세한 사용법 가이드
- **examples/**: 완전한 워크플로우 예제 스크립트
- **test_refactored_functions.R**: 함수별 테스트 스크립트
- **R/config/**: 설정 파일들
- **R/core/**: 핵심 함수들
- **R/analysis/**: 분석 함수들
- **R/utils/**: 유틸리티 함수들 