* The `gg_boost_vimp()` plot is redrawn as a dot chart: one panel for main
  effects and one for interactions with time, sharing a variable axis and an
  importance scale. Every value sits at its signed importance. A grey band
  runs from minus to plus the largest negative importance, which measures
  how far noise alone reaches; values right of the band are filled dots on a
  stem, values inside it hollow. An interaction panel with nothing outside
  the band says "None detectable", where the old bar chart drew an empty
  panel. The overall time effect, previously dropped, is reported in the
  caption.

* New `gg_boost_prediction(fit, time)` predicts every subject's response at
  one time from `predict.boostmtree()` at `m.opt`, with the subject's
  covariates, and `plot(gg, covariate = )` draws the predictions against one
  covariate with a loess smoother. It refuses a time outside the observed
  follow-up, multi-response fits and `BoostMLR` fits.

* New article, *Four Figures From One boostmtree Fit*, builds the subject
  trajectories, variable importance, a partial effect over time and a
  landmark-time prediction from one fit, and says how to read each.
