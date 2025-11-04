# VC Network Analysis Refactoring Project - 작업 맥락 요약

## 📋 프로젝트 개요

### 목표
- 기존 VC 네트워크 분석 R 코드를 모듈화하여 재사용 가능한 라이브러리로 리팩토링
- 원본 로직과 스타일을 보존하여 오류 최소화
- 유연한 데이터 플로우 조작 가능하도록 설계
- .pkl 파일을 .rds로 변환하여 R/Python/Stata 호환성 확보

### 사용자 작업 스타일
- **유연성 중시**: 고정된 main() 구조보다 함수 라이브러리 방식 선호
- **단계별 검증**: 각 단계마다 결과 확인 후 다음 단계 진행
- **상세한 오류 추적**: 모든 오류를 체계적으로 기록하고 해결
- **디버깅 중심**: 문제 발생 시 즉시 디버깅 스크립트 생성
- **한국어 문서화**: 분석 설계 문서는 한국어, 함수 docstring은 영어

## 🏗️ 프로젝트 구조

### 폴더 구조
```
Research/VC/R/refactor/
├── R/
│   ├── config/          # 설정 파일
│   ├── core/            # 핵심 함수들
│   ├── analysis/        # 분석 함수들
│   └── utils/           # 유틸리티 함수들
├── examples/            # 사용 예제 스크립트들
├── tests/               # 테스트 스크립트들
├── data/                # 데이터 파일들
└── docs/                # 문서들
```

### 핵심 파일들
- `R/core/network_construction.R`: 네트워크 구축 함수
- `R/core/centrality_calculation.R`: 중심성 계산 함수
- `R/core/sampling.R`: 샘플링 함수들
- `R/core/data_processing.R`: 데이터 처리 함수들
- `R/analysis/imprinting_analysis.R`: 임프린팅 분석
- `R/analysis/performance_analysis.R`: 성과 분석
- `R/analysis/regression_analysis.R`: 회귀 분석
- `ERROR_MEMO.md`: 오류 추적 및 해결 기록
- `examples/debug_detailed.R`: 상세 디버깅 스크립트

## 🔧 주요 기술적 개념

### R 패키지
- **네트워크 분석**: igraph, data.table
- **데이터 처리**: tidyverse, lubridate
- **병렬 처리**: doParallel, foreach
- **파일 처리**: readxl, fst
- **통계 분석**: plm, pglm, lme4, car

### 네트워크 분석 개념
- **이분 네트워크**: VC-투자 라운드 관계
- **일모드 투영**: VC 간 네트워크 생성
- **중심성 측정**: degree, betweenness, power centrality
- **구조적 구멍**: constraint 값

### 데이터 처리 개념
- **동적 컬럼 매핑**: 실제 Excel 헤더 기반 매핑
- **시간윈도우**: year/quarter 기반 이벤트 식별
- **안전한 날짜 처리**: POSIXct 형식 사용

## 🐛 해결된 주요 오류들

### 1. read_excel skiprows 오류
**파일**: `R/core/data_processing.R`
**문제**: `skiprows` 파라미터 오류
**해결**: `skip` 파라미터로 변경

### 2. 날짜 파싱 오류
**파일**: `R/core/data_processing.R`
**문제**: 날짜 컬럼 변환 오류
**해결**: POSIXct 형식으로 안전한 변환

### 3. 이분 네트워크 생성 오류
**파일**: `R/core/network_construction.R`
**문제**: 중복 노드명으로 인한 네트워크 생성 실패
**해결**: 이벤트명에 prefix 추가하여 고유성 보장

### 4. merge 충돌 오류
**파일**: `R/core/centrality_calculation.R`
**문제**: data.frame merge 시 충돌
**해결**: data.table로 변환 후 안전한 merge

### 5. time_window 컬럼 누락
**파일**: `R/core/centrality_calculation.R`
**문제**: rbind 후 time_window 컬럼 누락
**해결**: rbind 후 time_window 컬럼 추가

### 6. EXIT_TYPES 변수 누락
**파일**: `R/analysis/performance_analysis.R`
**문제**: 전역 변수 EXIT_TYPES 누락
**해결**: 로컬 정의 fallback 추가

### 7. cbind 벡터 길이 불일치
**파일**: `R/core/centrality_calculation.R`
**문제**: "x and y are not compatible" 오류
**해결**: cbind 대신 data.table 직접 생성, rep()로 벡터 길이 맞춤

## 📊 현재 작업 상태

### 완료된 작업
- ✅ 모듈화된 함수 구조 설계
- ✅ 동적 컬럼 매핑 시스템 구현
- ✅ 날짜 처리 안전성 확보
- ✅ 이분 네트워크 생성 오류 해결
- ✅ merge 충돌 해결
- ✅ 중심성 계산 오류 해결
- ✅ 데이터 준비 파이프라인 구축
- ✅ 예제 스크립트 업데이트
- ✅ Many-to-many relationship 경고 해결
- ✅ imprinting_analysis_example.R Step 3까지 성공적 실행
- ✅ 성능 최적화 및 진행 상황 모니터링 구현
- ✅ 병렬 처리 중심성 계산 구현
- ✅ 진행 상황 표시 기능 추가

### 진행 중인 작업
- 🔄 디버깅 스크립트 실행 및 검증
- 🔄 최종 통합 테스트

### 남은 작업
- ⏳ 성능 최적화
- ⏳ 문서화 완성
- ⏳ 사용자 가이드 작성

## 🎯 원본 참고 파일들

### 핵심 원본 파일들
- `Research/VC/R/imprinting_Dec18.R`: 임프린팅 분석 메인 로직
- `Research/VC/R/CVC_preprcs_v4.R`: 데이터 전처리 로직
- `Research/VC/R/VC_merge.R`: 데이터 병합 로직

### 데이터 파일들
- `Research/VC/raw/round/US/`: 투자 라운드 데이터
- `Research/VC/raw/comp/`: 회사 데이터
- `Research/VC/raw/firm/`: VC 회사 데이터

## 🔍 디버깅 접근법

### 1. 단계별 검증
```r
# 각 단계마다 결과 확인
cat("Step 1: Data loading\n")
cat("Dimensions:", dim(data), "\n")
cat("Columns:", names(data), "\n")
```

### 2. 함수별 테스트
```r
# 개별 함수 테스트
tryCatch({
  result <- function_name(params)
  cat("Success:", length(result), "\n")
}, error = function(e) {
  cat("Error:", e$message, "\n")
})
```

### 3. 데이터 구조 검사
```r
# 데이터 구조 상세 검사
str(data)
summary(data)
head(data)
```

### 4. 네트워크 검증
```r
# 네트워크 속성 확인
cat("Vertices:", vcount(network), "\n")
cat("Edges:", ecount(network), "\n")
cat("Is bipartite:", is_bipartite(network), "\n")
```

## 📝 사용자 요청 패턴

### 1. 오류 보고
- 구체적인 오류 메시지 제공
- 실행한 코드 스니펫 포함
- 예상 결과와 실제 결과 비교

### 2. 해결 요청
- 즉시 해결책 제시
- 오류 메모 업데이트
- 관련 파일들 수정

### 3. 검증 요청
- 디버깅 스크립트 생성
- 단계별 결과 확인
- 다음 단계 진행 여부 결정

### 4. 문서화 요청
- 한국어로 상세한 설명
- 코드 주석 추가
- 사용 예제 제공

## 🚀 다음 대화에서 이어갈 작업

### 즉시 확인할 사항
1. `debug_detailed.R` 스크립트 실행 결과
2. `VC_centralities` 함수 정상 작동 여부
3. 전체 분석 파이프라인 통합 테스트

### 다음 단계
1. 성능 분석 함수 검증
2. 회귀 분석 함수 검증
3. 최종 통합 테스트
4. 사용자 가이드 작성

### 주의사항
- 모든 수정사항은 `ERROR_MEMO.md`에 기록
- 원본 로직 보존 유지
- 한국어 문서화 지속
- 단계별 검증 필수

## 📞 연락처 및 참고사항

### 작업 환경
- OS: macOS (darwin 24.5.0)
- Shell: /bin/zsh
- 작업 디렉토리: /Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/Documents/Code/Python/PJT

### 중요 파일 경로
- 프로젝트 루트: `Research/VC/R/refactor/`
- 원본 데이터: `Research/VC/raw/`
- 원본 코드: `Research/VC/R/`

### 사용자 선호사항
- 모든 처리 완료 후 한 번에 결과 통지
- 분석 설계 문서는 한국어
- 함수 docstring은 영어
- 유연한 함수 조합 가능한 구조

---

**마지막 업데이트**: 2025-07-20
**현재 상태**: 디버깅 단계 완료, 통합 테스트 준비 중
**다음 목표**: 전체 파이프라인 검증 및 최적화 