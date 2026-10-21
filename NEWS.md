Package: ggBoostedTrees
Version: 0.10.0

# ggBoostedTrees 0.10.0

* The README's section on what `cv.flag = TRUE` costs gains timings and peak
  memory from a server, measured at 10 steps, by subjects and cores, and says
  that memory, not speed, limits the cores on a large fit: the parallel share
  levels off near 80%. It says the fit's memory also grows with the number of
  steps, so the 10-step figures do not bound a longer fit. It drops the claim
  that the share keeps rising with the number of subjects, which the server
  measurements did not bear out past about 1,000, and corrects the simulated
  data's visits per subject from 5 to about 9.

* The README adds a measured full run at study size (1,391 subjects, 4,771
  visits, 1,000 steps, 8 cores) on boostmtree 2.0.7 and 2.0.8: partial effects
  fell from 94 minutes and 70.0 GiB of session memory to 32 minutes and
  11.3 GiB, with identical results.

* `Remotes:` installs `boostmtree` 2.0.8 from the CCF fork (`v2.0.8-ccf`), and
  the README's backend install line names that tag. The `Imports:` floor stays
  at 2.0.1. Since 2.0.4, the fork's releases have made long fits faster and
  smaller without changing their results:
  - 2.0.5 makes an ordinal fit's cross-validation about 23% faster (600
    subjects, 4 cores).
  - 2.0.6 stores the cross-validation state as one vector per subject, so each
    forked worker holds about a quarter of the memory it did: on a server at
    4,000 subjects, 8 and 16 cores now finish where 2.0.4 ran out of memory.
  - 2.0.7 runs each forked worker on one BLAS thread. On a server whose R
    links a multithreaded OpenBLAS, 2.0.6's workers each started a thread per
    CPU and overloaded the machine: at 1,000 subjects on 4 cores, 2.0.7 took
    616 s where 2.0.6 took 1,488 s.
  - 2.0.8 makes partial effects walk the boosting steps one at a time instead
    of holding every step for every subject at once. On a synthetic ordinal
    fit one `partial.plot()` call fell from 87 s and 4.5 GB to 2.4 s and
    0.4 GB, and it adds a `progress` callback to `boostmtree()` and
    `partial.plot()`.

# ggBoostedTrees 0.9.3

* The README's Installation section now leads with `hvtiR::install()`, which
  installs the whole HVTI R family in one call, and then gives
  `pak::pak("ehrlinger/ggBoostedTrees")` for this package alone.

* `Remotes:` installs `boostmtree` 2.0.4 from the CCF fork (`v2.0.4-ccf`), and
  the README's backend install line names that tag. 2.0.4 adds
  `boostmtree.control(cv.cores = )`, which runs the cross-validated fit's
  out-of-bag update on several cores, and is about 30% faster on one core;
  the fit is identical to 2.0.3's. The `Imports:` floor stays at 2.0.1,
  because nothing in this package uses the new argument.

* The README and the getting-started vignette say what `cv.flag = TRUE`
  costs: cross-validation's time grows with the square of the number of
  subjects, with measured timings, and `boostmtree` 2.0.4's
  `boostmtree.control(cv.cores = )` runs it on several cores without changing
  the fit.

# ggBoostedTrees 0.9.2

* `DESCRIPTION` now declares the Quarto command line tool in
  `SystemRequirements`, which the new vignette needs to build.

* New overview vignette, `vignette("ggBoostedTrees")`, walks one small
  simulated `boostmtree` fit through every figure the package draws, in the
  order you would look at them. On the pkgdown site, the article puts the
  table of contents on the left, as in the other HVTI packages.

# ggBoostedTrees 0.9.1

* `Remotes:` now pins the `boostmtree` fork at `v2.0.3-ccf` (was
  `v2.0.2-ccf`). That release only drops an unused `parallel` import; the
  `cv.flag` fix came in 2.0.2, so the `boostmtree (>= 2.0.1)` floor is
  unchanged. Downstream packages that pin their own `boostmtree` ref can now
  move to `v2.0.3-ccf` without handing `pak` two refs for one package.

# ggBoostedTrees 0.9.0

* `gg_boost_vimp()` accepts a `BoostMLR` predict object made with
  `predictBoostMLR(..., importance = TRUE)`. `BoostMLR` splits the
  covariate-time interaction over its time intervals; these are summed to one
  `interaction` value per covariate, and the per-interval matrices are kept
  in the `interaction.by.interval` attribute (#9).
* New `boostmlr_partial()` computes `BoostMLR` partial effects for one or more
  covariates, naming the covariates and responses that
  `BoostMLR::partial.BoostMLR()` leaves unnamed. `gg_boost_effect()` accepts
  the result and extracts the lowess-smoothed curves, one block per response.
  All six figures now accept a `BoostMLR` fit. `BoostMLR` support remains
  partial: marginal effects and joint importance are not supported (#9).
* `gg_boost_effect()` now accepts the `partial.plot()` and `marginal.plot()`
  output of a multi-response (ordinal or nominal) `boostmtree` fit, which it
  previously refused. Every result gains a `response` factor, labelled from
  the object's `response.labels`; a single-response fit is labelled
  `"response"` and otherwise unchanged. `autoplot()` facets by response, as a
  grid of response by variable when there are several of each (#19).

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
