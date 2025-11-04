# CVC Flow Testing Summary
Date: 2025-10-11
Status: ✅ IN PROGRESS

---

## 📋 실행 계획

### ✅ 완료된 작업

1. **폴더 구조 정리**
   - ✅ `python_preprocessing` → `refactor_v2`로 이름 변경
   - ✅ `testing_results/cvc_flow/{data,results,logs}` 폴더 생성

2. **코드 비교 분석**
   - ✅ `COMPARISON_REPORT.md` 작성 완료
   - ✅ 주요 발견사항:
     - 리팩토링 코드가 **원본 버그 수정** (IPO/M&A 변수)
     - 에러 처리 및 안정성 향상
     - 핵심 로직은 원본과 동일

3. **테스트 스크립트 작성**
   - ✅ `test_cvc_full_flow.R` 작성 완료
   - ✅ 전체 CVC workflow 구현:
     1. 데이터 로딩
     2. 전처리 (US only, Angel 제외)
     3. Lead VC 식별
     4. Case-Control 샘플링 (1:10)
     5. 네트워크 중심성 계산
     6. 변수 생성
     7. 통계 분석 (clogit 모델)

4. **테스트 실행**
   - ✅ 백그라운드 실행 시작 (PID: 86076)
   - ✅ 로그 파일: `logs/full_execution.log`

---

## 🔍 주요 발견사항 (코드 비교)

### 리팩토링 코드의 개선사항

| 항목 | 원본 | 리팩토링 | 개선 여부 |
|------|------|----------|-----------|
| 네트워크 생성 | 기본 로직 | + overlap 체크 | ✅ 개선 |
| 중심성 계산 | 기본 로직 | + 에러 처리, ego_density | ✅ 개선 |
| 샘플링 로직 | 완전함 | 동일 | ✅ 동일 |
| Lead VC 식별 | 완전함 | 동일 | ✅ 동일 |
| Exit 변수 | 완전함 | 동일 | ✅ 동일 |
| **IPO 변수** | ❌ **버그** (`exit` 사용) | ✅ **수정** (`ipoExit` 사용) | ✅ 개선 |
| **M&A 변수** | ❌ **버그** (`exit` 사용) | ✅ **수정** (`MnAExit` 사용) | ✅ 개선 |

### 원본 코드의 버그 (수정됨)

```r
# 원본 CVC_preprcs_v4.R (Line 508-527)
VC_IPO_num <- function(...){
  # ...
  mutate(ipoNum = sum(exit)) %>%  # ❌ 잘못됨! ipoExit 사용해야 함
}

VC_MnA_num <- function(...){
  # ...
  mutate(MnANum = sum(exit)) %>%  # ❌ 잘못됨! MnAExit 사용해야 함
}
```

```r
# 리팩토링 코드 (R/analysis/performance_analysis.R)
VC_IPO_num <- function(...){
  # ...
  mutate(ipoNum = sum(ipoExit)) %>%  # ✅ 수정됨!
}

VC_MnA_num <- function(...){
  # ...
  mutate(MnANum = sum(MnAExit)) %>%  # ✅ 수정됨!
}
```

---

## 🧪 테스트 구성

### 데이터 범위
- **연도**: 1985-2000 (테스트용으로 축소)
- **샘플링 비율**: 1:10
- **Time window**: 5년
- **Edge cutpoint**: 5

### 테스트 단계

1. **STEP 1: 데이터 로딩**
   - Company data: 63,233 rows
   - Firm data: 15,779 rows
   - Round data: 414,836 rows
   - Fund data: 39,334 rows

2. **STEP 2: 데이터 전처리**
   - US only 필터링
   - Angel 그룹 제외
   - 음수 firm age 제외
   - Quarter & Event 생성

3. **STEP 3: Lead VC 식별**
   - 3가지 기준 사용:
     1. 첫 라운드 투자
     2. 투자 비율
     3. 투자 금액

4. **STEP 4: Case-Control 샘플링**
   - 1:10 비율
   - Quarter별 샘플링

5. **STEP 5: 중심성 계산**
   - 병렬 처리 (6 코어)
   - 5년 window
   - Degree, Betweenness, Power, Constraint 계산

6. **STEP 6: 변수 생성**
   - Dyad type variables (both_prv, both_cvc, prvcvc)
   - Power asymmetry variables
   - Log transformations

7. **STEP 7: 통계 분석**
   - Model 0: Base model
   - Model 1: VC type effect
   - Model 2: both_prv interaction
   - Model 3: prvcvc interaction

---

## 📊 예상 산출물

### 데이터 파일 (`testing_results/cvc_flow/data/`)
- `round_preprocessed.csv` - 전처리된 라운드 데이터
- `edgeRound.csv` - 네트워크 edge 데이터
- `leadVC_data.csv` - Lead VC 식별 결과
- `sampling_data.csv` - 샘플링 결과
- `centrality_data.csv` - 중심성 계산 결과
- `final_cvc_data.csv` - 최종 분석 데이터셋

### 결과 파일 (`testing_results/cvc_flow/results/`)
- `descriptive_stats.csv` - 기술통계
- `correlation_matrix.csv` - 상관관계 행렬
- `model_0_results.csv` - Base 모델 결과
- `model_1_results.csv` - Model 1 결과
- `model_2_results.csv` - Model 2 결과
- `model_3_results.csv` - Model 3 결과

### 로그 파일 (`testing_results/cvc_flow/logs/`)
- `full_execution.log` - 전체 실행 로그
- `cvc_test_YYYYMMDD.log` - 상세 로그

---

## 🔄 진행 상황 모니터링

### 로그 확인 명령어
```bash
# 실시간 로그 확인
tail -f /Users/suengj/Documents/Code/Python/Research/VC/testing_results/cvc_flow/logs/full_execution.log

# 로그 마지막 50줄 확인
tail -50 /Users/suengj/Documents/Code/Python/Research/VC/testing_results/cvc_flow/logs/full_execution.log

# 프로세스 확인
ps aux | grep "Rscript test_cvc_full_flow.R"
```

### 현재 상태
- 🟢 프로세스 실행 중 (PID: 86076)
- 📊 데이터 로딩 완료 (18.17초)
- ⏳ 전처리 진행 중...

---

## ✅ 검증 체크리스트

### 코드 검증
- [x] 원본 코드와 로직 비교
- [x] 버그 수정 확인
- [x] 함수 완전성 확인
- [ ] 실행 결과 검증 (진행 중)

### 데이터 검증
- [ ] 데이터 크기 일치
- [ ] 주요 변수 분포 확인
- [ ] 네트워크 통계량 확인

### 통계 분석 검증
- [ ] 모델 수렴 확인
- [ ] 계수 부호 일치
- [ ] 모델 적합도 확인

---

## 📝 다음 단계

1. ⏳ **CVC Flow 테스트 완료 대기** (현재 진행 중)
2. 📊 **결과 검증**
   - 데이터 파일 확인
   - 통계 결과 확인
   - 원본과 비교
3. 📄 **최종 보고서 작성**
   - 테스팅 결과 요약
   - 성능 비교
   - 개선 권장사항

---

## 💡 참고사항

### 실행 시간 예상
- 전처리: ~5분
- Lead VC 식별: ~10분
- 샘플링: ~30-60분 (quarter별)
- 중심성 계산: ~15-30분 (병렬 처리)
- 변수 생성: ~5분
- 통계 분석: ~5분
- **총 예상 시간: 약 70-115분 (1.2-2시간)**

### 주의사항
- 샘플링 단계가 가장 시간이 오래 걸림
- 메모리 사용량 주의 (대용량 데이터)
- 병렬 처리로 CPU 80% 사용

---

## 📞 문의사항

진행 상황 확인이 필요하거나 에러 발생 시:
1. 로그 파일 확인: `logs/full_execution.log`
2. 프로세스 상태 확인: `ps aux | grep Rscript`
3. 중간 결과 확인: `data/` 폴더의 csv 파일들

---

**Last Updated**: 2025-10-11 23:14 KST
**Status**: 🟢 테스트 실행 중 (백그라운드)
**PID**: 86076

