# Eye-tracking metrics: behavior-group x masking mixed ANOVA across ALL metrics,
# with FDR correction across metrics and Bonferroni post-hoc contrasts.
# Full sample (no metric pre-selection).
#
# Design: Group_behavior (A-D) x J_Group (control vs. masking), Participant random.
#   A = spectate+/play+, B = spectate+/play-, C = spectate-/play+, D = spectate-/play-.

library(tidyverse)
library(readxl)
library(lme4)
library(lmerTest)
library(emmeans)

# ---- Data ----
df <- read_excel("data/eyetracker.xlsx")

start_col_idx <- which(colnames(df) == "Start_of_interval")
all_vars <- colnames(df)[start_col_idx:ncol(df)]

df_final <- df %>%
  filter(!is.na(Group_behavior), !is.na(J_Group)) %>%
  mutate(across(all_of(all_vars), ~as.numeric(as.character(.))),
         Group_behavior = as.factor(Group_behavior),
         J_Group = as.factor(J_Group),
         Participant = as.factor(Participant))

n_subj <- length(unique(df_final$Participant))
cat("Subjects:", n_subj, "\n")
cat("By behavior group:\n")
print(df_final %>% distinct(Participant, Group_behavior) %>% count(Group_behavior))

# ---- ANOVA + post-hoc across all metrics ----
anova_list <- list(); posthoc_list <- list()
for (dv in all_vars) {
  try({
    form <- as.formula(paste0("`", dv, "` ~ Group_behavior * J_Group + (1|Participant)"))
    model <- lmer(form, data = df_final)

    anova_list[[dv]] <- as.data.frame(anova(model)) %>%
      rownames_to_column("Effect") %>% mutate(Variable = dv)

    emm <- emmeans(model, pairwise ~ J_Group | Group_behavior, adjust = "bonferroni")
    posthoc_list[[dv]] <- as.data.frame(emm$contrasts) %>% mutate(Variable = dv)
  }, silent = TRUE)
}

# ---- Combine (FDR across metrics, within each effect) ----
final_anova <- bind_rows(anova_list) %>%
  rename(p_raw = `Pr(>F)`) %>%
  group_by(Effect) %>%
  mutate(p_FDR = p.adjust(p_raw, method = "fdr")) %>%
  ungroup() %>%
  select(Variable, Effect, F_value = `F value`, NumDF, DenDF, p_raw, p_FDR)

final_posthoc <- bind_rows(posthoc_list) %>%
  rename(p_bonferroni = p.value) %>%
  select(Variable, Group_behavior, contrast, estimate, SE, df, t_ratio = t.ratio, p_bonferroni)

# ---- Descriptives by group x condition ----
descriptives <- df_final %>%
  pivot_longer(all_of(all_vars), names_to = "Variable", values_to = "Score") %>%
  group_by(Variable, Group_behavior, J_Group) %>%
  summarise(MeanSD = sprintf("%.2f +- %.2f", mean(Score, na.rm=T), sd(Score, na.rm=T)),
            .groups = "drop")

# ---- Save ----
write.csv(final_anova, "EyeTracker_ANOVA_Results.csv", row.names = FALSE)
write.csv(final_posthoc, "EyeTracker_PostHoc_Results.csv", row.names = FALSE)
write.csv(descriptives, "EyeTracker_Descriptives.csv", row.names = FALSE)

# ---- Console summary (FDR-significant effects) ----
cat("\nGroup x masking interactions, FDR < 0.05:\n")
print(final_anova %>% filter(Effect == "Group_behavior:J_Group", p_FDR < 0.05) %>%
        select(Variable, F_value, p_raw, p_FDR))

cat("\nMasking main effects, FDR < 0.05:\n")
print(final_anova %>% filter(Effect == "J_Group", p_FDR < 0.05) %>%
        select(Variable, F_value, p_raw, p_FDR))
