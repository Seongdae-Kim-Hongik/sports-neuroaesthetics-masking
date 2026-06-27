# Multimodal integration: survey + fNIRS + eye-tracking.
# Hierarchical Bayesian correlation (within behavior group x masking) between
# prefrontal/eye-tracking measures and the five survey factors.

library(readxl)
library(tidyverse)
library(BayesFactor)
library(ggdist)
library(patchwork)

# ---- Data ----
df_survey <- read_excel("data/survey.xlsx")
df_et     <- read_excel("data/eyetracker.xlsx")
df_fnirs  <- read_excel("data/fnirs.xlsx")

# ---- Survey preprocessing (items Q_63 - Q_122; 12 presentations x 5 metrics) ----
masking_order <- c("masking", "nomasking", "masking", "nomasking", "masking", "nomasking",
                   "masking", "masking", "nomasking", "masking", "nomasking", "nomasking")
metrics <- c("Emotion", "Liveliness", "Arousal", "Flow", "Attractiveness")

df_survey_long <- df_survey %>%
  rename(ID = e_name, Behavior_Group = Group_behavior) %>%
  mutate(across(contains("Q_"), ~as.numeric(as.character(gsub("[^0-9.]", "", .))))) %>%
  pivot_longer(cols = contains("Q_"), names_to = "Question", values_to = "Score") %>%
  mutate(q_num = as.numeric(str_extract(Question, "\\d+"))) %>%
  filter(q_num >= 63, q_num <= 122) %>%
  mutate(
    rel_q_num = q_num - 62,
    Stim_idx = (rel_q_num - 1) %/% 5 + 1,
    Metric_idx = (rel_q_num - 1) %% 5 + 1,
    Masking_Cond = masking_order[Stim_idx],
    Metric = metrics[Metric_idx]
  ) %>%
  mutate(ID = tolower(trimws(as.character(ID)))) %>%
  group_by(ID, sex, Behavior_Group, Masking_Cond, Metric) %>%
  summarise(Score = mean(Score, na.rm=TRUE), .groups = "drop") %>%
  pivot_wider(names_from = Metric, values_from = Score)

# ---- fNIRS and eye-tracking standardisation ----
fnirs_prep <- df_fnirs %>%
  rename(ID = `Subject Name`, Masking_raw = Condition) %>%
  mutate(Masking_Cond = ifelse(str_detect(tolower(Masking_raw), "no"), "nomasking", "masking")) %>%
  mutate(ID = tolower(trimws(as.character(ID))))

et_prep <- df_et %>%
  rename(ID = Participant, Masking_raw = J_Group) %>%
  mutate(Masking_Cond = case_when(
    str_detect(tolower(Masking_raw), "control") ~ "nomasking",
    str_detect(tolower(Masking_raw), "masking") ~ "masking",
    TRUE ~ tolower(Masking_raw)
  )) %>%
  mutate(ID = tolower(trimws(as.character(ID))))

# ---- Merge ----
master <- df_survey_long %>%
  inner_join(fnirs_prep, by = c("ID", "Masking_Cond")) %>%
  inner_join(et_prep, by = c("ID", "Masking_Cond"))

cat("Merged sample size (N):", nrow(master), "\n")

# ---- Hierarchical Bayesian correlation (within behavior group x masking) ----
results <- master %>%
  group_by(Behavior_Group, Masking_Cond) %>%
  group_modify(~ {
    v1_list <- c("Left FPC", "Left OFC", "Right OFC", "Left VLPFC", "Average_eye_openness")
    v2_list <- metrics
    res_list <- list()
    for (v1 in v1_list) {
      for (v2 in v2_list) {
        if (v1 %in% colnames(.x) & v2 %in% colnames(.x)) {
          x <- as.numeric(.x[[v1]]); y <- as.numeric(.x[[v2]])
          ok <- is.finite(x) & is.finite(y)
          if (sum(ok) > 5) {
            bf_obj <- correlationBF(x[ok], y[ok])
            res_list[[length(res_list)+1]] <- tibble(
              var1 = v1, var2 = v2,
              r_mean = mean(posterior(bf_obj, iterations = 2000)[, 1]),
              BF10 = as.numeric(extractBF(bf_obj)$bf)
            )
          }
        }
      }
    }
    bind_rows(res_list)
  }) %>% ungroup()

# ---- Report (BF10 > 3) ----
print(as.data.frame(results %>% filter(BF10 > 3) %>% arrange(desc(BF10))))

# ---- Visualisation (example panels, one per behavior group) ----
plot_theme <- theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold", size = 10),
        axis.title = element_text(face = "bold"))

p_a <- master %>% filter(Behavior_Group == "a", Masking_Cond == "nomasking") %>%
  ggplot(aes(x = `Left OFC`, y = Attractiveness)) +
  geom_point(color = "#1f77b4", alpha = 0.6) + geom_smooth(method = "lm", color = "black") +
  labs(title = "Group A: no-masking", x = "Left OFC", y = "Attractiveness") + plot_theme

p_b <- master %>% filter(Behavior_Group == "b", Masking_Cond == "masking") %>%
  ggplot(aes(x = `Left FPC`, y = Flow)) +
  geom_point(color = "#d62728", alpha = 0.6) + geom_smooth(method = "lm", color = "black") +
  labs(title = "Group B: masking", x = "Left FPC", y = "Flow") + plot_theme

p_c <- master %>% filter(Behavior_Group == "c", Masking_Cond == "masking") %>%
  ggplot(aes(x = `Left VLPFC`, y = Emotion)) +
  geom_point(color = "#2ca02c", alpha = 0.6) + geom_smooth(method = "lm", color = "black") +
  labs(title = "Group C: masking", x = "Left VLPFC", y = "Emotion") + plot_theme

p_d <- master %>% filter(Behavior_Group == "d", Masking_Cond == "nomasking") %>%
  ggplot(aes(x = `Left VLPFC`, y = Flow)) +
  geom_point(color = "#9467bd", alpha = 0.6) + geom_smooth(method = "lm", color = "black") +
  labs(title = "Group D: no-masking", x = "Left VLPFC", y = "Flow") + plot_theme

(p_a | p_b) / (p_c | p_d) + plot_annotation(title = "Multimodal correlations by behavior group")
