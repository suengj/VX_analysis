# CVC analysis part
# Suengjae Hong
# must follow CVC_preprcs.R 

# load data
setwd(wd[1])

sample_ratio <- 10
loadDate <- "23Mar25"

dta <- read_fst(
  paste0('dta_',loadDate,'_',sample_ratio,'.fst')
)

# [ ANALYSIS ] ----
# create log variables
dta <- dta %>%
  mutate(ln_coVC_age = log(coVC_age+1),
         ln_coVC_totalInv = log(coVC_totalInv+1),
         ln_coVC_AmtInv = log(coVC_AmtInv+1),
         ln_coVC_exitNum = log(coVC_exitNum+1),
         ln_VC_zipdist = log(VC_zipdist+1),
         ln_coVC_com_zipdist = log(coVC_com_zipdist+1),
         ln_coVC_fundcnt = log(coVC_fundcnt+1))

# 2. descriptive table ----
real_summTable <- psych::describe(dta %>% 
                                    filter(realized==1) %>%
                                    select(realized, ln_coVC_age, 
                                           ln_coVC_totalInv, ln_coVC_AmtInv, ln_coVC_exitNum, ln_coVC_fundcnt,
                                           indDist, coVC_comDist1, coVC_blau, geoDist1,
                                           ln_VC_zipdist, ln_coVC_com_zipdist,
                                           bp_abs_dis_max,
                                           both_prv, prvcvc, both_cvc, hsacvc, hsapvc), fast=TRUE)

unreal_summTable <- psych::describe(dta %>% 
                                      filter(realized==0) %>%
                                      select(realized, ln_coVC_age, 
                                             ln_coVC_totalInv, ln_coVC_AmtInv, ln_coVC_exitNum, ln_coVC_fundcnt,
                                             indDist, coVC_comDist1, coVC_blau, geoDist1,
                                             ln_VC_zipdist, ln_coVC_com_zipdist,
                                             bp_abs_dis_max,
                                             both_prv, prvcvc, both_cvc, hsacvc, hsapvc), fast=TRUE)


summTable <- psych::describe(dta %>% 
                               select(realized, ln_coVC_age, 
                                      ln_coVC_totalInv, ln_coVC_AmtInv, ln_coVC_exitNum, ln_coVC_fundcnt,
                                      indDist, coVC_comDist1, coVC_blau, geoDist1,
                                      ln_VC_zipdist, ln_coVC_com_zipdist,
                                      bp_abs_dis_max,
                                      both_prv, prvcvc, both_cvc, hsacvc, hsapvc), fast=TRUE)


# 2-1. Welch Two sample t-test ----
varnm_list <- c('ln_coVC_age', 
                'ln_coVC_totalInv', 'ln_coVC_AmtInv', 'ln_coVC_exitNum', 'ln_coVC_fundcnt',
                'indDist', 'coVC_comDist1', 'coVC_blau', 'geoDist1',
                'ln_VC_zipdist', 'ln_coVC_com_zipdist',
                'bp_abs_dis_max',
                'both_prv', 'prvcvc', 'both_cvc', 'hsacvc', 'hsapvc')

ttest_list <- list()

for(i in seq_along(varnm_list)){
  ttest_list[[i]] <- welch_t_test(dta, realized, varnm_list[i])
  
}

t.test.rst <- do.call("rbind", ttest_list)
t.test.rst <- as.data.frame(t.test.rst)



# 3. corr table ----
corr <- dta %>% 
  select(realized, ln_coVC_age, 
         ln_coVC_totalInv, ln_coVC_AmtInv, ln_coVC_exitNum, ln_coVC_fundcnt,
         indDist, coVC_comDist1, coVC_blau, geoDist1,
         ln_VC_zipdist, ln_coVC_com_zipdist,
         bp_abs_dis_max,
         both_prv, prvcvc, both_cvc, hsacvc, hsapvc) %>%
  drop_na()

pwcorr <- Hmisc::rcorr(as.matrix(corr))

# 4. test hypotheses ----
# 4-0. Base model ====
model_0 <- survival::clogit(realized ~ log(coVC_age+1)+log(coVC_totalInv+1)+ 
                              indDist + coVC_comDist1+ log(coVC_AmtInv+1) + geoDist1 + log(coVC_exitNum+1) +
                              log(VC_zipdist+1)+log(coVC_com_zipdist+1) + log(coVC_fundcnt+1)+
                              strata(synd_lv),
                            dta, 
                            method="approximate")

summary(model_0); # car::vif(model_0); support.CEs::gofm(model_0)

# 4-1. Hypothesis 1 ====
model_1 <- survival::clogit(realized ~ factor(coVC_type) + log(coVC_age+1)+log(coVC_totalInv+1)+ coVC_blau + 
                              indDist + coVC_comDist1+ log(coVC_AmtInv+1) + geoDist1 + log(coVC_exitNum+1) +
                              log(VC_zipdist+1)+log(coVC_com_zipdist+1) + log(coVC_fundcnt+1)+
                              z_bp_abs_dis_max + strata(synd_lv),
                            dta, 
                            method="approximate")

summary(model_1); # car::vif(model_1); support.CEs::gofm(model_1)

# 4-2. Hypothesis 2 ====
model_2 <- survival::clogit(realized ~ factor(coVC_type) + log(coVC_age+1)+log(coVC_totalInv+1)+ coVC_blau +
                              indDist + coVC_comDist1+ log(coVC_AmtInv+1) + geoDist1 + log(coVC_exitNum+1) +
                              log(VC_zipdist+1)+log(coVC_com_zipdist+1) + log(coVC_fundcnt+1)+
                              both_prv*z_bp_abs_dis_max + strata(synd_lv),
                            dta, 
                            method="approximate")

summary(model_2); # car::vif(model_2); support.CEs::gofm(model_2)

# 4-3. Hypothesis 3 ====
model_3 <- survival::clogit(realized ~ factor(coVC_type) + log(coVC_age+1)+log(coVC_totalInv+1)+ coVC_blau +
                              indDist + coVC_comDist1+ log(coVC_AmtInv+1) + geoDist1 + log(coVC_exitNum+1) +
                              log(VC_zipdist+1)+log(coVC_com_zipdist+1) + log(coVC_fundcnt+1)+
                              prvcvc*z_bp_abs_dis_max + strata(synd_lv),
                            dta, 
                            method="approximate")

summary(model_3); # car::vif(model_3); support.CEs::gofm(model_3)


# 4-3. Hypothesis 3a ====
model_3a <- survival::clogit(realized ~ factor(coVC_type) + log(coVC_age+1)+log(coVC_totalInv+1)+ coVC_blau +
                               indDist + coVC_comDist1+ log(coVC_AmtInv+1) + geoDist1 + log(coVC_exitNum+1) +
                               log(VC_zipdist+1)+log(coVC_com_zipdist+1) + log(coVC_fundcnt+1)+
                               hsacvc*bp_abs_dis_max + strata(synd_lv),
                             dta, 
                             method="approximate")

summary(model_3a); # car::vif(model_3a); support.CEs::gofm(model_3a)


# 4-3. Hypothesis 3b ====
model_3b <- survival::clogit(realized ~ factor(coVC_type) + log(coVC_age+1)+log(coVC_totalInv+1)+ coVC_blau +
                               indDist + coVC_comDist1+ log(coVC_AmtInv+1) + geoDist1 + log(coVC_exitNum+1) +
                               log(VC_zipdist+1)+log(coVC_com_zipdist+1) + log(coVC_fundcnt+1)+
                               hsapvc*bp_abs_dis_max + strata(synd_lv),
                             dta, 
                             method="approximate")

summary(model_3b); # car::vif(model_3b); support.CEs::gofm(model_3b)


# 4-3. Hypothesis 3a+b ====
model_3ab <- survival::clogit(realized ~ factor(coVC_type) + log(coVC_age+1)+log(coVC_totalInv+1)+ coVC_blau +
                                indDist + coVC_comDist1+ log(coVC_AmtInv+1) + geoDist1 + log(coVC_exitNum+1) +
                                log(VC_zipdist+1)+log(coVC_com_zipdist+1) + log(coVC_fundcnt+1)+
                                (both_prv + prvcvc)*bp_abs_dis_max + strata(synd_lv),
                              dta, 
                              method="approximate")

summary(model_3ab); # car::vif(model_3ab); support.CEs::gofm(model_3ab)


# 4-4. visualizaton ====
model_vis <- survival::clogit(realized ~ log(coVC_age+1)+log(coVC_totalInv+1) +
                                indDist + coVC_comDist1+ log(coVC_AmtInv+1) + geoDist1 + log(coVC_exitNum+1) +
                                log(VC_zipdist+1)+log(coVC_com_zipdist+1) + log(coVC_fundcnt+1)+
                                dyad_cat3*bp_abs_dis_max + strata(synd_lv),
                              dta, 
                              method="approximate")

summary(model_vis)

# 5. Testing vif & Condition Index ====
# ref: https://www.ibm.com/support/pages/multicollinearity-diagnostics-logistic-regression-nomreg-or-plum
# ref: https://statisticalhorizons.com/multicollinearity/
model_vif <- lm(realized ~ log(coVC_age+1) + indDist + coVC_comDist1 + 
                  log(coVC_totalInv+1)+ log(coVC_AmtInv+1)+ 
                  geoDist1 + log(coVC_exitNum+1) +
                  log(VC_zipdist+1)+log(coVC_com_zipdist+1)+log(coVC_fundcnt+1)+
                  both_prv + prvcvc + bp_abs_dis_max,
                dta)

ols_vif_tol(model_vif) # VIF
ols_eigen_cindex(model_vif) # condition index

# both_prv == 85%
# hsacvc OR hsaprv == 14.7%
# both_cvc == 0.3%

# 6. Vis modeling ===
vis_m <- glmer(realized ~ factor(coVC_type) + log(coVC_age+1)+log(coVC_totalInv+1)+ coVC_blau +
                 indDist + coVC_comDist1+ log(coVC_AmtInv+1) + geoDist1 + log(coVC_exitNum+1) +
                 log(VC_zipdist+1)+log(coVC_com_zipdist+1) + log(coVC_fundcnt+1)+
                 hsapvc*bp_abs_dis_max + (1|synd_lv),
               data=clust_dta,
               family="binomial")

summary(vis_m)

# 6. save results ====
setwd(wd[3])

tcorr <- broom::tidy(pwcorr); 
tidy0 <- broom::tidy(model_0); tidy1 <- broom::tidy(model_1); tidy2 <- broom::tidy(model_2)
tidy3 <- broom::tidy(model_3); tidy3a <- broom::tidy(model_3a); tidy3b <- broom::tidy(model_3b); tidy3ab <- broom::tidy(model_3ab)

tvif0 <- broom::tidy(car::vif(model_0))
tvif1 <- broom::tidy(car::vif(model_1))
tvif2 <- broom::tidy(car::vif(model_2))
tvif3 <- broom::tidy(car::vif(model_3))
tvif3a <- broom::tidy(car::vif(model_3a))
tvif3b <- broom::tidy(car::vif(model_3b))
tvif3ab <-broom::tidy(car::vif(model_3ab))

# model fits (R^2)
m0_r2 <- gofm(model_0)$RHO2; m1_r2 <- gofm(model_1)$RHO2; m2_r2 <- gofm(model_2)$RHO2
m3_r2 <- gofm(model_3)$RHO2;
m3a_r2 <- gofm(model_3a)$RHO2; m3b_r2 <- gofm(model_3b)$RHO2; m3ab_r2 <- gofm(model_3ab)$RHO2

# Log likelhood
m0_log <- gofm(model_0)$LL0 - gofm(model_0)$LLb
m1_log <- gofm(model_1)$LL0 - gofm(model_1)$LLb
m2_log <- gofm(model_2)$LL0 - gofm(model_2)$LLb
m3_log <- gofm(model_3)$LL0 - gofm(model_3)$LLb
m3a_log <- gofm(model_3a)$LL0 - gofm(model_3a)$LLb
m3b_log <- gofm(model_3b)$LL0 - gofm(model_3b)$LLb
m3ab_log <- gofm(model_3ab)$LL0 - gofm(model_3ab)$LLb

# results
model_fit <- data.frame(rho = rbind(m0_r2, m1_r2, m2_r2, m3_r2, m3a_r2, m3b_r2, m3ab_r2),
                        loglike = rbind(m0_log, m1_log, m2_log, m3_log, m3a_log, m3b_log, m3ab_log))

# save results
filenm <- c("Mar25_rst_sample10.xlsx")
xlsx::write.xlsx(real_summTable, file=filenm, sheetName="summary (case)")
xlsx::write.xlsx(unreal_summTable, file=filenm, sheetName="summary (control)", append=TRUE)
xlsx::write.xlsx(summTable, file=filenm, sheetName="summary (all)", append=TRUE)
xlsx::write.xlsx(t.test.rst, file=filenm, sheetName = "t_test", append=TRUE)
xlsx::write.xlsx(pwcorr$r, file=filenm, sheetName = "corr_r", append=TRUE)
xlsx::write.xlsx(pwcorr$P, file=filenm, sheetName = "corr_p", append=TRUE)
xlsx::write.xlsx(tcorr, file=filenm, sheetName = "corr", append=TRUE)
xlsx::write.xlsx(tidy0, file=filenm, sheetName = "base", append=TRUE)
xlsx::write.xlsx(tvif0, file=filenm, sheetName = "base (vif)", append=TRUE)
xlsx::write.xlsx(tidy1, file=filenm, sheetName = "hyp1", append=TRUE)
xlsx::write.xlsx(tvif1, file=filenm, sheetName = "hyp1 (vif)", append=TRUE)
xlsx::write.xlsx(tidy2, file=filenm, sheetName = "hyp2", append=TRUE)
xlsx::write.xlsx(tvif2, file=filenm, sheetName = "hyp2 (vif)", append=TRUE)
xlsx::write.xlsx(tidy3, file=filenm, sheetName = "hyp3", append=TRUE)
xlsx::write.xlsx(tvif3, file=filenm, sheetName = "hyp3 (vif)", append=TRUE)
xlsx::write.xlsx(tidy3a, file=filenm, sheetName = "hyp3a", append=TRUE)
xlsx::write.xlsx(tvif3a, file=filenm, sheetName = "hyp3a (vif)", append=TRUE)
xlsx::write.xlsx(tidy3b, file=filenm, sheetName = "hyp3b", append=TRUE)
xlsx::write.xlsx(tvif3b, file=filenm, sheetName = "hyp3b (vif)", append=TRUE)
xlsx::write.xlsx(tidy3ab, file=filenm, sheetName = "hyp3ab", append=TRUE)
xlsx::write.xlsx(tvif3ab, file=filenm, sheetName = "hyp3ab (vif)", append=TRUE)
xlsx::write.xlsx(model_fit, file=filenm, sheetName = "model fit", append=TRUE)


setwd(wd[1])


### [[[ END OF CODE ]]] ----















# 7. testing temp ideas ----

model_tmp <- survival::clogit(realized ~ 
                                indDist + log(coVC_AmtInv+1) + geoDist1 + log(coVC_exitNum+1) +
                                mc_bp_dis_max + strata(synd_lv),
                              dta, 
                              method="approximate")

summary(model_tmp); support.CEs::gofm(model_tmp)


model_tmp <- survival::clogit(realized ~ upwardTie +
                                indDist + log(coVC_AmtInv+1) + geoDist1 + log(coVC_exitNum+1) +
                                mc_bp_dis_max*both_prv + strata(synd_lv),
                              dta, 
                              method="approximate")

summary(model_tmp); support.CEs::gofm(model_tmp)


model_tmp <- survival::clogit(realized ~ upwardTie + 
                                indDist + log(coVC_AmtInv+1) + geoDist1 + log(coVC_exitNum+1) +
                                mc_bp_dis_max*hsacvc*leadcvc.coivc + strata(synd_lv),
                              dta, 
                              method="approximate")

summary(model_tmp); support.CEs::gofm(model_tmp)


model_tmp <- survival::clogit(realized ~ upwardTie +
                                indDist + log(coVC_AmtInv+1) + geoDist1 + log(coVC_exitNum+1) +
                                bp_asy_max*hsacvc*leadcvc.coivc + strata(synd_lv),
                              dta, 
                              method="approximate")

summary(model_tmp); support.CEs::gofm(model_tmp)

# vif
test_vif <- lm(realized ~ indDist + log(coVC_AmtInv+1)+ geoDist1 + log(coVC_exitNum+1) +
                 both_prv + leadcvc.coivc + leadivc.cocvc + hsacvc + mc_bp_dis_max,
               dta)

ols_vif_tol(test_vif) # VIF
ols_eigen_cindex(test_vif) # condition index

# 4-x. Hypothesis x ====

model_x <- survival::clogit(realized ~ upwardTie + coVC_max 
                            + indDist  + log(coVC_AmtInv+1)+ geoDist1 + log(coVC_exitNum+1) +
                              mc_bp_abs_dis_max + strata(synd_lv),
                            dta, 
                            method="approximate")

summary(model_x); car::vif(model_x)

model_y <- survival::clogit(realized ~ 
                              indDist  + log(coVC_AmtInv+1)+ geoDist1 + log(coVC_exitNum+1) +
                              mc_bp_abs_dis_max*dyad_cat2 + strata(synd_lv),
                            dta, 
                            method="approximate")

summary(model_y);  car::vif(model_y)

# 4-4. Hypothesis 4 ====
model_4 <- survival::clogit(realized ~  upwardTie + coVC_max
                            + indDist + log(coVC_AmtInv+1)+ geoDist1 + log(coVC_exitNum+1) +
                              both_cvc*bp_abs_dis_max + strata(synd_lv),
                            dta, 
                            method="approximate")

summary(model_4); car::vif(model_4); gofm(model_4)



# 4. test hypotheses ----
# 4-0. Base model ====
model_0 <- survival::clogit(realized ~ upwardTie + coVC_max
                            + indDist + log(coVC_AmtInv+1) + geoDist1 + log(coVC_exitNum+1) +
                              strata(synd_lv),
                            dta, 
                            method="approximate")

summary(model_0); car::vif(model_0); support.CEs::gofm(model_0)

# 4-1. Hypothesis 1 ====
model_1 <- survival::clogit(realized ~ upwardTie + coVC_max 
                            + indDist  + log(coVC_AmtInv+1)+ geoDist1 + log(coVC_exitNum+1) +
                              bp_dis_max + strata(synd_lv),
                            dta, 
                            method="approximate")

summary(model_1); car::vif(model_1); support.CEs::gofm(model_1)

# 4-2. Hypothesis 2 ====
model_2 <- survival::clogit(realized ~ upwardTie + coVC_max
                            + indDist + log(coVC_AmtInv+1)+geoDist1 + log(coVC_exitNum+1) +
                              both_prv*bp_dis_max + strata(synd_lv),
                            dta, 
                            method="approximate")

summary(model_2); car::vif(model_2); support.CEs::gofm(model_2)

# 4-3. Hypothesis 3 ====
model_3 <- survival::clogit(realized ~  coVC_max
                            + indDist + log(coVC_AmtInv+1)+ geoDist1 + log(coVC_exitNum+1) +
                              both_cvc*bp_dis_max*upwardTie + strata(synd_lv),
                            dta, 
                            method="approximate")

summary(model_3); car::vif(model_3); support.CEs::gofm(model_3)

# 4-4. Hypothesis 4 ====
sampdta1 <- dta %>% filter(leadVC_cvc==1)
model_4 <- survival::clogit(realized ~  upwardTie + coVC_max
                            + indDist + log(coVC_AmtInv+1)+ geoDist1 + log(coVC_exitNum+1) +
                              coVC_cvc*bp_dis_max + strata(synd_lv),
                            dta, 
                            method="approximate")

summary(model_4); car::vif(model_4); gofm(model_4)





# model
model_0 <- glm(dv~factor(year) + log(nt_size_sum+1),
               data=dta,
               family='binomial'); summary(model_0)

model_1 <- glm(dv~factor(year) + log(nt_size_sum+1)
               + bp_d2_0,
               data=dta,
               family='binomial'); summary(model_1)

model_2 <- glm(dv~factor(year) + log(nt_size_sum+1) + both_prv*bp_d2_0,
               data=dta,
               family='binomial'); summary(model_2)

model_3 <- glm(dv~factor(year) + log(nt_size_sum+1) + both_cvc*bp_d2_0,
               data=dta,
               family='binomial'); summary(model_3)

model_4 <- glm(dv~factor(year) + log(nt_size_sum+1) + prvcvc*bp_d2_0,
               data=dta,
               family='binomial'); summary(model_4)


x <- left_join(round, corporatevc, by="firmname")



# Jan 12
dta <- dta %>%
  mutate(leadcvc.coivc = ifelse(leadVC_cvc==1 & coVC_cvc==0, 1, 0),
         leadivc.cocvc = ifelse(leadVC_cvc==0 & coVC_cvc==1, 1, 0))
