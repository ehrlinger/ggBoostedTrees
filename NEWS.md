Package: ggBoostedTrees
Version: 0.0.7

# ggBoostedTrees 0.0.7

* The README function reference now lists `gg_boost_calibration()` and its
  `autoplot()` method alongside the other shipped figure-data objects.
* New `gg_boost_calibration()` compares observed and fitted values over
  follow-up. Observations are binned by time into equal-count bins, and each
  bin reports the observed mean with a 95% interval, the fitted mean at the
  same observations, and how many observations and distinct subjects stand
  behind it. It accepts `boostmtree` and `BoostMLR` fits.
* Supplying a `boostmtree` predict object as `pred` adds the cohort mean
  curve. A predict object made with `tm` and `id` is refused, because each
  subject is then predicted at its own times and a mean across subjects
  would change composition along the curve.
* The renderer draws each bin's time span, so a thin tail shows as a long
  late bin.

# ggBoostedTrees 0.0.6

* `BoostMLR` fits are now accepted by `gg_boost_trajectory()`,
  `gg_boost_error()` and `gg_boost_path()`. Adding the backend required
  extractor methods only; no renderer changed, which is what the tidy
  intermediate exists to guarantee.
* `BoostMLR` selects no optimal boosting iteration, so `gg_boost_error()`
  flags none for that backend rather than deriving one.
* `BoostMLR`'s `Lambda_List` holds per-iteration basis coefficients rather
  than a scalar smoothing parameter, so `gg_boost_path()` offers `rho` and
  `phi` for that backend and says so if `lambda` is requested.
* `gg_boost_vimp()` and `gg_boost_effect()` remain `boostmtree` only.
* `gg_boost_error()` refuses `use.rmse = FALSE` on a `BoostMLR` fit, by name
  or by position: that backend records no `y.sd`, so its `Error_Rate` cannot be
  unstandardized. The generic declares `use.rmse` as its second formal, so the
  positional form is valid syntax, and it previously fell through and returned
  standardized values to a caller who had asked for the other scale.
  `use.rmse = TRUE` is accepted, being the default and the scale `BoostMLR`
  already returns, so a caller that always passes the argument runs against
  either backend unchanged.
* `autoplot.gg_boost_trajectory()` accepts a repeated subject identifier in
  `subset` rather than failing with an internal `factor level [2] is
  duplicated`. The caller's ordering still determines the factor levels.
* `gg_boost_path()`'s `boostmtree` method validates `parameters` the same
  way its `BoostMLR` sibling and `gg_boost_vimp()`'s `components` argument
  do: an empty vector is rejected and duplicates are de-duplicated rather
  than reaching an opaque `factor()` error.

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
