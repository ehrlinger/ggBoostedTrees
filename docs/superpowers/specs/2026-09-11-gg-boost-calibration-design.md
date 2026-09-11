# gg_boost_calibration: observed against fitted over follow-up

Date: 2026-09-11
Status: approved design, implemented on feat/calibration
Branch: `feat/calibration`

## Why

A cohort analysis on the patched `boostmtree` build (postop AV mean gradient,
Cleveland Clinic cohort) produced a figure of every patient's predicted curve
with the cohort mean drawn through them, beside the same mean over the raw
data. The figure could not answer the question it raised: does the mean curve
match the data? Nothing on either panel summarised the observed values, and
nothing showed how much data supported the tail after about 7 years, where a
few predicted curves fanned upward.

The diagnostics that answered it were written as analysis code (the
"Checking the boostmtree cohort curves" PDF sent to the analyst). Two of the
three belong in the package, because they read the model:

1. **Calibration over time.** Observed against fitted, binned by follow-up
   time, with the mean predicted curve for the cohort overlaid.
2. **Tail support.** How many observations and subjects stand behind each
   stretch of follow-up.

The third, flagging suspect raw measurements, reads only the response data and
never the model. It stays out.

## Scope

In:

- A new extractor, `gg_boost_calibration()`, with methods for `boostmtree` and
  `BoostMLR` grow fits and a refusing `default`.
- Its renderer, `autoplot.gg_boost_calibration()`, with `plot()` as the alias.
- A documented example showing the fanning-curve check with the existing
  `gg_boost_trajectory()`, which already extracts predicted curves from a
  `boostmtree` predict object (verified: a predict object on a 15-point grid
  yields 15 rows per subject with `observed` all `NA`).

Out:

- A raw-data spike or outlier flagger. Data QC, not a model figure.
- A shared-axis side-by-side panel helper. `coord_cartesian()` and
  `patchwork` already do it.
- A late-riser ranking helper. `gg_boost_trajectory()` plus `subset` covers the
  figure; ranking is a one-line `dplyr` step in analysis code.
- A loess curve through the raw observations. The binned means carry the same
  information with honest uncertainty, and the renderer reads only the tidy
  object, which holds bins rather than raw rows.
- Cohort curves for `BoostMLR`. The package already refuses `BoostMLR` predict
  objects via `.boost_check_mlr_grow()`; its comment in `R/utils.R` gives the
  reasons (their `Error_Rate` is test error, and they record an `Mopt` the
  extractors would silently discard).

## API

```r
gg_boost_calibration(object, pred = NULL, n_bins = 10, breaks = NULL, ...)

autoplot(object, ci = TRUE, ...)   # object: a gg_boost_calibration
plot(x, ci = TRUE, ...)
```

- `object`: a `boostmtree` grow fit or a `BoostMLR` grow fit.
- `pred`: optional `boostmtree` predict object, made with
  `predict(fit, x = ...)` and no `tm`/`id`. Adds the cohort curve.
- `n_bins`: number of equal-count (quantile) time bins. Default 10.
- `breaks`: numeric vector of bin edges in the fit's own time units. Overrides
  `n_bins` when supplied.
- `ci`: draw 95% intervals on the observed bin means.

Argument names follow the package's existing snake_case for new arguments
(`n_max`, `subset`); dotted names are reserved for arguments that mirror a
`boostmtree` argument.

## Extractor

### Source rows

The extractor calls `gg_boost_trajectory(object)` and bins its output. That
reuses the existing, tested handling of both backends' storage layouts, time
sorting, subject identifiers from `id.unique`, and per-response blocks. The
calibration extractor adds binning and nothing else, so a new backend added to
`gg_boost_trajectory()` reaches this figure for free.

Rows with `NA` in `observed` or `fitted` are dropped before binning. A fit with
no observed values at all (every `observed` is `NA`) is refused: there is
nothing to calibrate against.

### Binning

Default breaks are quantiles of observed time, computed per response, at
`seq(0, 1, length.out = n_bins + 1)`. The lowest and highest edges are the
observed minimum and maximum, and the lowest bin is closed on the left
(`include.lowest = TRUE`).

Tied times are the norm in clinical data (many echoes at discharge), and they
merge quantile edges. The extractor removes duplicate edges and, when fewer
than `n_bins` bins survive, issues a `message()` naming the response, the
number requested and the number produced. A message, not a warning: the result
is correct, only coarser than asked.

A supplied `breaks` is used as given after `sort(unique())`. Observations
outside its range are dropped with a message giving the count. Fewer than two
distinct edges is an error.

A response left with no observations, because none fall within `breaks` or
none has both an observed and a fitted value, is an error naming the
response.

`n_bins` must be a single whole number of at least 1; `breaks` must be numeric.
Both are validated with messages naming `gg_boost_calibration`.

### Equal-count bins and tail support

With equal-count bins, `n_obs` is nearly constant by construction and cannot
show thinning. Tail support is carried by the two things that do vary:

- **Bin width** (`time_hi - time_lo`): where data is sparse, a bin must span
  more time to collect its share.
- **`n_subject`**: a late bin with the same observation count but far fewer
  distinct subjects rests on repeat measurements of a few people.

The renderer draws the bin width explicitly (see below) so the tail signal is
visible rather than only in the table.

### Return value

A `gg_boost_calibration` `data.frame`, one row per response by bin, ordered by
response then time:

| Column | Type | Meaning |
|---|---|---|
| `response` | factor | Response label, levels as in `gg_boost_trajectory()` |
| `bin` | factor | Bin label from `cut()`, ordered by time |
| `time_lo` | numeric | Lower bin edge |
| `time_hi` | numeric | Upper bin edge |
| `time` | numeric | Median observed time within the bin |
| `n_obs` | integer | Observations in the bin |
| `n_subject` | integer | Distinct subjects in the bin |
| `observed` | numeric | Mean observed value |
| `observed_lo` | numeric | `observed - 1.96 * sd / sqrt(n_obs)`; `NA` when `n_obs < 2` |
| `observed_hi` | numeric | `observed + 1.96 * sd / sqrt(n_obs)`; `NA` when `n_obs < 2` |
| `fitted` | numeric | Mean fitted value at the same observations |

The interval is a normal approximation that treats observations as independent.
Repeated measures within a subject make it too narrow, and the `@details` says
so. It is a visual guide, not an inferential claim; a cluster-robust interval
is a possible later refinement, not part of this change.

### The cohort curve

When `pred` is supplied, the result carries an attribute `cohort`: a
`data.frame` with columns `response` (factor, same levels), `time` (numeric)
and `fitted` (numeric, the mean over subjects of the predicted curves at each
grid time). It is computed from `gg_boost_trajectory(pred)`.

It is an attribute rather than rows because it has a different grain (grid
times, not bins) and mixing the two in one frame would make every consumer
filter by kind. `@return` documents it, and the renderer reads it with
`attr(object, "cohort")`.

`pred` is refused, with a message naming `gg_boost_calibration`, when:

- it is not a `boostmtree` object of class `predict`;
- `object` is a `BoostMLR` fit (no cohort curve for that backend);
- it records a different number of responses from `object`;
- its subjects do not share one time vector. That happens when `predict()` was
  given `tm` and `id`, which predicts at each subject's own times. A mean over
  ragged time sets changes composition from one time to the next and would be
  misleading, so the message says to call `predict(fit, x = ...)` without them.

## Renderer

`autoplot.gg_boost_calibration()` draws, in order:

1. **Bin span**: a thin horizontal segment from `time_lo` to `time_hi` at the
   observed mean, via `geom_segment()`. This is the tail-support signal. It is
   drawn with `geom_segment()` rather than `geom_errorbarh()`, which ggplot2
   deprecated in 4.0.0 (verified against the installed 4.0.3).
2. **Observed**: bin means as points, with vertical 95% intervals via
   `geom_linerange()` when `ci = TRUE` (rows with `NA` bounds are skipped).
3. **Fitted**: bin means as a second point series in a different shape,
   joined by a line, so observed and fitted can be compared bin by bin.
4. **Cohort curve**, when the attribute is present: a heavier line through the
   mean predicted curve.

An observed-versus-fitted legend distinguishes 2 and 3. Axis labels default to
`"Time"` and `"Response"`, matching `autoplot.gg_boost_trajectory()`. More than
one response facets with `facet_wrap(~ response, scales = "free_y")`. Like
every renderer in the package, it applies no theme.

The renderer reads only the column contract and the `cohort` attribute, never
the fit.

## Tests

In `tests/testthat/test-gg_boost_calibration.R` and
`test-plot-gg_boost_calibration.R`, matching the existing file pairs.

Extractor, against `boost_continuous.rds` (25 subjects, 189 observations):

- Class and column contract, including types.
- `sum(n_obs)` is 189; `n_subject` never exceeds 25.
- Each bin's `fitted` and `observed` equal means computed by hand from the
  fixture's `mu` and `y.org`.
- Bins are ordered by time and `time_lo < time_hi` throughout.
- `breaks` overrides `n_bins`; out-of-range observations are dropped with a
  message stating the count.

Edge cases, against hand-built objects in `helper-fixtures.R`:

- Tied times that merge quantile edges produce the fewer-bins message and the
  right number of rows.
- A single-observation bin gets `NA` interval bounds, not an error.
- A fit with no observed values is refused.
- `n_bins` and `breaks` validation errors.

Backends:

- The 3-response `BoostMLR` fixture yields one block of bins per response.
- `pred` refusals: wrong class, `BoostMLR` fit, response-count mismatch,
  ragged time vectors.

Cohort curve:

- A new slimmed predict fixture, `boost_predict.rds`, made by the fixture
  generator from `predict(fit, x = fit$x)` on the committed fit and keeping
  only the fields `gg_boost_trajectory()` reads, plus the class. The full
  predict object is 4.4 MB, too large to commit against the 5 MB tarball
  budget. `predict()` on the committed fit is deterministic (verified: two
  calls return identical `mu`), so the fixture stays valid without refitting.
- The attribute's `fitted` equals the row means of the predicted curves.

Renderer:

- Returns a `ggplot`; builds without warnings.
- vdiffr snapshots with and without the cohort curve, and for a
  multi-response fit; `ci = FALSE` is covered by a layer test rather than a
  snapshot.
- Faceting appears only for multiple responses.

## Package changes

- `R/gg_boost_calibration.R`, `R/plot.gg_boost_calibration.R`.
- Fixture generator: add the slimmed predict fixture.
- `NAMESPACE` via roxygen; `importFrom(ggplot2, geom_segment, geom_linerange)`.
- `_pkgdown.yml`: add to sections 1 (Extract) and 2 (Render).
- `README.md`: a row in the status table.
- `NEWS.md` and `DESCRIPTION`: 0.0.6 to 0.0.7 (patch digit only).

## Branch sequence

1. Recompose `.claude/house-style.md` with
   `compose-house-style.R --repo ggBoostedTrees`. The artifact is stale against
   the vault sources, and the `house-style` job runs on every PR. The pinned
   `house-style-v1` tag is level with `origin/main`, and its mirrored
   `sources/` are byte-identical to the vault, so a local recompose produces
   exactly what CI checks for.
2. This spec.
3. The feature, test-first.
4. Version bump, NEWS, pkgdown and README.
5. Local gate: `devtools::test()`, `lintr::lint_package()` after
   `pkgload::load_all()`, and `R CMD check`. Then open the PR.
