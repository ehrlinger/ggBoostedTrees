# Fixed-time prediction data object

Predict each subject's response at one time point from a fitted
[`boostmtree`](https://rdrr.io/pkg/boostmtree/man/boostmtree.html)
model, alongside that subject's covariates, so the prediction can be
plotted against any one of them.

## Usage

``` r
gg_boost_prediction(object, time, ...)
```

## Arguments

- object:

  A fitted
  [`boostmtree`](https://rdrr.io/pkg/boostmtree/man/boostmtree.html)
  object.

- time:

  A single time, on the scale of the fitted `tm`, at which to predict
  every subject.

- ...:

  Not used; present for S3 consistency.

## Value

A `gg_boost_prediction` `data.frame` with one row per subject and
columns:

- id:

  Factor subject index.

- predicted:

  Numeric predicted response at `time`.

followed by one column per covariate, as stored on the fit. Attributes:
`time` (the prediction time) and `m` (the iterations used).

## Details

This answers a question the other figures do not: "what does the model
predict for these patients at ten years, and how does that vary with
age?" A partial effect
([`gg_boost_effect`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_effect.md))
holds every other covariate at a reference and varies one; this figure
keeps each subject's own covariates, so the scatter shows the spread the
other covariates produce around the trend in the one being plotted.

Predictions come from
[`predict.boostmtree`](https://rdrr.io/pkg/boostmtree/man/predict.boostmtree.html)
at the cross-validated number of iterations `m.opt` (or the fitted `M`
when the fit records none). They are in-sample predictions: each
subject's own data helped fit the trees. That is not the same quantity
as the `mu` stored on the fit, which
[`gg_boost_trajectory`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_trajectory.md)
plots and which is out-of-bag. A subject's dot here will generally sit
closer to its observed trajectory than the fitted curve in that figure.

`time` must lie within the observed follow-up. `boostmtree` builds its
time effect from a B-spline basis, and a prediction beyond the last
observation is an extrapolation of that basis rather than a model
estimate, so it is refused rather than returned.

Only single-response fits are supported. `BoostMLR` fits are refused:
this figure has not been implemented for that backend.

## See also

[`plot.gg_boost_prediction`](https://ehrlinger.github.io/ggBoostedTrees/reference/autoplot.gg_boost_prediction.md),
[`gg_boost_effect`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_effect.md),
[`gg_boost_trajectory`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_trajectory.md)

## Examples

``` r
# \donttest{
sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
fit <- boostmtree::boostmtree(
  x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
  M = 50, cv.flag = TRUE, verbose = FALSE
)
gg <- gg_boost_prediction(fit, time = 1)
plot(gg, covariate = "x1")

# }
```
