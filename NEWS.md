Package: ggBoostedTrees
Version: 0.0.5

# ggBoostedTrees 0.0.5

* `gg_boost_effect()` now handles factor covariates. It previously coerced
  their labels with `as.numeric()`, producing an all-`NA` covariate column and
  a blank figure. The contract gains an `x_label` column, and the renderer
  draws discrete covariates as points on a labelled axis.
* An object mixing continuous and discrete covariates is refused with
  guidance, since one figure permits only one scale type per aesthetic.
* `gg_boost_vimp()` validates `components`: an empty vector is rejected and
  duplicates are de-duplicated rather than reaching an opaque `factor()` error.
* Corrected the description of `marginal.plot()`'s `$data`, which holds
  unsmoothed fitted predictions rather than raw observations.

# ggBoostedTrees 0.0.4

* `gg_boost_vimp()` and `plot()`/`autoplot()` for variable importance,
  covering both the main effect of each covariate and its interaction with
  time. The axis is labelled with the metric recorded on the source object
  rather than a hard-coded string.
* `gg_boost_effect()` and `plot()`/`autoplot()` for partial and marginal
  covariate effects over time, as one class distinguished by `kind`.
* Neither `partial.plot()` nor `marginal.plot()` computes a confidence
  interval, so `gg_boost_effect()` reports none.

# ggBoostedTrees 0.0.3

* `gg_boost_trajectory()` and `plot()`/`autoplot()` for observed and fitted
  subject trajectories over time. Rows are sorted within subject, because
  `boostmtree` stores observations in input order and a line drawn from that
  order zigzags.
* The trajectory renderer thins large cohorts with `subset` and `n_max`, and
  scales transparency to the number of subjects drawn so that an overplotted
  cohort reads as a density.

# ggBoostedTrees 0.0.2

* `gg_boost_error()` and `plot()`/`autoplot()` for the boosting error path,
  marking the cross-validated optimal iteration. Requires a fit grown with
  `cv.flag = TRUE`.
* `gg_boost_path()` and `plot()`/`autoplot()` for the `rho`, `phi` and
  `lambda` parameter paths.
* `autoplot()` on a `boostmtree` fit as a shortcut to the error path.

# ggBoostedTrees 0.0.1

* Package skeleton, shared utilities, and the testthat scaffold.
