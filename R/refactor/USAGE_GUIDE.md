# VC Network Analysis - 상세 사용법 가이드

## 목차
1. [시작하기](#시작하기)
2. [기본 사용법](#기본-사용법)
3. [고급 분석](#고급-분석)
4. [예제 스크립트](#예제-스크립트)
5. [문제 해결](#문제-해결)
6. [참고 자료](#참고-자료)

## 시작하기

### 1.1 필수 패키지 설치

```r
# 필수 패키지들
required_packages <- c(
  "igraph",      # 네트워크 분석
  "tidyverse",   # 데이터 처리
  "data.table",  # 빠른 데이터 처리
  "plm",         # 패널 데이터 분석
  "pglm",        # 패널 일반화 선형 모델
  "lme4",        # 혼합 효과 모델
  "car",         # 회귀 진단
  "parallel",    # 병렬 처리
  "foreach",     # 반복문 병렬화
  "progress"     # 진행률 표시
)

# 패키지 설치 및 로드
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}
```

### 1.2 모듈 로드

```r
# 모든 모듈 로드
source("load_all_modules.R")
modules <- load_vc_modules()

# 또는 완전한 설정
modules <- quick_setup()
```

### 1.3 데이터 준비

```r
# 데이터 파일 구조
# - comdta_new.csv: 회사 정보 (comname, comsitu, date_sit, date_ipo, comindmnr, comnation)
# - firmdta_all.xlsx: VC 정보 (firmname, firmfounding, firmtype, firmnation)
# - round_Mar25.csv: 투자 라운드 정보 (firmname, comname, rnddate, rndamt)

# 데이터 로드 예시
comdta <- read.csv('comdta_new.csv') %>% as_tibble()
firmdta <- read_excel('firmdta_all.xlsx') %>% as_tibble()
round <- read.csv("round_Mar25.csv", header = TRUE)
```

## 기본 사용법

### 2.1 네트워크 구성 및 중심성 계산

```r
# 기본 네트워크 구성
network <- VC_matrix(round_data, 1995, time_window = 5, edge_cutpoint = NULL)

# 중심성 계산
centralities <- VC_centralities(round_data, 1995, time_window = 5, edge_cutpoint = NULL)

# 결과 확인
print(head(centralities))
```

### 2.2 샘플링 분석

```r
# 케이스-컨트롤 샘플링
sampled_data <- VC_sampling_opt1_output(
  round_data, 
  leadVC_data, 
  "quarter", 
  ratio = 10, 
  target_quarter = "1995Q1"
)

# 결과 확인
print(nrow(sampled_data))
```

### 2.3 다양성 분석

```r
# Blau 지수 계산
diversity_data <- blau_index(industry_data)

# 포트폴리오 다양성 계산
portfolio_diversity <- calculate_portfolio_diversity(industry_data)

# 결과 확인
print(head(diversity_data))
```

### 2.4 성과 분석

```r
# 출구 데이터 생성
exit_data <- create_exit_data(company_data)

# 성과 지표 계산
performance_data <- calculate_performance_metrics(
  round_data, 
  company_data, 
  years = 1990:2000, 
  time_window = 5
)

# 결과 확인
print(head(performance_data))
```

## 고급 분석

### 3.1 임프린팅 분석

```r
# 초기 연결 식별
initial_ties <- VC_initial_ties(edge_data, 1990, time_window = 3)

# 임프린팅 기간 필터링
initial_partner_list <- VC_initial_period(initial_ties, period = 3)

# 파트너 중심성 계산
partner_centrality <- VC_initial_partner_centrality(initial_partner_list, centrality_data)

# 포커스 기업 중심성 계산
focal_centrality <- VC_initial_focal_centrality(initial_partner_list, centrality_data)

# 통합 임프린팅 데이터셋 생성
imprinting_dataset <- create_imprinting_dataset(
  edge_data, 
  centrality_data, 
  initial_year_data, 
  imprinting_period = 3, 
  time_windows = c(1, 3, 5)
)
```

### 3.2 회귀 분석

```r
# 패널 데이터 생성
panel_data <- create_panel_data(regression_data)

# 임프린팅 회귀 분석
model_H0 <- run_imprinting_regression(panel_data, "H0")
model_H1 <- run_imprinting_regression(panel_data, "H1")
model_H2 <- run_imprinting_regression(panel_data, "H2")

# CVC 회귀 분석
cvc_base <- run_cvc_regression(data, "realized", "base")
cvc_network <- run_cvc_regression(data, "realized", "network")
cvc_specific <- run_cvc_regression(data, "realized", "cvc")

# VIF 분석
vif_values <- calculate_vif(model_H1)

# 모델 비교
model_comparison <- run_model_comparison(data, model_specs)
```

### 3.3 통계적 검정

```r
# Welch's t-test
t_result <- welch_t_test(data, group_variable, "test_variable")

# 성과 요약 통계
performance_summary <- calculate_performance_summary(performance_data, group_variable)
```

## 예제 스크립트

### 4.1 CVC 분석 예제

```r
# CVC 분석 전체 워크플로우
source("examples/cvc_analysis_example.R")

# 주요 단계:
# 1. 데이터 로드 및 전처리
# 2. 네트워크 구성 및 중심성 계산
# 3. 샘플링 및 데이터 처리
# 4. 다양성 분석
# 5. 성과 분석
# 6. CVC 특화 분석
# 7. 회귀 분석
# 8. 결과 저장
```

### 4.2 임프린팅 분석 예제

```r
# 임프린팅 분석 전체 워크플로우
source("examples/imprinting_analysis_example.R")

# 주요 단계:
# 1. 데이터 로드 및 전처리
# 2. 초기 연도 식별
# 3. 네트워크 중심성 계산
# 4. 초기 연결 식별
# 5. 임프린팅 기간 필터링
# 6. 파트너 중심성 계산
# 7. 포커스 기업 중심성 계산
# 8. 성과 데이터 준비
# 9. 임프린팅 데이터셋 생성
# 10. 회귀 분석
# 11. 임프린팅 효과 분석
# 12. 견고성 검사
```

### 4.3 성과 분석 예제

```r
# 성과 분석 전체 워크플로우
source("examples/performance_analysis_example.R")

# 주요 단계:
# 1. 데이터 로드 및 전처리
# 2. 출구 데이터 생성
# 3. 성과 지표 계산
# 4. 투자 데이터 준비
# 5. 네트워크 중심성 계산
# 6. 다양성 분석
# 7. VC 타입별 성과 분석
# 8. 통계적 검정
# 9. 시계열 분석
# 10. 상관관계 분석
```

### 4.4 회귀 분석 예제

```r
# 회귀 분석 전체 워크플로우
source("examples/regression_analysis_example.R")

# 주요 단계:
# 1. 데이터 로드 및 전처리
# 2. 네트워크 중심성 계산
# 3. 성과 데이터 준비
# 4. 다양성 분석
# 5. 임프린팅 데이터 준비
# 6. 회귀 데이터셋 생성
# 7. 임프린팅 회귀 분석
# 8. CVC 회귀 분석
# 9. 모델 비교
# 10. VIF 분석
# 11. 견고성 검사
# 12. 모델 결과 추출
```

## 문제 해결

### 5.1 일반적인 오류

#### 패키지 관련 오류
```r
# 패키지가 설치되지 않은 경우
if (!require('igraph')) install.packages('igraph'); library('igraph')

# 패키지 버전 충돌
remove.packages('igraph')
install.packages('igraph')
```

#### 데이터 형식 오류
```r
# 데이터 검증
validate_network_params(data, year, time_window)
validate_centrality_params(data, year, time_window, edge_cutpoint)
check_data_completeness(data)
```

#### 메모리 부족 오류
```r
# 병렬 처리 설정 조정
registerDoParallel(cores = 2)  # 코어 수 줄이기

# 데이터 청크 단위 처리
for (chunk in data_chunks) {
  process_chunk(chunk)
}
```

### 5.2 성능 최적화

#### 병렬 처리 설정
```r
# 최적 코어 수 설정
num_cores <- min(parallel::detectCores() - 1, 4)
registerDoParallel(cores = num_cores)

# 진행률 표시
library(progress)
pb <- progress_bar$new(total = length(years))
```

#### 메모리 효율성
```r
# 대용량 데이터 처리
library(data.table)
setDT(data)  # data.table로 변환

# 불필요한 객체 제거
rm(temporary_objects)
gc()  # 가비지 컬렉션
```

### 5.3 디버깅

#### 함수별 테스트
```r
# 개별 함수 테스트
test_network_functions()
test_sampling_functions()
test_diversity_functions()
test_imprinting_functions()
test_performance_functions()
test_regression_functions()
```

#### 로그 확인
```r
# 상세 로그 활성화
options(verbose = TRUE)

# 에러 추적
tryCatch({
  result <- function_call()
}, error = function(e) {
  cat("Error:", e$message, "\n")
  cat("Call stack:", "\n")
  print(sys.calls())
})
```

## 참고 자료

### 6.1 설정 파일

#### parameters.R
```r
# 네트워크 파라미터
NETWORK_PARAMS <- list(
  default_time_window = 5,
  default_edge_cutpoint = NULL,
  min_edges = 1
)

# 샘플링 파라미터
SAMPLING_PARAMS <- list(
  default_ratio = 10,
  min_cases = 10
)
```

#### constants.R
```r
# 산업 분류 코드
INDUSTRY_CODES <- list(
  "Internet Specific" = "ind1",
  "Medical/Health" = "ind2",
  "Consumer Related" = "ind3"
)

# 출구 타입
EXIT_TYPES <- c("Went Public", "Merger", "Acquisition")
```

### 6.2 함수 참조

#### 네트워크 함수
- `VC_matrix()`: 네트워크 매트릭스 생성
- `VC_centralities()`: 중심성 계산
- `create_bipartite_network()`: 이분 네트워크 생성
- `project_network()`: 네트워크 투영

#### 샘플링 함수
- `VC_sampling_opt1()`: 케이스-컨트롤 샘플링
- `VC_sampling_opt1_output()`: 샘플링 출력
- `create_case_control_dataset()`: 케이스-컨트롤 데이터셋

#### 분석 함수
- `blau_index()`: Blau 지수 계산
- `VC_initial_ties()`: 초기 연결 식별
- `VC_exit_num()`: 출구 수 계산
- `run_imprinting_regression()`: 임프린팅 회귀

### 6.3 출력 파일

#### CSV 파일
- `centrality_data.csv`: 중심성 측정
- `diversity_data.csv`: 다양성 지표
- `performance_data.csv`: 성과 지표
- `regression_dataset.csv`: 회귀 데이터셋

#### RDS 파일
- `imprinting_models.rds`: 임프린팅 모델
- `cvc_models.rds`: CVC 모델
- `statistical_tests.rds`: 통계 검정 결과

### 6.4 추가 리소스

#### 문서
- `README.md`: 기본 사용법
- `test_refactored_functions.R`: 테스트 스크립트
- `examples/`: 예제 스크립트들

#### 설정
- `R/config/`: 설정 파일들
- `R/core/`: 핵심 함수들
- `R/analysis/`: 분석 함수들
- `R/utils/`: 유틸리티 함수들

---

**참고**: 이 가이드는 리팩토링된 VC 네트워크 분석 모듈의 완전한 사용법을 제공합니다. 기존 코드의 로직을 그대로 유지하면서 모듈화된 구조로 재구성되었습니다. 