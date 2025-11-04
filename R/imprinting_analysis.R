## cont'd to imprinting mgmt R file
# Suengjae Hong
library("ggplot2")

# Setting -----
select <- dplyr::select

### working dir ####
wd <- c("/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Yang, Rhee, Ma/data",
        "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Yang, Rhee, Ma/results",
        "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Network Imprinting/dta",
        "/Users/suengj/Library/Mobile Documents/com~apple~CloudDocs/suengj/Academia/Research/03_project/00_Network Imprinting/rst")

### multi core ####
capacity <- 0.8
cores <- round(parallel::detectCores()*capacity,digits=0)
registerDoParallel(cores=cores)


# III. ANALYSIS ----
setwd(wd[3])

dtaYr <- 1

if(dtaYr==1){
  dta <- read_fst('dta_1yrPeriod.fst')
} else {
  dta <- read_fst('dta_3yrPeriod.fst')
}

# filtering only private VC
pdta <- dta %>% 
  filter(corpvc==0) %>% # remove corporate vc
  mutate(timesince = year - last_initial_tied,
         sample = ifelse(timesince >= 0,1,0),
         initial_age = initial_year - fnd_year,
         imprinted = ifelse(timesince < 8,1,0),
         after7 = ifelse(timesince > 7,1,0)) %>%
  filter(initial_year > 1989) %>% 
  filter(sample==1) %>% 
  filter(firmAge >=0) %>%
  filter(initial_age >=0) %>%
  filter(cons_value_1y <= 1) %>%
  filter(f_cons_value_1y <=1) %>%
  
  mutate(sh_1y = 1-cons_value_1y)

#  filter(sample==1) %>% 
#  mutate_all(function(x) ifelse(is.nan(x),1,x))

par(mfrow=c(1,1))
hist(pdta %>% select(timesince))
hist(pdta %>% select(firmAge))
hist(pdta %>% select(AnnVol))
hist(pdta %>% select(after7))
hist(pdta %>% select(NumExit))
hist(pdta %>% select(blau))
hist(pdta %>% select(InvestAMT))
hist(pdta %>% select(earlyStage))
hist(pdta %>% select(CAMA))
hist(pdta %>% select(initial_year))
hist(pdta %>% select(dgr_1y))
hist(pdta %>% select(pwr_max_5y))
hist(pdta %>% select(cons_value_1y))
hist(pdta %>% select(f_dgr_1y))
hist(pdta %>% select(f_pwr_max_5y))
hist(pdta %>% select(f_cons_value_1y))

# model test
# descr
summTable <- psych::describe(pdta %>% 
                               select(NumExit, AnnVol, earlyStage, blau, 
                                      InvestAMT, dgr_1y, sh_1y, pwr_max_5y,
                                      timesince, after7, firmAge, CAMA, initial_year,
                                      f_dgr_1y, f_cons_value_1y, p_pwr_max_5y) %>%
                               drop_na(),
                                      fast=TRUE)

# VIF
lm <- lm(formula = 
           NumExit ~ timesince +  log(firmAge+1) + AnnVol + after7 + 
           lag(NumExit) + lag(blau) + lag(log(InvestAMT+1)) + lag(earlyStage) + # other (t)
           CAMA + factor(initial_year) + # factor
           lag(dgr_1y) + lag(pwr_max_5y) + lag(sh_1y) + # network (t)
           
           f_dgr_1y +# initial focal level
           p_pwr_max_5y + f_cons_value_1y,
         data=pdta)

vif(lm)

# corr table
corr <- pdta %>% 
  ungroup() %>%
  select(NumExit, AnnVol, earlyStage, blau, 
         InvestAMT, dgr_1y, sh_1y, pwr_max_5y,
         timesince, after7, firmAge, CAMA, initial_year,
         f_dgr_1y, f_cons_value_1y, p_pwr_max_5y) %>%
  drop_na()

pwcorr <- rcorr(as.matrix(corr))

# pwcorr <- round(cor(corr),2)

# H0
model0 <- pglm(NumExit ~ 
                 AnnVol + lag(NumExit) + lag(earlyStage) + 
                 lag(blau) + lag(log(InvestAMT+1)) + 
                 lag(dgr_1y) + lag(sh_1y) + lag(pwr_max_5y) + 
                 timesince + after7 + log(firmAge+1) + 
                 CAMA + factor(initial_year) + # factor
                 f_dgr_1y, # initial focal level
               
               data=pdta,
               index=c("firmname","year"),
               family=negbin,
               model='random')

summary(model0)


# H1
model1 <- pglm(NumExit ~ 
                 AnnVol + lag(NumExit) + lag(earlyStage) + 
                 lag(blau) + lag(log(InvestAMT+1)) + 
                 lag(dgr_1y) + lag(sh_1y) + lag(pwr_max_5y) + 
                 timesince + after7 +log(firmAge+1) + 
                 CAMA + factor(initial_year) + # factor
                 f_dgr_1y +
                 f_cons_value_1y, # initial focal level
               
               data=pdta,
               index=c("firmname","year"),
               family=negbin,
               model='random')

summary(model1)

# H2
model2 <- pglm(NumExit ~ 
                 AnnVol + lag(NumExit) + lag(earlyStage) + 
                 lag(blau) + lag(log(InvestAMT+1)) + 
                 lag(dgr_1y) + lag(sh_1y) + lag(pwr_max_5y) + 
                 timesince + after7 +log(firmAge+1) + 
                 CAMA + factor(initial_year) + # factor
                 f_dgr_1y +
                 f_cons_value_1y*p_pwr_max_5y, # hypothesis
               
               data=pdta,
               index=c("firmname","year"),
               family=negbin,
               model='random')

summary(model2)


##### save results ####
setwd(wd[4])

tcorr <- tidy(pwcorr); tidy0 <- tidy(model0); tidy1 <- tidy(model1); tidy2 <- tidy(model2)

filenm <- c("Dec31_rst_1yr.xlsx")
write.xlsx(summTable, file=filenm, sheetName="summary")
write.xlsx(pwcorr$r, file=filenm, sheetName = "corr_r", append=TRUE)
write.xlsx(pwcorr$P, file=filenm, sheetName = "corr_p", append=TRUE)
write.xlsx(tcorr, file=filenm, sheetName = "corr", append=TRUE)
write.xlsx(tidy0, file=filenm, sheetName = "base", append=TRUE)
write.xlsx(tidy1, file=filenm, sheetName = "hyp1", append=TRUE)
write.xlsx(tidy2, file=filenm, sheetName = "hyp2", append=TRUE)




# Hypothese (test)
model_test1 <- pglm(NumExit ~ 
                      timesince +  log(firmAge+1) +  AnnVol + 
                      lag(NumExit) + lag(blau) + lag(log(InvestAMT)) + lag(earlyStage) + # other (t)
                      CAMA + factor(initial_year) + # factor
                      lag(dgr_1y) + lag(pwr_max_5y) + lag(cons_value_1y) + # network (t)
                      
                      f_dgr_1y + f_pwr_max_5y + # initial focal level
                      p_btw_1y, # hypothesis
                    
                    data=pdta,
                    index=c("firmname","year"),
                    family=negbin,
                    model='random')

summary(model_test1)


model_test2 <- pglm(NumExit ~ 
                      timesince +  log(firmAge+1) + 
                      lag(NumExit) + lag(blau) + lag(log(InvestAMT)) + lag(earlyStage) + # other (t)
                      CAMA + factor(initial_year) + # factor
                      lag(dgr_1y) + lag(pwr_max_5y) + lag(cons_value_1y) + # network (t)
                      
                      f_dgr_1y + f_pwr_max_5y + # initial focal level
                      p_btw_1y * f_cons_value_1y, # hypothesis
                    
                    data=pdta,
                    index=c("firmname","year"),
                    family=negbin,
                    model='random')

summary(model_test2)


model_test3 <- pglm(NumExit ~ 
                      timesince +  log(firmAge+1) + 
                      lag(NumExit) + lag(blau) + lag(log(InvestAMT)) + lag(earlyStage) + # other (t)
                      CAMA + factor(initial_year) + # factor
                      lag(dgr_1y) + lag(pwr_max_5y) + lag(cons_value_1y) + # network (t)
                      
                      f_btw_1y + f_dgr_1y + f_pwr_max_5y + # initial focal level
                      f_cons_value_1y*(p_btw_1y + p_pwr_max_5y), 
                    
                    data=pdta,
                    index=c("firmname","year"),
                    family=negbin,
                    model='random')

summary(model_test3)
