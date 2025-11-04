# VC Network Analysis - 에러 및 문제점 메모

## 📋 메모 작성 규칙

### 파일 형식
```
## [날짜] - [문제 유형]
### 파일: [파일 경로]
### 함수: [함수명]
### 에러 내용: [에러 메시지 또는 문제 설명]
### 상황: [에러가 발생한 상황]
### 해결 방법: [해결 방법 또는 제안사항]
### 상태: [미해결/해결됨/검토중]
```

---

## 🔍 발견된 문제점들

### [2025-07-20] - 누락된 함수들
### 파일: R/analysis/performance_analysis.R
### 함수: create_exit_data()
### 에러 내용: com_sit 변수명이 잘못됨 (comsitu가 맞음)
### 상황: 출구 데이터 생성 시 변수명 오류
### 해결 방법: com_sit를 comsitu로 수정
### 상태: 해결됨

### [2025-07-20] - 누락된 함수들
### 파일: R/analysis/diversity_analysis.R
### 함수: calculate_industry_proportion()
### 에러 내용: 함수가 정의되지 않음
### 상황: 예제 스크립트에서 호출하지만 함수가 없음
### 해결 방법: 함수 구현 완료
### 상태: 해결됨

### [2025-07-20] - 누락된 함수들
### 파일: R/analysis/diversity_analysis.R
### 함수: calculate_portfolio_diversity()
### 에러 내용: 함수가 정의되지 않음
### 상황: 예제 스크립트에서 호출하지만 함수가 없음
### 해결 방법: 함수 구현 완료
### 상태: 해결됨

### [2025-07-20] - 누락된 함수들
### 파일: R/analysis/diversity_analysis.R
### 함수: calculate_geographic_diversity()
### 에러 내용: 함수가 정의되지 않음
### 상황: 예제 스크립트에서 호출하지만 함수가 없음
### 해결 방법: 함수 구현 완료
### 상태: 해결됨

### [2025-07-20] - 누락된 함수들
### 파일: R/analysis/diversity_analysis.R
### 함수: calculate_stage_diversity()
### 에러 내용: 함수가 정의되지 않음
### 상황: 예제 스크립트에서 호출하지만 함수가 없음
### 해결 방법: 함수 구현 완료
### 상태: 해결됨

### [2025-07-20] - 누락된 함수들
### 파일: R/analysis/imprinting_analysis.R
### 함수: create_imprinting_dataset()
### 에러 내용: 함수가 정의되지 않음
### 상황: 예제 스크립트에서 호출하지만 함수가 없음
### 해결 방법: 함수 구현 완료
### 상태: 해결됨

### [2025-07-20] - 누락된 함수들
### 파일: R/analysis/imprinting_analysis.R
### 함수: calculate_imprinting_effects()
### 에러 내용: 함수가 정의되지 않음
### 상황: 예제 스크립트에서 호출하지만 함수가 없음
### 해결 방법: 함수 구현 완료
### 상태: 해결됨

### [2025-07-20] - 논리적 문제점
### 파일: R/analysis/performance_analysis.R
### 함수: VC_IPO_num(), VC_MnA_num()
### 에러 내용: exit 변수를 사용하지만 실제로는 ipoExit, MnAExit을 사용해야 함
### 상황: 성과 분석에서 잘못된 변수 사용
### 해결 방법: 각 함수에서 해당하는 exit 타입 변수 사용
### 상태: 해결됨

### [2025-07-20] - 누락된 함수들
### 파일: R/analysis/regression_analysis.R
### 함수: run_robustness_checks()
### 에러 내용: 함수가 불완전함 (200번째 줄에서 끝남)
### 상황: 회귀 분석에서 견고성 검사 함수 미완성
### 해결 방법: 함수 완성 완료
### 상태: 해결됨

### [2025-07-20] - 누락된 함수들
### 파일: R/core/data_processing.R
### 함수: create_event_identifiers()
### 에러 내용: event 컬럼 생성 로직이 불완전함
### 상황: 데이터 처리에서 이벤트 식별자 생성 미완성
### 해결 방법: 이벤트 식별 로직 완성 완료
### 상태: 해결됨

### [2025-07-20] - 누락된 함수들
### 파일: R/analysis/imprinting_analysis.R
### 함수: VC_initial_centrality()
### 에러 내용: 함수가 불완전함 (주석에 "incomplete" 표시)
### 상황: 초기 중심성 계산 함수 미완성
### 해결 방법: 연구 요구사항에 맞는 로직 구현 필요
### 상태: 미해결

### [2025-07-20] - 패키지 의존성 문제
### 파일: load_all_modules.R
### 함수: quick_setup()
### 에러 내용: pglm 패키지가 CRAN에서 제거됨
### 상황: 패키지 설치 실패
### 해결 방법: 대체 패키지 사용 또는 다른 설치 방법
### 상태: 해결됨

### [2025-07-20] - 데이터 로딩 문제
### 파일: examples/*.R
### 에러 내용: readRDS() 사용하지만 실제로는 .pkl 파일 로드 필요
### 상황: Python pickle 파일을 R에서 로드하는 문제
### 해결 방법: raw 데이터에서 직접 .rds 파일 생성하는 data_preparation.R 스크립트 작성
### 상태: 해결됨

### [2025-07-20] - 새로운 데이터 처리 시스템
### 파일: R/data_preparation.R
### 내용: raw Excel 파일에서 .rds 파일 생성하는 완전한 파이프라인 구현
### 기능: 
### - read_merge_save_rds(): Excel 파일 병합 및 .rds 저장
### - process_round_data(): 라운드 데이터 처리
### - process_company_data(): 회사 데이터 처리  
### - process_firm_data(): VC 회사 데이터 처리
### - process_all_data(): 전체 데이터 처리 파이프라인
### 상태: 구현 완료

### [2025-07-20] - 패키지 의존성 정리
### 파일: load_all_modules.R
### 내용: reticulate 패키지 제거, readxl 패키지 추가
### 이유: .pkl 파일 로딩 대신 raw 데이터에서 직접 .rds 생성
### 상태: 완료됨

### [2025-07-20] - 데이터 처리 함수 버그 수정
### 파일: R/data_preparation.R
### 에러 내용: read_excel()에서 skip = NULL 에러 발생
### 상황: round 데이터와 firm 데이터 처리 시 skiprows = NULL 사용
### 해결 방법: skiprows = 0으로 변경, read_excel()에서 NULL 처리 로직 추가
### 상태: 해결됨

### [2025-07-20] - 경로 업데이트
### 파일: R/data_preparation.R
### 내용: STARTUP_PATH를 "startup"에서 "comp"로 변경
### 이유: 실제 raw 데이터 디렉토리 구조에 맞춤
### 상태: 완료됨

### [2025-07-20] - 컬럼 매핑 수정
### 파일: R/data_preparation.R
### 내용: 실제 Excel 파일의 컬럼명에 맞춰 매핑 업데이트
### 변경사항:
### - ROUND_COLUMN_MAPPING: 실제 round 파일 컬럼명으로 수정
### - COMPANY_COLUMN_MAPPING: 실제 company 파일 컬럼명으로 수정  
### - FIRM_COLUMN_MAPPING: 실제 firm 파일 컬럼명으로 수정
### - 중복 컬럼명 처리 로직 추가
### 상태: 완료됨

### [2025-07-20] - 컬럼명 확인 기능 추가
### 파일: R/data_preparation.R
### 내용: check_actual_columns(), check_all_columns() 함수 추가
### 기능: 실제 Excel 파일의 컬럼명을 확인하여 매핑 검증
### 상태: 완료됨

### [2025-07-20] - 동적 컬럼 매핑 시스템 구현
### 파일: R/data_preparation.R
### 내용: 완전히 새로운 접근 방식으로 데이터 처리 시스템 재구축
### 주요 변경사항:
### - 엔터가 포함된 컬럼명 정리 함수 (clean_column_name)
### - 실제 Excel 파일에서 컬럼명 추출 함수 (extract_actual_columns)
### - 동적 컬럼 매핑 생성 함수 (create_column_mapping)
### - 표준화된 컬럼명 생성 함수 (generate_standard_name)
### - 모든 데이터 처리 함수를 2단계로 분리 (컬럼 추출 → 데이터 처리)
### - 전역 변수에 실제 컬럼명과 매핑 저장
### 기능: 
### 1. 실제 Excel 파일을 읽어서 정확한 컬럼명 추출
### 2. 엔터를 띄어쓰기로 변환하여 컬럼명 정리
### 3. 모든 파일에서 공통된 컬럼명 찾기
### 4. 컬럼명 패턴 매칭으로 표준화된 이름 생성
### 5. 동적으로 생성된 매핑으로 데이터 처리
### 상태: 완료됨

### [2025-07-20] - read_excel 파라미터 수정
### 파일: R/data_preparation.R
### 내용: read_excel() 함수에서 skiprows 파라미터를 skip으로 수정
### 이유: readxl 패키지에서는 skiprows 대신 skip 파라미터를 사용
### 수정 위치:
### - extract_actual_columns() 함수
### - process_round_data() 함수  
### - process_company_data() 함수
### - process_firm_data() 함수
### 상태: 완료됨

### [2025-07-20] - 날짜 형식 처리 수정
### 파일: examples/imprinting_analysis_example.R
### 내용: 날짜 컬럼 처리 시 발생하는 형식 오류 수정
### 문제: date_sit, date_ipo, firmfounding, rnddate 컬럼이 문자형으로 저장되어 날짜 변환 시 오류 발생
### 해결방법:
### - 빈 문자열, NA, "NA" 문자열을 적절히 처리
### - case_when을 사용하여 유효한 날짜만 변환
### - as.Date() 변환 전에 문자열 정리
### 수정 위치:
### - company 데이터 처리 (date_sit, date_ipo)
### - firm 데이터 처리 (firmfounding)
### - round 데이터 처리 (rnddate)
### 상태: 완료됨

### [2025-07-20] - 날짜 형식 재수정
### 파일: examples/imprinting_analysis_example.R
### 내용: 날짜 컬럼이 이미 POSIXct 형식으로 저장되어 있음을 확인하고 처리 방법 수정
### 문제: 날짜 컬럼들이 이미 POSIXct 형식인데 문자형으로 처리하려고 해서 오류 발생
### 해결방법:
### - 불필요한 날짜 변환 로직 제거
### - POSIXct 형식에서 직접 year() 함수 사용
### - is.na() 함수로 NA 값만 체크
### 수정 내용:
### - company 데이터: date_sit, date_ipo를 직접 사용
### - firm 데이터: firmfounding에서 직접 year 추출
### - round 데이터: rnddate에서 직접 year, month, day 추출
### 상태: 완료됨

### [2025-07-20] - VC_initial_ties 함수 컬럼명 수정
### 파일: R/analysis/imprinting_analysis.R
### 내용: VC_initial_ties 함수에서 반환되는 데이터프레임의 컬럼명 수정
### 문제: 함수가 V1, V2, tied_year 컬럼을 반환하는데, left_join에서 firmname 컬럼을 찾을 수 없음
### 해결방법: 반환되는 데이터프레임의 컬럼명을 firmname, initial_partner, tied_year로 변경
### 상태: 완료됨

### [2025-07-20] - VC_initial_ties 함수 bipartite 네트워크 수정
### 파일: R/analysis/imprinting_analysis.R
### 내용: VC_initial_ties 함수에서 bipartite projection 오류 수정
### 문제: "Non-bipartite edge found in bipartite projection" 에러 발생
### 원인: 네트워크 생성 시 firmname과 comname이 제대로 구분되지 않아 같은 타입 노드 간 연결 생성
### 해결방법:
### - 명시적으로 firmname과 comname 컬럼만 사용하여 bipartite 네트워크 생성
### - complete.cases()로 결측값 제거
### - is_bipartite() 체크 추가
### - proj1 사용하여 firm-firm 네트워크 생성
### - 빈 데이터프레임 반환 시 올바른 컬럼 구조 유지
### 상태: 완료됨

### [2025-07-20] - EXIT_TYPES 변수 정의 추가
### 파일: examples/imprinting_analysis_example.R
### 내용: EXIT_TYPES 변수가 정의되지 않아서 발생하는 오류 수정
### 문제: constants.R에서 EXIT_TYPES가 정의되어 있지만 로딩되지 않아 오류 발생
### 해결방법: 스크립트에서 EXIT_TYPES 변수가 없으면 로컬에서 정의
### 상태: 완료됨

### [2025-07-20] - centrality_df의 time_window 컬럼 누락 문제 수정
### 파일: examples/imprinting_analysis_example.R
### 내용: centrality_df에서 time_window 컬럼이 누락되어 필터링 오류 발생
### 문제: do.call("rbind") 과정에서 time_window 컬럼이 손실됨
### 해결방법: 
### - 빈 데이터프레임 체크 추가
### - time_window 컬럼 존재 여부 확인 및 재생성
### - 안전한 데이터프레임 결합 로직 구현
### 상태: 완료됨

### [2025-07-20] - event 컬럼 생성 추가
### 파일: examples/imprinting_analysis_example.R, R/core/network_construction.R
### 내용: event 컬럼이 없어서 네트워크 생성 실패하는 문제 수정
### 문제: VC_matrix 함수에서 event 컬럼을 사용하지만 round 데이터에 event 컬럼이 없음
### 해결방법: 
### - round 데이터 처리 시 event = paste(comname, rnddate, sep = "-") 생성
### - VC_matrix 함수를 원래 event 컬럼 사용하도록 복원
### - date-comname 조합으로 고유한 투자 라운드 식별자 생성
### 상태: 완료됨

### [2025-07-20] - 이분 네트워크 생성 오류 수정
### 파일: R/core/network_construction.R
### 내용: "Non-bipartite edge found in bipartite projection" 오류 수정
### 문제: firmname과 event가 같은 값을 가져서 이분 네트워크 생성 실패
### 해결방법: 
### - firmname과 event 간 중복 값 체크
### - 중복이 있으면 event에 "event_" 접두사 추가
### - 이분 네트워크 구조 보장
### 상태: 완료됨

### [2025-07-20] - event 생성 로직 근본적 수정 (timewave 개념 도입)
### 파일: examples/imprinting_analysis_example.R, R/core/network_construction.R
### 내용: event 생성 시 잘못된 날짜 사용 문제 수정 및 timewave 개념 도입
### 문제: 
### - event = paste(comname, rnddate, sep = "-") → 전체 날짜 사용 (잘못됨)
### - 같은 회사의 같은 연도 투자를 각각 다른 event로 처리
### - quarter별 timewave 지원 부재
### 해결방법: 
### - event = paste(comname, timewave, sep = "-") → timewave 사용 (올바름)
### - timewave = year (기본값) 또는 quarter
### - 같은 회사의 같은 timewave 투자를 하나의 event로 통합
### - VC_matrix 함수에 timewave_unit 파라미터 추가
### 상태: 완료됨

### [2025-07-20] - data.table merge 충돌 오류 수정
### 파일: R/core/centrality_calculation.R
### 내용: "x and y are not compatible" 오류 수정
### 문제: data.table과 data.frame 병합 시 컬럼명 충돌 발생
### 해결방법: 
### - cent_dta와 ego_dta를 모두 data.table로 변환
### - merge 시 all.x=TRUE 옵션 추가로 안전한 병합
### - 컬럼명 충돌 방지
### 상태: 완료됨

### [2025-07-20] - cbind 벡터 길이 불일치 오류 수정
### 파일: R/core/centrality_calculation.R
### 내용: "x and y are not compatible" 오류의 근본 원인 수정
### 문제: cbind(year, centrality_vectors)에서 year(스칼라)와 centrality_vectors(벡터) 길이 불일치
### 해결방법: 
### - cbind 대신 data.table 직접 생성
### - year를 rep()로 벡터 길이에 맞게 반복
### - firmname을 names(V(adjmatrix))로 직접 설정
### - 벡터 길이 일치 보장
### 상태: 완료됨

### [2025-07-21] - Many-to-many relationship 경고 해결
### 파일: examples/imprinting_analysis_example.R
### 내용: left_join에서 many-to-many relationship 경고 발생
### 문제: 
### - firmdta와 comdta에 중복된 firmname/comname이 존재
### - 단순히 unique()만으로는 중복 제거 불가
### - 원본 CVC_preprcs_v4.R의 단계별 merge 로직과 다름
### 해결방법:
### - firmdta와 comdta에서 group_by(firmname/comname) %>% slice(1)로 중복 완전 제거
### - 원본 코드처럼 단계별 merge 로직 구현
### - US 케이스만 필터링하는 로직 추가
### - Angel 그룹 제외 로직 추가
### 상태: 완료됨

### [2025-07-21] - 성능 최적화 및 진행 상황 모니터링 구현
### 파일: R/utils/validation.R, examples/imprinting_analysis_example.R
### 내용: 계산 속도 개선 및 진행 상황 표시 기능 추가
### 구현사항:
### - time_execution(): 함수 실행 시간 측정
### - create_year_progress(): 연도별 진행 상황 표시
### - vectorized_centrality_calculation(): 병렬 처리 중심성 계산
### - optimized_network_construction(): 네트워크 캐싱
### - chunked_processing(): 메모리 효율적 데이터 처리
### - benchmark_function(): 함수 성능 벤치마킹
### - imprinting_analysis_example.R에 최적화 적용
### - 병렬 처리로 중심성 계산 속도 대폭 개선
### 상태: 완료됨

### [2025-07-21] - registerDoParallel 함수 누락 에러 수정
### 파일: R/utils/validation.R, load_all_modules.R
### 내용: vectorized_centrality_calculation 함수에서 registerDoParallel 함수를 찾을 수 없음
### 문제: doParallel 패키지가 명시적으로 로드되지 않아서 발생
### 해결방법:
### - vectorized_centrality_calculation 함수에 패키지 로드 로직 추가
### - parallel, foreach, doParallel 패키지를 함수 내에서 확인하고 로드
### - load_all_modules.R에 doParallel 패키지를 필수 패키지 목록에 추가
### 상태: 완료됨

### [2025-07-21] - CPU 사용률 제한 설정 (80% 제한)
### 파일: R/utils/validation.R, examples/imprinting_analysis_example.R
### 내용: 병렬 처리 시 CPU 사용률을 80%로 제한하여 시스템 안정성 확보
### 구현사항:
### - vectorized_centrality_calculation 함수에 CPU 사용률 제한 로직 추가
### - PARALLEL_PARAMS 설정을 활용한 동적 CPU 코어 수 계산
### - chunked_processing 함수에 병렬 처리 옵션 및 CPU 제한 추가
### - 시스템 정보 및 CPU 사용률 제한 표시 기능 추가
### - 기본값으로 80% CPU 사용률 제한 설정
### 상태: 완료됨

### [2025-07-21] - 데이터 필터링 및 dplyr 경고 수정
### 파일: R/config/parameters.R, R/analysis/imprinting_analysis.R, examples/*.R
### 내용: 예제 코드에서 7개년 데이터로 제한하고 dplyr funs() 경고 수정
### 구현사항:
### - EXAMPLE_PARAMS 설정 추가 (1990-2000년, 11개년으로 확장)
### - 모든 example 파일에 데이터 필터링 로직 추가
### - dplyr funs() 함수를 현대적인 across() 문법으로 수정
### - left_join 에러 수정 (do.call 대신 순차적 join 사용)
### - imprinting_analysis_example.R에서 CPU 제한 및 병렬 처리 성공
### - 6개 코어 병렬 처리로 성능 개선 확인
### - 네트워크 생성 성공 (4,864개 중심성 데이터)
### - 종합 임프린팅 데이터셋 생성 성공 (7,697개 관측치)
### - 컬럼명 매칭 문제 해결 (rndamt, comindmnr, NumExit 등)
### - 패널 데이터 생성 시 lag 연산 문제 발견
### 상태: 핵심 논리적 문제 해결 완료 (Merge 키 매칭 문제만 남음)
### 해결된 문제들:
### ✅ Initial Year vs Tied Year 논리적 오류: 완전 해결 (9,077개 모두 올바름)
### ✅ 중복 underscore 문제: p_dgr_cent_3y, p_dgr_cent_5y 등으로 해결
### ✅ Power Centrality 계산 에러: tryCatch로 완전 해결
### ✅ Performance Data 컬럼명 문제: comsitu 기반 exit 판단으로 해결
### ✅ Industry Data 컬럼명 매핑: comindmnr 사용으로 해결
### ✅ 네트워크 누적 로직: 5년 > 3년 > 1년 순으로 올바르게 작동 확인

### 최종 성과:
### - 네트워크 중심성: 30,340개 데이터 생성 성공
### - Initial ties: 9,077개 연결 성공 (논리적 오류 없음)
### - Investment data: 8,222개 non-zero 값 성공
### - 종합 임프린팅 데이터셋: 9,077개 관측치 성공
### - 모든 데이터 처리 단계 완료 (Step 1-9)

### 남은 작업:
### - Centrality data와 Performance data의 merge 키 매칭 문제 해결
### - Step 10: glm 모델 수렴 문제 해결

---

## 📝 새로운 문제점 기록

### [날짜] - [문제 유형]
### 파일: [파일 경로]
### 함수: [함수명]
### 에러 내용: [에러 메시지 또는 문제 설명]
### 상황: [에러가 발생한 상황]
### 해결 방법: [해결 방법 또는 제안사항]
### 상태: [미해결/해결됨/검토중]

---

## 🚨 긴급 문제점

### [날짜] - 긴급
### 파일: [파일 경로]
### 함수: [함수명]
### 에러 내용: [에러 메시지]
### 상황: [상황]
### 우선순위: [높음/중간/낮음]
### 상태: [미해결/해결됨/검토중]

---

## 🔧 수정이 필요한 부분

### [날짜] - 수정 필요
### 파일: [파일 경로]
### 함수: [함수명]
### 문제: [문제 설명]
### 현재 상태: [현재 어떻게 되어 있는지]
### 개선 방향: [어떻게 개선하고 싶은지]
### 상태: [미해결/해결됨/검토중]

---

## 📊 성능 문제

### [날짜] - 성능 이슈
### 파일: [파일 경로]
### 함수: [함수명]
### 문제: [성능 문제 설명]
### 현재 속도: [현재 실행 시간]
### 목표 속도: [목표 실행 시간]
### 개선 방안: [개선 방법]
### 상태: [미해결/해결됨/검토중]

---

## 🧪 테스트 결과

### [날짜] - 테스트 실패
### 파일: [파일 경로]
### 함수: [함수명]
### 테스트: [테스트 내용]
### 예상 결과: [예상 결과]
### 실제 결과: [실제 결과]
### 원인: [실패 원인]
### 해결 방법: [해결 방법]
### 상태: [미해결/해결됨/검토중]

---

---

## 🐛 CVC Flow Testing Errors (2025-10-11)

### 2025-10-11 - Missing coVC_age and leadVC_age Variables
### 파일: `testing_results/cvc_flow/test_cvc_full_flow.R`
### 함수: Step 6 - Variable Creation
### 에러 메시지:
```
Error in `mutate()`:
ℹ In argument: `ln_coVC_age = log(coVC_age + 1)`.
Caused by error:
! object 'coVC_age' not found
```

### 문제:
테스트 스크립트에서 `coVC_age`와 `leadVC_age` 변수 생성 로직이 누락됨.

### 원본 코드 (CVC_preprcs_v4.R):
```r
raw <- raw %>%
  mutate(leadVC_age = year - year(firmfounding.x),
         coVC_age = year - year(firmfounding.y)) %>%
  select(-firmfounding.x, -firmfounding.y)
```

### 해결 방법:
1. `firmfounding` 데이터를 leadVC와 coVC 각각에 대해 병합
2. `year - year(firmfounding)` 계산으로 age 변수 생성
3. 음수 나이는 0으로 처리 (원본 로직 참조: `coVC_age = ifelse(coVC_age <0, 0, coVC_age)`)

### 수정 코드:
```r
# Merge firm founding dates and calculate ages
raw <- raw %>%
  left_join(firmdta %>% select(firmname, firmfounding) %>% unique(), 
            by = c("leadVC" = "firmname")) %>%
  left_join(firmdta %>% select(firmname, firmfounding) %>% unique(), 
            by = c("coVC" = "firmname"), suffix = c(".x", ".y")) %>%
  mutate(
    leadVC_age = year - year(firmfounding.x),
    coVC_age = year - year(firmfounding.y)
  ) %>%
  select(-firmfounding.x, -firmfounding.y) %>%
  mutate(
    leadVC_age = ifelse(leadVC_age < 0, 0, leadVC_age),
    coVC_age = ifelse(coVC_age < 0, 0, coVC_age)
  )
```

### 상태: ✅ 해결됨 (2025-10-11)

---

### 2025-10-11 - Many-to-many Merge Warnings
### 파일: `testing_results/cvc_flow/test_cvc_full_flow.R`
### 함수: Step 6 - firmtype2 Merge
### 경고 메시지:
```
Warning: Detected an unexpected many-to-many relationship between `x` and `y`.
```

### 문제:
`firmtype2` 병합 시 일부 firm이 중복된 레코드를 가지고 있어 many-to-many 관계 발생.

### 원인:
`firmdta` 테이블에서 같은 `firmname`이 여러 행에 나타날 수 있음 (데이터 품질 이슈).

### 해결 방법:
병합 전 `group_by() %>% slice(1) %>% ungroup()`로 중복 제거하거나, 
`relationship = "many-to-many"` 명시적으로 설정.

### 상태: ⚠️ 검토 필요 - 원본 코드 동작과 비교 필요

---

## 📋 우선순위별 해결 계획

---

## 🐛 Imprinting Flow Testing Errors (2025-10-11)

### 2025-10-11 - Missing 'quar' Column
### 파일: `testing_results/imprinting_flow/test_imprinting_full_flow.R`
### 에러: Can't subset columns that don't exist. x Column `quar` doesn't exist.
### 해결: 원본 데이터에 `quar` 컬럼 없음. `quarter` 직접 생성으로 변경.
### 상태: ✅ 해결됨

---

### 2025-10-11 - Wrong Column Name 'comcountry'
### 파일: `testing_results/imprinting_flow/test_imprinting_full_flow.R`
### 에러: object 'comcountry' not found
### 해결: `comcountry` → `comnation`으로 수정
### 상태: ✅ 해결됨

---

### 2025-10-11 - Missing Undisclosed Filtering & Inconsistent Preprocessing
### 파일: `testing_results/imprinting_flow/test_imprinting_full_flow.R`
### 문제: Initial ties 계산 결과가 0개
### 원인:
- Undisclosed Firm/Company 필터링 누락
- US 필터링이 CVC와 다름 (comnation만 확인)
- 전처리 로직이 CVC와 불일치

### 해결:
CVC와 동일한 전처리 로직으로 변경:
1. Undisclosed Firm/Company 필터링 추가
2. US 필터링: firmnation과 comnation 모두 확인
3. Angel 제외: left_join 방식으로 변경
4. Year 범위: 1970-2011로 제한
5. 중복 컬럼 정리 추가

### 상태: ✅ 해결됨 - 테스트 정상 실행 중

---

### 🔴 높은 우선순위 (즉시 해결 필요)
1. ✅ coVC_age/leadVC_age 변수 생성 (해결됨 2025-10-11)
2. ✅ CVC flow 전체 테스트 완료 (성공 2025-10-11)
3. ✅ Imprinting 데이터 전처리 이슈 (해결됨 2025-10-11)
4. 🔄 Imprinting flow 완료 대기

### 🟡 중간 우선순위 (1-2주 내 해결)
1. ✅ Imprinting flow 테스트 스크립트 작성 (완료)
2. ✅ 에러 핸들링 시스템 구축 (완료)
3. ✅ 통합 테스트 시스템 구축 (완료)
4. ⚠️ Many-to-many merge 경고 처리

### 🟢 낮은 우선순위 (시간 있을 때)
1. Python 전처리 코드 구현
2. 성능 최적화
3. 추가 검증 테스트 
---

## [2025-10-12] Imprinting Test Errors - Final Session

### Error 9: Missing ipoExit/MnAExit in Performance Calculation
**Location**: `test_imprinting_full_flow.R`, Line ~406  
**Error Message**: `object 'ipoExit' not found`  
**Cause**: 
- Exit variables are in `comdta`, not `round`
- Performance calculation tried to aggregate from `round` directly

**Fix**:
```r
# Before (wrong)
round %>%
  group_by(firmname) %>%
  summarise(n_exits_ipo = sum(ipoExit, na.rm = TRUE))

# After (correct)
round %>%
  left_join(comdta %>% select(comname, ipoExit, MnAExit), by = "comname") %>%
  group_by(firmname) %>%
  summarise(n_exits_ipo = sum(ipoExit, na.rm = TRUE))
```

**Impact**: Major (analysis blocked)  
**Status**: ✅ Fixed

---

### Error 10: Wrong Edge Data for VC_initial_ties
**Location**: `test_imprinting_full_flow.R`, Line ~204  
**Error Message**: `VC_initial_ties` returned 0 rows  
**Cause**: 
- `VC_initial_ties` requires `firmname` and `comname` columns
- But `edge_raw` only had `firmname`, `year`, `event`

**Fix**:
```r
# Create two edge datasets
edge_raw <- round %>%
  select(firmname, comname, year) %>%  # For VC_initial_ties
  distinct()

edgeRound <- round %>%
  select(firmname, year, event) %>%    # For VC_centralities
  distinct()
```

**Impact**: Critical (no imprinting data generated)  
**Status**: ✅ Fixed

---

### Error 11: Bipartite Network Name Overlap in VC_initial_ties
**Location**: `R/analysis/imprinting_analysis.R`, Line ~37-60  
**Error Message**: `Non-bipartite edge found in bipartite projection`  
**Cause**: Some companies have same names as VC firms  
**Fix**:
```r
# Check for overlapping names
firmnames <- unique(edge_data[,1])
companynames <- unique(edge_data[,2])
overlap <- intersect(as.character(firmnames), as.character(companynames))
if (length(overlap) > 0) {
  # Add prefix to companies
  edge_data[,2] <- paste0("com_", edge_data[,2])
}
```

**Impact**: Critical (bipartite projection failed)  
**Status**: ✅ Fixed

---

### Error 12: Wrong Column Names for Log Variables
**Location**: `test_imprinting_full_flow.R`, Line ~429  
**Error Message**: `object 'p_dgr' not found`  
**Cause**: 
- Partner/focal centrality functions return `p_dgr_cent`, not `p_dgr`
- Log variable creation used wrong names

**Fix**:
```r
# Before
ln_p_dgr = log(p_dgr + 1)
ln_f_dgr = log(f_dgr + 1)

# After
ln_p_dgr = log(p_dgr_cent + 1)
ln_f_dgr = log(f_dgr_cent + 1)
```

**Impact**: Major (final dataset creation failed)  
**Status**: ✅ Fixed

---

## Summary of Imprinting Test Session

**Duration**: ~3.5 hours (4 retry attempts)  
**Errors Fixed**: 4 major errors  
**Final Status**: ✅ **SUCCESS**

**Output Generated**:
- ✅ 7 data files (157K-7.6M rows)
- ✅ 1 results file (descriptive stats)
- ⚠️ pglm models failed due to memory (16 GB limit with 7.6M rows)

**Key Learning**: 
- Imprinting analysis generates extremely large datasets (7.6M rows)
- Future: Consider sampling or year range reduction for statistical models
- All data processing logic works correctly


---

## [2025-10-12] Year Range Optimization

### Issue: Memory Overflow in pglm Models (1970-2011)
**Symptom**: `vector memory limit of 16.0 Gb reached`  
**Data Size**: 7,610,360 rows  
**Models**: All pglm models failed  

### Solution: Reduce Year Range to 1980-2000
**Change**:
```r
# Before
min_year <- 1970
max_year <- 2011
# Parallel loop: foreach(y = 1970:2011, ...)

# After
min_year <- 1980
max_year <- 2000
# Parallel loop: foreach(y = min_year:max_year, ...)
```

**Results**:
- Data size: **4,241,330 rows** (-44%)
- Initial ties: **31,727** (-53%)
- Duration: **4.5 minutes** (-72%)
- Model 0, 1, 2: **All completed successfully** ✅

**Trade-off**: 
- ✅ Faster execution, manageable memory
- ⚠️ Shorter time period for analysis (21 years vs 42 years)
- ⚠️ Model results show Inf std.error (needs further investigation)

**Recommendation**: 
- Use 1980-2000 for testing and development
- For production analysis, consider sampling or chunked processing
- Or use high-memory server for full 1970-2011 range

