# Pooled variable importance: box of margins over the shadow band

Approved by John, 2026-11-20. Branch `feat/pooled-vimp-box`.

## Goal

One `vimp.boostmtree()` run gives one verdict per covariate, and a borderline
covariate can land on either side of the shadow band from one run (or one
refit) to the next. Pooling several runs reports how often each covariate
cleared its run's band.

## Input

`gg_boost_vimp(list(v1, v2, ...))`, a new `gg_boost_vimp.list()` S3 method.
Elements are `vimp.boostmtree` objects: repeated runs on one fit, one run on
each of several refits, or a mix. Runs are labelled by the list names, or
`1..N` when unnamed. A bare `vimp.boostmtree` object goes to the existing
method and behaves exactly as before.

Errors, naming the run:

- an element that is not a `vimp.boostmtree` object (BoostMLR included);
- a run with no shadow covariates (no band to be judged against);
- a run whose covariates, components, responses or metric differ from the
  first run's;
- an empty list, or names that are empty or duplicated.

## Extracted object

Class `gg_boost_vimp_pool`, a data frame with one row per
variable x component x response (shadows excluded):

`variable`, `component`, `response`, `n_runs`, `n_detected`, `share`,
`median_importance`, `q15`, `q25`, `q50`, `q75`, `q85`.

Per run, `band` = max(shadow importance in that panel, 0), the rule
`.vimp_shadow_thresholds()` already uses; `margin` = importance - band;
`detected` = margin > 0. `share` = n_detected / n_runs. The quantiles are of
`margin` over runs.

Attributes: `runs` (per-run rows: `variable`, `component`, `response`, `run`,
`importance`, `band`, `margin`, `detected`), `metric`, `n_runs`, and
`time.effect` (per-response median over runs when every run records one).

No pooled "detected" verdict: the share is reported, the reader judges.

## Plot

`autoplot.gg_boost_vimp_pool()`, same panel and facet layout as the single-run
figure. x is the margin over each run's own band, with a reference line at
zero. A box spans the 25th to 75th percentile, whiskers the 15th to 85th, the
runs are drawn as small points (no jitter), and a `k/N` label per row gives
the share. Rows run top to bottom by their largest median margin. The renderer
reads only the extracted frame and its `runs` attribute.

## Tests

Shares, counts, bands, margins and quantiles against hand-computed values from
`vimp_shadow_fixture()`; run labels; a one-run list; every error path; plot
layer data; one new vdiffr snapshot. Existing tests and snapshots unchanged.
