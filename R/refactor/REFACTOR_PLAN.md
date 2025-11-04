# VC 네트워크 분석 R 코드 리팩토링 계획서

## 1. 프로젝트 개요

### 1.1 목표
- 기존 `CVC_preprcs_v4.R`과 `imprinting_Dec18.R` 코드의 중복 제거 및 모듈화
- **연구 목적에 맞는 함수 라이브러리 중심의 접근**
- 코드 재사용성, 유지보수성, 확장성 향상
- 설정 관리 및 에러 처리 강화
- 메모리 효율성 개선

### 1.2 범위
- 네트워크 구성 및 중심성 계산 함수들
- 데이터 전처리 및 변수 생성 함수들
- 샘플링 및 분석 함수들
- 설정 관리 및 유틸리티 함수들

### 1.3 접근 방식
**연구 중심의 함수 라이브러리 접근**

이 리팩토링은 연구자가 데이터 플로우를 자유롭게 조작할 수 있도록 **함수 라이브러리 중심**으로 설계됩니다.

#### 핵심 원칙:
1. **모듈화된 함수 라이브러리**: 기존 코드에서 추출된 함수들을 재사용 가능한 라이브러리로 구성
2. **유연한 데이터 플로우**: 연구자가 필요에 따라 함수들을 조합하여 다양한 분석 플로우 구성 가능
3. **설정 기반 파라미터 관리**: 분석 파라미터를 외부 설정으로 관리하여 다양한 실험 가능
4. **점진적 함수화**: 데이터 처리 과정에서 반복되는 로직을 함수로 추출하여 재사용성 향상

#### 기존 접근과의 차이점:
- **기존**: 전체 분석을 하나의 스크립트로 실행하는 방식
- **리팩토링**: 개별 함수들을 조합하여 연구자가 원하는 분석 플로우를 구성하는 방식
- **결과**: 연구자가 데이터 처리 과정을 세밀하게 제어하고 다양한 실험을 수행할 수 있는 환경

#### 사용 방식:
```r
# 기존 방식
source("CVC_preprcs_v4.R")  # 전체 분석 실행

# 리팩토링 후 방식
source("R/core/network_construction.R")
source("R/analysis/cvc_analysis.R")

# 연구자가 원하는 순서로 함수 조합
network_data <- create_vc_network(edge_data, 1990, 5)
centralities <- calculate_centralities(network_data, 1990)
sampled_data <- case_control_sampling(data, lead_vc_data, ratio = 10)
# ... 연구자가 원하는 분석 플로우 구성
```

## 2. 폴더 구조 설계

```
refactor/
├── R/
│   ├── core/                           # 핵심 함수 라이브러리
│   │   ├── network_construction.R      # 네트워크 구성 핵심 함수
│   │   ├── centrality_calculation.R    # 중심성 계산 함수
│   │   ├── data_processing.R           # 데이터 전처리 함수
│   │   └── sampling_methods.R          # 샘플링 방법 함수
│   ├── analysis/                       # 분석 전용 함수 라이브러리
│   │   ├── cvc_analysis.R              # CVC 분석 전용 함수
│   │   ├── imprinting_analysis.R       # Imprinting 분석 전용 함수
│   │   └── variable_creation.R         # 변수 생성 함수
│   ├── utils/                          # 유틸리티 함수 라이브러리
│   │   ├── validation.R                # 데이터 검증 함수
│   │   ├── memory_utils.R              # 메모리 최적화 함수
│   │   ├── progress_utils.R            # 진행률 표시 함수
│   │   └── file_utils.R                # 파일 처리 함수
│   └── config/                         # 설정 관리
│       ├── parameters.R                # 분석 파라미터 설정
│       ├── constants.R                 # 상수 정의
│       └── paths.R                     # 경로 설정
├── examples/                           # 연구용 예제 스크립트
│   ├── example_cvc_analysis.R          # CVC 분석 예제
│   ├── example_imprinting_analysis.R   # Imprinting 분석 예제
│   ├── example_custom_analysis.R       # 커스텀 분석 예제
│   └── example_experiment_design.R     # 실험 설계 예제
├── tests/                              # 함수 테스트
│   ├── test_network_functions.R        # 네트워크 함수 테스트
│   ├── test_centrality_functions.R     # 중심성 함수 테스트
│   └── test_data_processing.R          # 데이터 처리 함수 테스트
├── docs/                               # 문서
│   ├── function_reference.md           # 함수 참조 문서
│   ├── usage_examples.md               # 사용 예제 문서
│   └── research_workflow_guide.md      # 연구 워크플로우 가이드
├── configs/                            # 연구 설정 저장소
│   ├── cvc_analysis_configs/           # CVC 분석 설정들
│   ├── imprinting_analysis_configs/    # Imprinting 분석 설정들
│   └── experiment_configs/             # 실험 설정들
└── data/                               # 데이터 관리
    ├── raw/                            # 원본 데이터
    ├── processed/                      # 처리된 데이터
    ├── results/                        # 분석 결과
    └── temp/                           # 임시 파일
```

## 3. 핵심 모듈 설계

### 3.1 Core 모듈

#### 3.1.1 network_construction.R
**목적**: 네트워크 구성의 핵심 로직을 담당

**주요 함수들**:
```r
#' Create VC network from investment data
#' @param edge_data Investment edge data (firmname, event, year)
#' @param year Target year for network construction
#' @param time_window Time window for network (default: 5)
#' @param projection_type Type of projection ("vc_vc" or "event_event")
#' @param edge_cutpoint Minimum edge weight threshold
#' @return igraph object
create_vc_network(edge_data, year, time_window = 5, 
                  projection_type = "vc_vc", edge_cutpoint = NULL)

#' Create bipartite network from VC-Company relationships
#' @param edge_data Investment edge data
#' @param year Target year
#' @param time_window Time window
#' @return igraph bipartite network
create_bipartite_network(edge_data, year, time_window = 5)

#' Project bipartite network to one-mode network
#' @param bipartite_net Bipartite network
#' @param projection_type "vc_vc" or "event_event"
#' @return igraph one-mode network
project_network(bipartite_net, projection_type = "vc_vc")
```

#### 3.1.2 centrality_calculation.R
**목적**: 네트워크 중심성 지표 계산

**주요 함수들**:
```r
#' Calculate comprehensive centrality measures
#' @param network igraph network object
#' @param year Target year
#' @return data.frame with centrality measures
calculate_centralities(network, year)

#' Calculate power centrality with different beta values
#' @param network igraph network object
#' @param beta_values Vector of beta values
#' @return data.frame with power centrality measures
calculate_power_centrality(network, beta_values = c(0.75, 1.0, 0.0))

#' Calculate ego network density
#' @param network igraph network object
#' @return data.frame with ego density measures
calculate_ego_density(network)

#' Calculate structural hole constraint
#' @param network igraph network object
#' @return data.frame with constraint measures
calculate_constraint(network)
```

#### 3.1.3 data_processing.R
**목적**: 데이터 전처리 및 기본 변수 생성

**주요 함수들**:
```r
#' Load and validate raw data
#' @param data_path Path to data files
#' @param data_type Type of data ("company", "firm", "round", "fund")
#' @return Validated data.frame
load_and_validate_data(data_path, data_type)

#' Filter data based on criteria
#' @param data Input data
#' @param filters List of filter criteria
#' @return Filtered data.frame
filter_data(data, filters)

#' Create time-based variables
#' @param data Input data
#' @param date_col Date column name
#' @return data.frame with time variables
create_time_variables(data, date_col = "rnddate")

#' Calculate Blau diversity index
#' @param data Investment data with industry information
#' @param time_window Time window for calculation
#' @return data.frame with Blau index
calculate_blau_index(data, time_window = 5)
```

#### 3.1.4 sampling_methods.R
**목적**: 샘플링 방법 구현

**주요 함수들**:
```r
#' Case-control sampling for VC partnerships
#' @param data Investment data
#' @param lead_vc_data Lead VC identification data
#' @param ratio Sampling ratio (default: 10)
#' @param time_period Time period for sampling
#' @return Sampled data.frame
case_control_sampling(data, lead_vc_data, ratio = 10, time_period)

#' Identify Lead VCs based on multiple criteria
#' @param round_data Round investment data
#' @param criteria List of identification criteria
#' @return data.frame with Lead VC identification
identify_lead_vcs(round_data, criteria = NULL)

#' Create potential partner matrix
#' @param lead_vcs Lead VC list
#' @param all_vcs All VC list
#' @param time_period Time period
#' @return Matrix of potential partnerships
create_partner_matrix(lead_vcs, all_vcs, time_period)
```

### 3.2 Analysis 모듈

#### 3.2.1 cvc_analysis.R
**목적**: CVC 분석 전용 함수들

**주요 함수들**:
```r
#' Calculate geographic distance between VCs
#' @param vc_data VC location data
#' @param distance_type Distance calculation method
#' @return Distance matrix
calculate_geographic_distance(vc_data, distance_type = "zip")

#' Calculate industry distance between VCs
#' @param investment_data Investment data with industry info
#' @param time_window Time window for calculation
#' @return Industry distance matrix
calculate_industry_distance(investment_data, time_window = 5)

#' Calculate network distance between VCs
#' @param network igraph network object
#' @return Network distance matrix
calculate_network_distance(network)

#' Calculate exit performance metrics
#' @param investment_data Investment data
#' @param exit_data Exit data
#' @param time_window Time window for calculation
#' @return Exit performance data.frame
calculate_exit_performance(investment_data, exit_data, time_window = 5)
```

#### 3.2.2 imprinting_analysis.R
**목적**: Imprinting 분석 전용 함수들

**주요 함수들**:
```r
#' Identify initial network ties
#' @param edge_data Investment edge data
#' @param year Target year
#' @param imprinting_period Imprinting period length
#' @return Initial ties data.frame
identify_initial_ties(edge_data, year, imprinting_period = 1)

#' Calculate initial partner characteristics
#' @param initial_ties Initial network ties
#' @param centrality_data Centrality data
#' @return Initial partner characteristics
calculate_initial_partner_characteristics(initial_ties, centrality_data)

#' Calculate focal firm initial network position
#' @param initial_ties Initial network ties
#' @param centrality_data Centrality data
#' @return Focal firm characteristics
calculate_focal_initial_position(initial_ties, centrality_data)

#' Analyze network imprinting effects
#' @param initial_data Initial network data
#' @param evolution_data Network evolution data
#' @param time_periods Time periods for analysis
#' @return Imprinting effects analysis
analyze_imprinting_effects(initial_data, evolution_data, time_periods)
```

#### 3.2.3 variable_creation.R
**목적**: 공통 변수 생성 함수들

**주요 함수들**:
```r
#' Create firm-level variables
#' @param firm_data Firm data
#' @param year Current year
#' @return Firm-level variables
create_firm_variables(firm_data, year)

#' Create investment-level variables
#' @param investment_data Investment data
#' @param time_window Time window
#' @return Investment-level variables
create_investment_variables(investment_data, time_window = 5)

#' Create market-level variables
#' @param market_data Market data
#' @param year Current year
#' @return Market-level variables
create_market_variables(market_data, year)

#' Create interaction variables
#' @param base_data Base dataset
#' @param var1 First variable name
#' @param var2 Second variable name
#' @return Interaction variables
create_interaction_variables(base_data, var1, var2)
```

### 3.3 Utils 모듈

#### 3.3.1 validation.R
**목적**: 데이터 및 파라미터 검증

**주요 함수들**:
```r
#' Validate network parameters
#' @param edge_data Edge data
#' @param year Target year
#' @param time_window Time window
#' @return Validation result
validate_network_params(edge_data, year, time_window)

#' Validate centrality calculation parameters
#' @param network Network object
#' @param beta_values Beta values for power centrality
#' @return Validation result
validate_centrality_params(network, beta_values)

#' Validate sampling parameters
#' @param data Input data
#' @param ratio Sampling ratio
#' @param time_period Time period
#' @return Validation result
validate_sampling_params(data, ratio, time_period)

#' Check data completeness
#' @param data Input data
#' @param required_columns Required column names
#' @return Completeness check result
check_data_completeness(data, required_columns)
```

#### 3.3.2 memory_utils.R
**목적**: 메모리 최적화

**주요 함수들**:
```r
#' Process large datasets in chunks
#' @param data Input data
#' @param chunk_size Size of each chunk
#' @param process_fun Function to apply to each chunk
#' @return Combined results
process_in_chunks(data, chunk_size = 10000, process_fun)

#' Optimize memory usage for large networks
#' @param network Network object
#' @param optimization_type Type of optimization
#' @return Optimized network
optimize_network_memory(network, optimization_type = "standard")

#' Clean up memory after processing
#' @param objects_to_remove Objects to remove
#' @param force_gc Force garbage collection
cleanup_memory(objects_to_remove = NULL, force_gc = TRUE)
```

#### 3.3.3 progress_utils.R
**목적**: 진행률 표시 및 로깅

**주요 함수들**:
```r
#' Create progress tracker
#' @param total_steps Total number of steps
#' @param description Description of the process
#' @return Progress tracker object
create_progress_tracker(total_steps, description = "")

#' Update progress
#' @param tracker Progress tracker
#' @param step Current step
#' @param message Optional message
update_progress(tracker, step, message = NULL)

#' Log processing information
#' @param message Log message
#' @param level Log level ("info", "warning", "error")
#' @param timestamp Include timestamp
log_message(message, level = "info", timestamp = TRUE)
```

#### 3.3.4 file_utils.R
**목적**: 파일 처리 및 저장

**주요 함수들**:
```r
#' Save data with compression
#' @param data Data to save
#' @param file_path File path
#' @param format File format ("fst", "rds", "csv")
#' @param compression Compression level
save_data(data, file_path, format = "fst", compression = 100)

#' Load data with error handling
#' @param file_path File path
#' @param format File format
#' @return Loaded data
load_data(file_path, format = "auto")

#' Create output directory structure
#' @param base_path Base directory path
#' @param subdirs Subdirectories to create
create_output_dirs(base_path, subdirs = c("processed", "results", "logs"))
```

### 3.4 Config 모듈

#### 3.4.1 parameters.R
**목적**: 분석 파라미터 설정

```r
# Network construction parameters
NETWORK_PARAMS <- list(
  default_time_window = 5,
  default_edge_cutpoint = 5,
  projection_types = c("vc_vc", "event_event"),
  centrality_beta_values = c(0.75, 1.0, 0.0)
)

# Sampling parameters
SAMPLING_PARAMS <- list(
  default_ratio = 10,
  available_ratios = c(1, 5, 10, 15),
  random_seed = 123
)

# Analysis parameters
ANALYSIS_PARAMS <- list(
  min_year = 1980,
  max_year = 2022,
  imprinting_periods = c(1, 3, 5),
  performance_windows = c(1, 3, 5)
)
```

#### 3.4.2 constants.R
**목적**: 상수 정의

```r
# Data validation constants
REQUIRED_COLUMNS <- list(
  company_data = c("comname", "comsitu", "date_ipo", "date_sit"),
  firm_data = c("firmname", "firmfounding", "firmtype"),
  round_data = c("firmname", "comname", "year", "rnddate")
)

# Industry classification
INDUSTRY_CODES <- list(
  "Internet Specific" = "ind1",
  "Medical/Health" = "ind2",
  "Consumer Related" = "ind3",
  "Semiconductors/Other Elect." = "ind4",
  "Communications and Media" = "ind5",
  "Industrial/Energy" = "ind6",
  "Computer Software and Services" = "ind7",
  "Computer Hardware" = "ind8",
  "Biotechnology" = "ind9",
  "Other Products" = "ind10"
)

# Exit types
EXIT_TYPES <- c("Went Public", "Merger", "Acquisition")
```

#### 3.4.3 paths.R
**목적**: 경로 설정

```r
# Base paths
BASE_PATHS <- list(
  data = "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Yang, Rhee, Ma/data",
  results = "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Yang, Rhee, Ma/results",
  refactor = "Research/VC/R/refactor"
)

# Subdirectories
SUB_DIRS <- list(
  raw_data = "raw",
  processed_data = "processed",
  results = "results",
  logs = "logs",
  temp = "temp"
)
```

## 4. 연구용 함수 라이브러리 사용 예제

### 4.1 CVC 분석 예제 스크립트 (example_cvc_analysis.R)
```r
# 연구자가 원하는 분석 플로우를 구성하는 예제
# 이 스크립트는 참고용이며, 연구자는 자신의 필요에 맞게 수정하여 사용

# 필요한 함수 라이브러리 로드
source("R/config/parameters.R")
source("R/config/constants.R")
source("R/core/network_construction.R")
source("R/core/centrality_calculation.R")
source("R/analysis/cvc_analysis.R")
source("R/utils/validation.R")

# 연구자가 설정할 수 있는 파라미터
my_config <- list(
  time_window = 5,
  sampling_ratio = 10,
  start_year = 1985,
  end_year = 2020,
  edge_cutpoint = 5
)

# 1. 데이터 로드 및 기본 전처리
data <- load_and_validate_data(BASE_PATHS$data, "all")
filtered_data <- filter_data(data, list(
  min_year = my_config$start_year,
  max_year = my_config$end_year,
  us_only = TRUE
))

# 2. Lead VC 식별 (연구자가 다른 기준을 사용할 수 있음)
lead_vc_data <- identify_lead_vcs(filtered_data$round, 
                                 criteria = list(
                                   first_round_weight = 0.4,
                                   investment_ratio_weight = 0.3,
                                   total_amount_weight = 0.3
                                 ))

# 3. 네트워크 구성 (연구자가 다른 기간을 설정할 수 있음)
network_data <- list()
for(year in my_config$start_year:my_config$end_year) {
  network_data[[as.character(year)]] <- create_vc_network(
    filtered_data$round, 
    year, 
    my_config$time_window, 
    "vc_vc", 
    my_config$edge_cutpoint
  )
}

# 4. 중심성 계산 (연구자가 다른 지표를 추가할 수 있음)
centrality_data <- list()
for(year in my_config$start_year:my_config$end_year) {
  centrality_data[[as.character(year)]] <- calculate_centralities(
    network_data[[as.character(year)]], 
    year
  )
}

# 5. 샘플링 (연구자가 다른 비율을 실험할 수 있음)
sampled_data <- case_control_sampling(
  filtered_data$round, 
  lead_vc_data, 
  my_config$sampling_ratio,
  time_period = "quarter"
)

# 6. 추가 변수 생성 (연구자가 새로운 변수를 추가할 수 있음)
geographic_distances <- calculate_geographic_distance(filtered_data$firm)
industry_distances <- calculate_industry_distance(filtered_data$round, my_config$time_window)
exit_performance <- calculate_exit_performance(filtered_data$round, filtered_data$company, my_config$time_window)

# 7. 최종 데이터셋 구성 (연구자가 원하는 변수만 선택)
final_data <- sampled_data %>%
  left_join(bind_rows(centrality_data, .id = "year"), by = c("year", "leadVC" = "firmname")) %>%
  left_join(geographic_distances, by = c("leadVC", "coVC")) %>%
  left_join(industry_distances, by = c("leadVC", "coVC", "year")) %>%
  left_join(exit_performance, by = c("leadVC" = "firmname", "year"))

# 8. 결과 저장 (연구자가 원하는 형식으로 저장)
save_data(final_data, "my_cvc_analysis_results", format = "fst")
```

### 4.2 Imprinting 분석 예제 스크립트 (example_imprinting_analysis.R)
```r
# Imprinting 분석을 위한 함수 라이브러리 사용 예제

# 필요한 함수 라이브러리 로드
source("R/config/parameters.R")
source("R/config/constants.R")
source("R/core/network_construction.R")
source("R/core/centrality_calculation.R")
source("R/analysis/imprinting_analysis.R")
source("R/utils/validation.R")

# 연구자가 설정할 수 있는 파라미터
my_imprinting_config <- list(
  imprinting_periods = c(1, 3, 5),  # 다양한 imprinting 기간 실험
  analysis_years = 1980:2010,
  network_time_windows = c(1, 3, 5)  # 다양한 네트워크 기간 실험
)

# 1. 데이터 로드
data <- load_and_validate_data(BASE_PATHS$data, "all")

# 2. 초기 네트워크 식별 (연구자가 다른 기준을 사용할 수 있음)
initial_networks <- list()
for(period in my_imprinting_config$imprinting_periods) {
  initial_networks[[as.character(period)]] <- identify_initial_networks(
    data$round, 
    period,
    criteria = list(
      min_vc_count = 2,
      include_individual_vcs = FALSE
    )
  )
}

# 3. 네트워크 진화 분석 (연구자가 다른 기간을 분석할 수 있음)
evolution_data <- list()
for(window in my_imprinting_config$network_time_windows) {
  evolution_data[[as.character(window)]] <- analyze_network_evolution(
    data$round, 
    initial_networks,
    time_window = window
  )
}

# 4. Imprinting 효과 분석 (연구자가 다른 측정 방법을 사용할 수 있음)
imprinting_effects <- list()
for(period in my_imprinting_config$imprinting_periods) {
  for(window in my_imprinting_config$network_time_windows) {
    key <- paste0("period_", period, "_window_", window)
    imprinting_effects[[key]] <- analyze_imprinting_effects(
      initial_networks[[as.character(period)]],
      evolution_data[[as.character(window)]],
      analysis_years = my_imprinting_config$analysis_years
    )
  }
}

# 5. 변수 생성 (연구자가 새로운 변수를 추가할 수 있음)
imprinting_variables <- create_imprinting_variables(
  data, 
  initial_networks, 
  evolution_data,
  additional_vars = list(
    market_volatility = TRUE,
    industry_concentration = TRUE,
    geographic_dispersion = TRUE
  )
)

# 6. Panel 데이터 구성 (연구자가 다른 구조를 사용할 수 있음)
panel_data <- construct_panel_data(
  imprinting_variables,
  panel_structure = "firm_year",
  time_varying_vars = c("network_centrality", "investment_amount", "exit_count"),
  time_invariant_vars = c("initial_partner_characteristics", "firm_foundation_year")
)

# 7. 결과 저장
save_data(panel_data, "my_imprinting_analysis_results", format = "fst")
```

### 4.3 연구용 유틸리티 함수들
```r
# 연구자가 자주 사용하는 유틸리티 함수들

#' 연구 설정을 저장하고 로드하는 함수
save_research_config <- function(config, name) {
  saveRDS(config, file.path(BASE_PATHS$refactor, "configs", paste0(name, ".rds")))
}

load_research_config <- function(name) {
  readRDS(file.path(BASE_PATHS$refactor, "configs", paste0(name, ".rds")))
}

#' 분석 결과를 비교하는 함수
compare_analysis_results <- function(result1, result2, comparison_vars) {
  # 연구자가 두 분석 결과를 비교할 수 있는 함수
}

#' 실험 결과를 시각화하는 함수
visualize_experiment_results <- function(results, plot_type = "comparison") {
  # 연구자가 실험 결과를 시각화할 수 있는 함수
}
```

## 5. 테스트 설계

### 5.1 test_network_functions.R
```r
# Test network construction functions
test_that("create_vc_network works correctly", {
  # Test with sample data
  sample_data <- create_sample_edge_data()
  network <- create_vc_network(sample_data, 1990, 5, "vc_vc")
  
  expect_s3_class(network, "igraph")
  expect_gt(vcount(network), 0)
  expect_gt(ecount(network), 0)
})

test_that("project_network works correctly", {
  # Test bipartite projection
  bipartite_net <- create_sample_bipartite_network()
  projected_net <- project_network(bipartite_net, "vc_vc")
  
  expect_s3_class(projected_net, "igraph")
  expect_false(is_bipartite(projected_net))
})
```

### 5.2 test_centrality_functions.R
```r
# Test centrality calculation functions
test_that("calculate_centralities works correctly", {
  sample_network <- create_sample_network()
  centralities <- calculate_centralities(sample_network, 1990)
  
  expect_s3_class(centralities, "data.frame")
  expect_true("degree" %in% colnames(centralities))
  expect_true("betweenness" %in% colnames(centralities))
  expect_true("power_centrality" %in% colnames(centralities))
})
```

## 6. 구현 우선순위

### Phase 1: Core Infrastructure (1-2주)
1. 폴더 구조 생성
2. Config 모듈 구현 (parameters.R, constants.R, paths.R)
3. Utils 모듈 구현 (validation.R, file_utils.R)
4. 기본 검증 함수 구현

### Phase 2: Core Functions (2-3주)
1. network_construction.R 구현 (기존 VC_matrix 함수 통합)
2. centrality_calculation.R 구현 (기존 VC_centralities 함수 통합)
3. data_processing.R 구현 (기존 데이터 처리 함수들 통합)
4. sampling_methods.R 구현 (기존 샘플링 함수들 통합)
5. 기본 테스트 작성

### Phase 3: Analysis Functions (2-3주)
1. cvc_analysis.R 구현 (CVC 분석 전용 함수들)
2. imprinting_analysis.R 구현 (Imprinting 분석 전용 함수들)
3. variable_creation.R 구현 (공통 변수 생성 함수들)
4. 기존 코드와 결과 비교 검증

### Phase 4: Research Tools and Documentation (1-2주)
1. 예제 스크립트 구현 (examples/ 폴더)
2. 연구 워크플로우 가이드 작성
3. 함수 참조 문서 작성
4. 성능 최적화 및 메모리 관리 개선

## 7. 성공 지표

### 7.1 코드 품질
- 함수 중복 제거율: 80% 이상
- 코드 재사용성: 70% 이상
- 테스트 커버리지: 80% 이상

### 7.2 성능
- 메모리 사용량: 기존 대비 20% 감소
- 실행 시간: 기존 대비 10% 이내 유지
- 에러 발생률: 90% 감소

### 7.3 유지보수성
- 함수 문서화: 100%
- 설정 외부화: 100%
- 에러 처리: 100%

## 8. 위험 요소 및 대응 방안

### 8.1 위험 요소
1. **기존 결과와의 불일치**: 충분한 테스트로 검증
2. **성능 저하**: 단계적 최적화
3. **복잡성 증가**: 명확한 문서화와 예제 제공

### 8.2 대응 방안
1. **점진적 구현**: 한 번에 모든 것을 바꾸지 않고 단계적 접근
2. **충분한 테스트**: 각 단계마다 기존 결과와 비교
3. **문서화**: 모든 함수와 사용법을 상세히 문서화

이 리팩토링 계획을 통해 코드의 품질과 유지보수성을 크게 향상시킬 수 있을 것입니다. 