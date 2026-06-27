# Survey component: five-factor ANOVA (N = 43)
# Sports-neuroaesthetics masking study. Five perceptual factors (Performance,
# Experience, Confidence, Attractiveness, Likability) rated under masked vs.
# non-masked stimuli, analysed by behavior group x masking mixed model.

library(readxl)
library(tidyverse)
library(lme4)
library(lmerTest)

# ---- Data ----
df_survey <- read_excel("data/survey.xlsx")

# ---- Five-factor preprocessing (items Q_63 - Q_122; masked = _M, non-masked = _N) ----
df_factors <- df_survey %>%
  rowwise() %>%
  mutate(
    perf_M = mean(c(Q_63, Q_73, Q_83, Q_93, Q_98, Q_108), na.rm=T),
    perf_N = mean(c(Q_68, Q_78, Q_88, Q_103, Q_113, Q_118), na.rm=T),

    exp_M = mean(c(Q_64, Q_74, Q_84, Q_94, Q_99, Q_109), na.rm=T),
    exp_N = mean(c(Q_69, Q_79, Q_89, Q_104, Q_114, Q_119), na.rm=T),

    conf_M = mean(c(Q_65, Q_75, Q_85, Q_95, Q_100, Q_110), na.rm=T),
    conf_N = mean(c(Q_70, Q_80, Q_90, Q_105, Q_115, Q_120), na.rm=T),

    attr_M = mean(c(Q_66, Q_76, Q_86, Q_96, Q_101, Q_111), na.rm=T),
    attr_N = mean(c(Q_71, Q_81, Q_91, Q_106, Q_116, Q_121), na.rm=T),

    like_M = mean(c(Q_67, Q_77, Q_87, Q_97, Q_102, Q_112), na.rm=T),
    like_N = mean(c(Q_72, Q_82, Q_92, Q_107, Q_117, Q_122), na.rm=T)
  ) %>% ungroup()

# ---- Part 1: five-factor mixed ANOVA (behavior group x masking) ----
cat("\n", strrep("=", 85), "\n", sep = "")
cat("PART 1. Five-factor mixed ANOVA (N = 43)\n")
cat(strrep("=", 85), "\n", sep = "")

factor_map <- list("Performance"="perf", "Experience"="exp", "Confidence"="conf",
                   "Attractiveness"="attr", "Likability"="like")

for (label in names(factor_map)) {
  f_pre <- factor_map[[label]]
  df_long <- df_factors %>%
    select(e_name, sex, Group_behavior, starts_with(f_pre)) %>%
    pivot_longer(cols = starts_with(f_pre), names_to = "Masking", values_to = "Score") %>%
    mutate(Masking = ifelse(str_detect(Masking, "_M"), "Masked", "No-Masked"))

  model <- lmer(Score ~ Group_behavior * Masking + (1|e_name), data = df_long)
  cat("\n[", label, "] ANOVA summary:\n")
  print(round(as.data.frame(anova(model))[, c("F value", "Pr(>F)")], 4))

  desc <- df_long %>%
    group_by(Group_behavior, Masking) %>%
    summarise(m = mean(Score, na.rm=T), s = sd(Score, na.rm=T), .groups='drop') %>%
    mutate(MeanSD = paste0(round(m, 2), " +- ", round(s, 2))) %>%
    select(Group_behavior, Masking, MeanSD) %>%
    pivot_wider(names_from = Masking, values_from = MeanSD)
  print(as.data.frame(desc))
}

# ---- Part 2: judgement-basis frequencies (Q123, Q124) ----
cat("\n\n", strrep("=", 85), "\n", sep = "")
cat("PART 2. Judgement-basis frequencies (Q123, Q124)\n")
cat(strrep("=", 85), "\n", sep = "")

analyze_freq <- function(col_name, title) {
  tab <- table(df_survey$Group_behavior, df_survey[[col_name]])
  cat("\n", title, " (n, %):\n", sep = "")
  res_df <- as.data.frame(tab) %>%
    rename(Behavior = Var1, Category = Var2, Count = Freq) %>%
    group_by(Behavior) %>%
    mutate(Percentage = paste0(round(Count/sum(Count)*100, 1), "%")) %>%
    pivot_wider(names_from = Category, values_from = c(Count, Percentage))
  print(as.data.frame(res_df))
}

analyze_freq("Q_123", "Factor that conveys emotion (Q123)")
analyze_freq("Q_124", "Factor driving perceived attractiveness (Q124)")
