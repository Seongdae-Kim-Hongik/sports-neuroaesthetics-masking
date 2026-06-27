# Sports Neuroaesthetics: Masking Effects on Athlete Perception Across Behavior Groups

Analysis code for a **sports-neuroaesthetics** study of how masking influences the
perception of athletes, across four behavior groups (defined by spectating and
playing experience), combining self-report ratings, prefrontal-cortex activation
(fNIRS), and eye-tracking. Analyses use mixed-effects models and hierarchical
Bayesian correlation.

## Scripts

| File | Purpose |
|------|---------|
| [`01_survey_factor_anova.R`](01_survey_factor_anova.R) | Five perceptual factors (Performance, Experience, Confidence, Attractiveness, Likability) under masked vs. non-masked stimuli; behavior-group x masking mixed-model ANOVA and judgement-basis frequencies (N = 43). |
| [`02_eyetracker_anova.R`](02_eyetracker_anova.R) | Behavior-group x masking mixed ANOVA across all eye-tracking metrics, with FDR correction across metrics and Bonferroni post-hoc contrasts (full sample, no metric pre-selection). |
| [`03_multimodal_bayesian.R`](03_multimodal_bayesian.R) | Survey + fNIRS + eye-tracking merge; hierarchical Bayesian correlation (`BayesFactor::correlationBF`) within behavior-group x masking cells, with example visualisations. |

## Data

The scripts read Excel files (survey, fNIRS, eye-tracking) from a `data/` folder.
Raw data are not included here as they contain human-subjects information; they are
available from the authors on reasonable request.

## Requirements

R (>= 4.1) with: `readxl`, `tidyverse`, `lme4`, `lmerTest`, `emmeans`,
`BayesFactor`, `ggdist`, `patchwork`.

## License

MIT — see [`LICENSE`](LICENSE).
