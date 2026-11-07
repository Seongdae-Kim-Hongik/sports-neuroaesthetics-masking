suppressPackageStartupMessages({library(lmerTest);library(emmeans);library(dplyr);library(tidyr)})
a<-commandArgs(TRUE); root<-normalizePath(a[1]);out<-file.path(root,'results');dir.create(out,showWarnings=FALSE)
all_models<-list(); desc<-list(); pooled<-list(); baselines<-list()
for(mod in c('survey','eye')) {
 d<-read.csv(file.path(root,'inputs_private',paste0(mod,'_long.csv')))
 d<-d[is.finite(d$Value),];d$Condition<-factor(d$Condition,levels=c('Standard','Faceless'));d$Group<-factor(d$Group);d$ID<-factor(d$ID)
 for(metric in unique(d$Metric)) {
  if(mod=='eye' && metric %in% c('Start_of_interval','Last_key_press','Last_AOI_viewed','AOI_at_interval_end')) next
  z<-d[d$Metric==metric,]
  agg<-z %>% group_by(ID,Group,Condition) %>% summarise(Value=mean(Value),.groups='drop')
  wide<-pivot_wider(agg,names_from=Condition,values_from=Value);wide<-wide[is.finite(wide$Standard)&is.finite(wide$Faceless),]
  n<-nrow(wide)
  if(n<5||sd(wide$Standard-wide$Faceless)==0) {pooled[[length(pooled)+1]]<-data.frame(Modality=mod,Metric=metric,N=n,MeanStandard=mean(wide$Standard),MeanFaceless=mean(wide$Faceless),Difference=mean(wide$Faceless-wide$Standard),Lower=NA,Upper=NA,p=NA,dz=NA);next}
  tt<-t.test(wide$Faceless,wide$Standard,paired=TRUE)
  pooled[[length(pooled)+1]]<-data.frame(Modality=mod,Metric=metric,N=n,MeanStandard=mean(wide$Standard),MeanFaceless=mean(wide$Faceless),Difference=unname(tt$estimate),Lower=tt$conf.int[1],Upper=tt$conf.int[2],p=tt$p.value,dz=mean(wide$Faceless-wide$Standard)/sd(wide$Faceless-wide$Standard))
  for(cond in c('Standard','Faceless')) {
   v<-wide[[cond]]; se<-sd(v)/sqrt(n);desc[[length(desc)+1]]<-data.frame(Modality=mod,Metric=metric,Condition=cond,N=n,Mean=mean(v),SD=sd(v),Lower=mean(v)-qt(.975,n-1)*se,Upper=mean(v)+qt(.975,n-1)*se)
  }
  zz<-agg[agg$ID %in% wide$ID,];zz$Group<-droplevels(zz$Group)
  tryCatch({fit<-lmer(Value~Group*Condition+(1|ID),data=zz);an<-as.data.frame(anova(fit,ddf='Kenward-Roger'));an$Term<-rownames(an);an$Modality<-mod;an$Metric<-metric;an$N<-n;all_models[[length(all_models)+1]]<-an},error=function(e)message(mod,' ',metric,': ',e$message))
  if(mod=='survey'||(mod=='eye'&&metric %in% c('Number_of_fixations','Average_duration_of_fixations','Average_pupil_diameter','Minimum_duration_of_fixations','Time_to_first_fixation'))) {
   bz<-if(mod=='survey')agg else z
   fit<-lmer(Value~Group*Condition+(1|ID),data=bz);an<-as.data.frame(anova(fit,ddf='Kenward-Roger'));an$Term<-rownames(an);an$Modality<-mod;an$Metric<-metric;baselines[[length(baselines)+1]]<-an
  }
 }
}
p<-bind_rows(pooled) %>% group_by(Modality) %>% mutate(pFDR=p.adjust(p,'BH',n=ifelse(first(Modality)=='eye',48,n()))) %>% ungroup();write.csv(p,file.path(out,'pooled_paired.csv'),row.names=FALSE)
write.csv(bind_rows(desc),file.path(out,'descriptives.csv'),row.names=FALSE)
m<-bind_rows(all_models) %>% group_by(Modality,Term) %>% mutate(pFDR=p.adjust(`Pr(>F)`,'BH',n=ifelse(first(Modality)=='eye',48,n()))) %>% ungroup();write.csv(m,file.path(out,'participant_models_all.csv'),row.names=FALSE)
write.csv(bind_rows(baselines),file.path(out,'baseline_reproduction.csv'),row.names=FALSE)
writeLines(capture.output(sessionInfo()),file.path(out,'sessionInfo.txt'))
print(p[p$Modality=='survey'|p$Metric %in% c('Number_of_fixations','Average_duration_of_fixations','Average_pupil_diameter'),])
