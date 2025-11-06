# CVC Code Comparison Report
# 원본 vs 리팩토링 코드 비교 분석

Date: 2025-10-11
Comparison: CVC_preprcs_v4.R vs refactor/R/*

---

## 🔍 핵심 함수 비교

### 1. VC_matrix() - 네트워크 생성

#### 원본 (CVC_preprcs_v4.R, Line 92-111)
```r
VC_matrix <- function(round, year, time_window = NULL, edge_cutpoint = NULL) {
  if(!is.null(time_window)) {
    edgelist <- round[round$year <= year-1 & round$year >= year-time_window, 
                      c("firmname", "event")]
  } else {
    edgelist <- round[round$year == year-1, c("firmname", "event")]
  }
  
  twomode <- graph_from_edgelist(as.matrix(edgelist), directed = FALSE)
  V(twomode)$type <- V(twomode)$name %in% edgelist[,2]
  onemode <- bipartite_projection(twomode)$proj1
  
  return(onemode)
}
```

#### 리팩토링 (R/core/network_construction.R, Line 16-68)
```r
VC_matrix <- function(round, year, time_window = NULL, edge_cutpoint = NULL, timewave_unit = "year") {
  # 추가된 디버깅 메시지
  # 추가된 timewave_unit 파라미터
  # 추가된 overlap 체크 및 prefix 추가 로직
  
  if(!is.null(time_window)) {
    edgelist <- round[round$year <= year-1 & round$year >= year-time_window,
                      c("firmname", "event")]
  } else {
    edgelist <- round[round$year == year-1, c("firmname", "event")]
  }
  
  # 중복 체크 로직 추가
  overlap <- intersect(firmnames, events)
  if (length(overlap) > 0) {
    edgelist[,2] <- paste0("event_", edgelist[,2])
  }
  
  twomode <- graph_from_edgelist(as.matrix(edgelist), directed = FALSE)
  V(twomode)$type <- V(twomode)$name %in% edgelist[,2]
  onemode <- bipartite_projection(twomode)$proj1
  
  return(onemode)
}
```

**차이점:**
- ✅ 리팩토링 코드에 overlap 체크 추가 (더 안전함)
- ✅ timewave_unit 파라미터 추가 (더 유연함)
- ⚠️ 디버깅 메시지는 production에서 제거 필요

**판정:** 리팩토링 코드가 더 robust함 ✅

---

### 2. VC_centralities() - 중심성 계산

#### 원본 (CVC_preprcs_v4.R, Line 124-153)
```r
VC_centralities <- function(round, year, time_window, edge_cutpoint) {
  adjmatrix <- VC_matrix(round, year, time_window, edge_cutpoint)
  
  upsilon <- max(eigen(as_adjacency_matrix(adjmatrix))$values)
  
  dgr_cent     <- degree(adjmatrix)
  btw_cent <- betweenness(adjmatrix)
  pwr_p75  <- power_centrality(adjmatrix, exponent = (1/upsilon)*0.75)
  pwr_max <- power_centrality(adjmatrix, exponent = 1/upsilon*(1 - 10^-10))
  pwr_zero  <- power_centrality(adjmatrix, exponent = 0)
  constraint_value <- constraint(adjmatrix)
  
  result <- data.table(cbind(dgr_cent, btw_cent, pwr_p75, pwr_max, pwr_zero,
                             constraint_value), keep.rownames = TRUE)
  
  return(result)
}
```

#### 리팩토링 (R/core/centrality_calculation.R, Line 16-88)
```r
VC_centralities <- function(round, year, time_window, edge_cutpoint) {
  adjmatrix <- VC_matrix(round, year, time_window, edge_cutpoint)
  
  # 빈 네트워크 체크 추가
  if (vcount(adjmatrix) == 0) {
    return(data.frame())
  }
  
  upsilon <- max(eigen(as_adjacency_matrix(adjmatrix))$values)
  
  dgr_cent <- degree(adjmatrix)
  btw_cent <- betweenness(adjmatrix)
  
  # tryCatch 추가로 에러 처리
  tryCatch({
    pwr_p75  <- power_centrality(adjmatrix, exponent = (1/upsilon)*0.75)
  }, error = function(e) {
    pwr_p75 <<- rep(0, vcount(adjmatrix))
  })
  
  # ... (다른 power centrality도 동일)
  
  constraint_value <- constraint(adjmatrix)
  
  # ego network 추가
  egonet_list <- make_ego_graph(adjmatrix)
  ego_dta <- data.frame(
    firmname = names(V(adjmatrix)),
    ego_density = lapply(egonet_list, graph.density) %>% unlist()
  )
  
  # 벡터 길이 맞춤
  cent_dta <- data.table(
    year = rep(year, length(dgr_cent)),
    firmname = names(V(adjmatrix)),
    dgr_cent = dgr_cent, 
    btw_cent = btw_cent,
    ...
  )
  
  result <- merge(cent_dta, ego_dta, by="firmname", all.x=TRUE)
  
  return(result)
}
```

**차이점:**
- ✅ 빈 네트워크 체크 추가 (에러 방지)
- ✅ tryCatch로 power centrality 에러 처리
- ✅ ego_density 추가 (imprinting 분석에 필요)
- ✅ 벡터 길이 문제 해결 (rep(year, length(dgr_cent)))
- ⚠️ 원본에서는 ego_density 없음 (CVC 분석에는 불필요할 수도)

**판정:** 리팩토링 코드가 더 robust하고 완전함 ✅

---

### 3. VC_sampling_opt1() - 샘플링 로직

#### 원본 (CVC_preprcs_v4.R, Line 158-202)
```r
VC_sampling_opt1 <- function(v_dta, v_coVC_unique, ratio){
  v_dta <- v_dta %>% unique()
  
  df_all_ties <- data.frame(coVC = v_coVC_unique$coVC, 
                            leadVC = v_dta$leadVC[1],
                            comname = v_dta$comname[1]) %>% as_tibble()
  
  df_all_ties <- left_join(df_all_ties, 
                           v_dta %>% select(coVC, realized),
                           by="coVC")
  
  df_all_ties <- df_all_ties %>%
    mutate(realized = replace_na(realized,0)) %>%
    filter(coVC != leadVC)
  
  df_realized_ties <- df_all_ties %>% filter(realized==1)
  df_unrealized_ties <- df_all_ties %>% filter(realized==0)
  
  set.seed(123)
  if(ratio*NROW(df_realized_ties) >= NROW(df_unrealized_ties)){
    df_unrealized_ties <- df_unrealized_ties %>% 
      sample_n(ratio*NROW(df_realized_ties), replace = TRUE)
  } else {
    df_unrealized_ties <- df_unrealized_ties %>%
      sample_n(ratio*NROW(df_realized_ties))
  }
  
  cc_dta <- bind_rows(df_realized_ties, df_unrealized_ties)
  return(cc_dta)
}
```

#### 리팩토링 (R/core/sampling.R)
```r
# 동일한 로직 구현됨
```

**차이점:**
- ✅ 로직 동일함

**판정:** 동일 ✅

---

### 4. leadVC_identifier() - Lead VC 식별

#### 원본 (CVC_preprcs_v4.R, Line 279-339)
```r
leadVC_identifier <- function(data){
  set.seed(123)
  
  LeadVCdta <- data %>% 
    add_count(comname) %>%
    rename(comInvested = n) %>%
    mutate(RoundNumber = replace_na(RoundNumber, 9999)) %>%
    
    group_by(comname) %>%
    mutate(FirstRound = +(RoundNumber == min(RoundNumber))) %>%
    ungroup() %>%
    
    add_count(firmname, comname) %>%
    rename(firm_comInvested = n) %>%
    mutate(firm_inv_ratio = firm_comInvested / comInvested) %>%
    
    mutate(RoundAmountDisclosedThou = replace_na(RoundAmountDisclosedThou, 0),
           RoundAmountEstimatedThou = replace_na(RoundAmountEstimatedThou, 0),
           RoundAmount = ifelse(RoundAmountDisclosedThou >= RoundAmountEstimatedThou,
                                RoundAmountDisclosedThou,
                                RoundAmountEstimatedThou)) %>%
    
    group_by(firmname, comname) %>%
    mutate(TotalAmountPerCompany = sum(RoundAmount)) %>%
    
    select(year, firmname, comname, comInvested, FirstRound, firm_inv_ratio, 
           RoundAmount, TotalAmountPerCompany) %>%
    
    group_by(comname) %>%
    mutate(leadVC1 = +(FirstRound ==1),
           leadVC2 = +(firm_inv_ratio == max(firm_inv_ratio)),
           leadVC3 = +(TotalAmountPerCompany == max(TotalAmountPerCompany))) %>%
    
    mutate(leadVCsum = leadVC1 + leadVC2 + leadVC3) %>%
    
    mutate(leadVC1_multi = sum(leadVC1),
           leadVC2_multi = sum(leadVC2),
           leadVC3_multi = sum(leadVC3)) %>% 
    
    mutate(leadVC = ifelse(leadVC1 ==1 & leadVC1_multi ==1,1,
                           ifelse(leadVC1 == 1 & leadVC2==1 & leadVC2_multi ==1,1,
                                  ifelse(leadVC1==1 & leadVC2==1 & leadVC3==1, 1,
                                         +(leadVC1 == 1 & max(leadVCsum) == leadVCsum))))) %>%
    
    ungroup() %>%
    
    select(firmname, comname, leadVC) %>% 
    filter(leadVC==1) %>%
    unique() %>%
    
    group_by(comname) %>%
    slice_sample(n=1)
  
  return(LeadVCdta)
}
```

#### 리팩토링 (R/core/data_processing.R, Line 31-92)
```r
# 동일한 로직 구현됨
```

**차이점:**
- ✅ 로직 완전 동일함

**판정:** 동일 ✅

---

### 5. Performance 변수 생성

#### 원본 (CVC_preprcs_v4.R, Line 487-549)
```r
VC_exit_num <- function(r_df, c_df, v_yr, yr_cut=5){
  tmp <- r_df %>% 
    filter(year >= v_yr-yr_cut & year < v_yr) %>%
    mutate(newyr = v_yr) %>%
    select(firmname, year, newyr, comname)
  
  tmp <- left_join(tmp, c_df,
                   by=c("comname"="comname",
                        "year"="situ_yr"))
  
  tmp <- tmp %>% 
    mutate(across(starts_with("exit"), ~replace_na(.x,0))) %>%
    group_by(firmname) %>%
    mutate(exitNum = sum(exit)) %>%
    select(firmname, newyr, exitNum) %>% 
    unique()
  
  return(tmp)
}

VC_IPO_num <- function(...){
  # ... sum(exit) 사용 (잘못됨!)
  mutate(ipoNum = sum(exit)) %>%
}

VC_MnA_num <- function(...){
  # ... sum(exit) 사용 (잘못됨!)
  mutate(MnANum = sum(exit)) %>%
}
```

#### 리팩토링 (R/analysis/performance_analysis.R, Line 44-93)
```r
VC_IPO_num <- function(r_df, c_df, v_yr, yr_cut=5){
  # ...
  tmp %>% 
    mutate(across(starts_with("exit"), ~replace_na(.x,0))) %>%
    group_by(firmname) %>%
    mutate(ipoNum = sum(ipoExit)) %>%  # ✅ 수정됨!
    # ...
}

VC_MnA_num <- function(r_df, c_df, v_yr, yr_cut=5){
  # ...
  tmp %>% 
    mutate(across(starts_with("exit"), ~replace_na(.x,0))) %>%
    group_by(firmname) %>%
    mutate(MnANum = sum(MnAExit)) %>%  # ✅ 수정됨!
    # ...
}
```

**차이점:**
- ✅ **원본 버그 수정됨!** IPO/M&A 함수에서 `exit` 대신 `ipoExit`/`MnAExit` 사용
- ✅ ERROR_MEMO.md에 이미 문서화되어 있음

**판정:** 리팩토링 코드가 원본 버그 수정함 ✅

---

## 📊 주요 차이점 요약

| 항목 | 원본 | 리팩토링 | 판정 |
|------|------|----------|------|
| 네트워크 생성 | 기본 로직 | + overlap 체크 | ✅ 개선됨 |
| 중심성 계산 | 기본 로직 | + 에러 처리, ego_density | ✅ 개선됨 |
| 샘플링 로직 | 완전함 | 동일 | ✅ 동일 |
| Lead VC 식별 | 완전함 | 동일 | ✅ 동일 |
| Exit 변수 | 버그 있음 | 수정됨 | ✅ 개선됨 |
| IPO 변수 | **버그** (`exit` 사용) | **수정** (`ipoExit` 사용) | ✅ 개선됨 |
| M&A 변수 | **버그** (`exit` 사용) | **수정** (`MnAExit` 사용) | ✅ 개선됨 |

---

## ✅ 결론

### 리팩토링 코드의 개선사항:
1. ✅ **버그 수정**: IPO/M&A 함수의 변수 사용 오류 수정
2. ✅ **안정성 향상**: 에러 처리 (tryCatch, 빈 네트워크 체크)
3. ✅ **기능 추가**: ego_density, overlap 체크
4. ✅ **로직 동일**: 핵심 알고리즘은 원본과 동일

### 추가 확인 필요사항:
1. ⚠️ Industry distance 계산 로직
2. ⚠️ Geographic distance 계산 로직
3. ⚠️ Network distance 계산 로직

### 권장사항:
- **리팩토링 코드 사용 권장** (원본 버그 수정됨)
- 디버깅 메시지는 production에서 제거 고려
- 전체 flow 테스팅으로 검증 필요

---

## 🔍 다음 단계: CVC Flow 전체 테스팅

원본 CVC_preprcs_v4.R의 전체 flow를 리팩토링된 코드로 재현하여 결과 비교 필요.







