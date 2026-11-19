# Subject trajectory data object

Extract observed and fitted longitudinal trajectories from a boosted
multivariate tree fit, one row per observation.

## Usage

``` r
gg_boost_trajectory(object, ...)
```

## Arguments

- object:

  A fitted
  [`boostmtree`](https://rdrr.io/pkg/boostmtree/man/boostmtree.html)
  object, or a fitted `BoostMLR` object.

- ...:

  Not used; present for S3 consistency.

## Value

A `gg_boost_trajectory` `data.frame` with columns:

- id:

  Factor subject identifier, taken from `id.unique`.

- time:

  Numeric observation time, ascending within subject.

- fitted:

  Numeric fitted value.

- observed:

  Numeric observed value, or `NA`.

- response:

  Factor naming the response.

## Details

This is the figure longitudinal boosting exists for: whether the model
tracks individual subjects over time, rather than only fitting the
population mean.

`boostmtree` stores `time`, `mu` and `y.org` as parallel lists of
per-subject vectors, in the order observations were supplied rather than
in time order. Rows here are sorted by time within each subject, and the
assembled frame is response-major (all subjects for one response, then
the next), so a line drawn through one subject's rows follows the
trajectory instead of zigzagging. Subject identifiers come from the
fit's own `id.unique`, not from a positional index.

`observed` is `NA` throughout when the fit carries no observed response,
which happens for a prediction on new data.

What `fitted` holds depends on how the model was grown. With
`cv.flag = FALSE` it is the in-sample fit. With `cv.flag = TRUE`,
`boostmtree` replaces `mu` with the out-of-bag prediction at `m.opt`,
the same values that produce the cross-validated error, so it sits
further from `observed` than an in-sample fit would. A subject's
out-of-bag prediction moves only at iterations where that subject is out
of bag. A subject never out of bag by `m.opt` keeps the starting value,
a constant equal to the mean response of the other subjects. The
extractor warns when the fit's own out-of-bag record (`gamma.i.list`)
shows such a subject. A flat line alone does not trigger it, since a fit
with an intercept-only time design (`d = 0`) is flat by construction.
Before `boostmtree` 2.0.13, a fixed `control$seed` drew the same
subsample for every tree, which left roughly 60 percent of subjects
flat. Refit with 2.0.13 or later, or grow with `control$seed = NULL`
after [`set.seed()`](https://rdrr.io/r/base/Random.html), which is still
reproducible.

This figure accepts either a `boostmtree` or a `BoostMLR` fit.
`BoostMLR` stores `mu` and `y` as flat observation-by-response matrices,
with `tm` and `id` as parallel flat vectors, rather than boostmtree's
nested per-subject lists – entirely different layout for the same
information. Response labels come from `y_Names`, since `mu` carries no
column names. `BoostMLR` is natively multi-response, so a fit typically
yields several response blocks even for a "single" model.

## See also

[`plot.gg_boost_trajectory`](https://ehrlinger.github.io/ggBoostedTrees/reference/autoplot.gg_boost_trajectory.md),
[`gg_boost_error`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_error.md)

## Examples

``` r
# \donttest{
sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
fit <- boostmtree::boostmtree(
  x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
  M = 50, verbose = FALSE
)
plot(gg_boost_trajectory(fit))

# }
```
