Package: ggBoostedTrees
Version: 0.10.2

# ggBoostedTrees 0.10.2

## Variable importance

* `gg_boost_vimp()` pools importance runs. Pass a list of
  `vimp.boostmtree()` results, repeated runs on one fit or one run on each
  of several refits, and it returns a `gg_boost_vimp_pool` frame: for each
  covariate and panel, the share of runs in which it cleared that run's own
  shadow band, with percentiles of its margin over the band. The per-run
  bands and margins travel as the `runs` attribute. A run without shadow
  covariates, on different covariates, or with a missing importance stops
  with an error naming it. A single importance object behaves as before.

* `autoplot()` draws a pooled object as a box per covariate of the margin
  over the band (box 25th to 75th percentile, whiskers 15th to 85th), with
  each run as a point and the count of runs that cleared the band. The
  article's figure B section shows five pooled runs.

## Documentation

* The help pages and vignettes now say how to use `boostmtree` correctly,
  drawing on a 50-seed simulation (100 subjects, `M = 400`, `nu = 0.25`,
  `randomForestSRC` 3.9.0 and 3.10.0). Documentation only; no behaviour
  changes.
  - `gg_boost_error()` and `autoplot.gg_boost_error()`: more iterations can
    overfit, unlike `ntree` in a random forest, and a curve that turns back
    up shows it. `m.opt` is one draw on a flat curve (156 to 400 across the
    seeds), so read the flattening and the error level instead.
  - A seed reproduces a fit only within one `randomForestSRC` version. Pin
    it (with `renv`) along with `set.seed()`, and set a seed before
    `vimp.boostmtree()`, and before `predict()` and `partial.plot()` under
    `na.action = "na.impute"`.
  - `boost_shadow()` and `gg_boost_vimp()`: a borderline importance verdict
    needs repeated runs, and refitting moves it as much as rerunning
    `vimp.boostmtree()`. The article's figure B section now advises refits,
    not reruns alone.

## Tests

* The test fixtures' provenance file (`boost_continuous.dcf`) records the
  `randomForestSRC` version they were fitted under (3.10.0), and
  `make-fixtures.R` writes it. `boostmtree` grows its trees with
  `randomForestSRC`, and a seeded fit is reproduced only under the same
  version: 3.9.0 and 3.10.0 gave a different fit at every one of 50 seeds.

# ggBoostedTrees 0.10.1

## boostmtree backend

* `Remotes:` installs `boostmtree` 2.0.13 from the CCF fork (`v2.0.13-ccf`),
  and the README's backend install line names that tag. The `Imports:` floor
  stays at 2.0.1. The fork's releases since 2.0.8:
  - 2.0.9 holds about 60% to 70% less memory per boosting step in a fitted
    object.
  - 2.0.10 fixes `predict()` and `partial.plot()` stopping with "subscript out
    of bounds" on a fit with `na.action = "na.omit"` when a row of `x` has a
    missing covariate, and rejects a bad `boostmtree.control(cv.cores = )`
    before the first tree.
  - 2.0.11 makes `partial.plot()` predict only at the time points it plots,
    and walks each step's out-of-bag list once in a cross-validated
    prediction instead of scanning it for every subject.
  - 2.0.13 fixes a fixed `boostmtree.control(seed = )` drawing the same
    subsample for every tree. With `cv.flag = TRUE` about 60% of subjects
    were never out of bag, and their fitted trajectory was a flat line at
    the mean response of the other subjects; the cross-validated error,
    `m.opt` and grow-object importance were computed from the rest.

* The test fixtures are refitted with 2.0.13; the reference fit now grows
  `M = 100`, because the honest cross-validated error was still falling at
  50 (`m.opt` is 88).

* `gg_boost_trajectory()`, and so `gg_boost_calibration()`, warn when a
  cross-validated `boostmtree` fit records subjects that were never out of
  bag by `m.opt`, read from the fit's own out-of-bag record
  (`gamma.i.list`), and name the cause. A flat trajectory alone does not
  warn: a fit with an intercept-only time design (`d = 0`) is flat by
  construction. Both document that such a fit stores out-of-bag predictions
  in `mu`, not the in-sample fit.

## Variable importance

* The `gg_boost_vimp()` plot is redrawn as a dot chart: one panel for main
  effects and one for interactions with time, sharing a variable axis and an
  importance scale. Every value sits at its signed importance. Values right
  of a grey noise band are filled dots on a stem, values inside it hollow.
  An interaction panel with nothing outside the band says "None
  detectable", where the old bar chart drew an empty panel. The overall time
  effect, previously dropped, is reported in the caption.

* New `boost_shadow(x, id, k = 5)` appends `k` shadow copies of every
  covariate, each shuffled between subjects, to give variable importance a
  noise reference measured in the fit itself. `gg_boost_vimp()` gains a
  logical `shadow` column that flags them by name.

* The noise band comes from the shadows: in each panel it runs up to the
  largest importance any shadow reached (or zero). Shadows set the band but
  are not drawn. The band is a reference, not a test with a known error
  rate: shadows in a copy share one subject shuffle and keep the
  covariates' correlations, and a covariate with no effect of its own can
  clear the band when it is correlated with one that has an effect. A fit
  without shadows draws no band and no detectable-or-not verdict, and the
  caption says so. A band from the largest negative importance was tried
  and dropped: with every tree drawing its own subsample, negatives become
  rare as boosting increases while a pure-noise covariate scored as high as
  0.57.

## Other figures

* New `gg_boost_prediction(fit, time)` predicts every subject's response at
  one time from `predict.boostmtree()` at `m.opt`, with the subject's
  covariates, and `plot(gg, covariate = )` draws the predictions against one
  covariate with a loess smoother. It refuses a time outside the observed
  follow-up, multi-response fits and `BoostMLR` fits.

* The `gg_boost_error()` plot's caption reports convergence: the optimal
  iteration against the number grown, and the error's relative change over
  the last quarter of the iterations. An optimum at the last iteration with
  a change of a percent or so means the curve has flattened; a steep fall
  means refit with more iterations or a larger learning rate. Turn it off
  with `convergence = FALSE`.

## Documentation

* New article, *Four Figures From One boostmtree Fit*, builds the subject
  trajectories, variable importance, a partial effect over time and a
  landmark-time prediction from one fit with shadow covariates, and says
  how to read each. It starts by reading the error path for convergence,
  and says that a verdict near the edge of the band can change between runs
  of `vimp.boostmtree()`.

* The getting-started vignette fits `M = 200` iterations instead of 50, so
  its error path levels off before the last iteration as its own advice
  asks, and reads the convergence caption. It seeds with `set.seed()` alone.

# ggBoostedTrees 0.10.0

* The plot snapshot tests skip when `vdiffr` is not installed instead of
  failing, and `patchwork`, which nothing uses, leaves `Suggests`. Both from
  the CRAN Cookbook audit for this release.

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
