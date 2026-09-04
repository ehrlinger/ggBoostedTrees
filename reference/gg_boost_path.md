# Boosting parameter path data object

Extract the estimated correlation, variance, and penalized-spline
smoothing parameters of a boosted multivariate tree fit as functions of
the boosting iteration.

## Usage

``` r
gg_boost_path(object, parameters = c("rho", "phi", "lambda"), ...)
```

## Arguments

- object:

  A fitted
  [`boostmtree`](https://rdrr.io/pkg/boostmtree/man/boostmtree.html)
  object, or a fitted `BoostMLR` object.

- parameters:

  Character vector naming the paths to extract. For a `boostmtree` fit,
  any of `"rho"`, `"phi"`, and `"lambda"`, defaulting to all three. For
  a `BoostMLR` fit, `"rho"` and/or `"phi"` only, defaulting to both.

- ...:

  Not used; present for S3 consistency.

## Value

A `gg_boost_path` `data.frame` with columns:

- iteration:

  Integer boosting iteration, from 1.

- value:

  Numeric parameter value at that iteration.

- parameter:

  Factor naming the parameter.

- response:

  Factor naming the response.

## Details

`boostmtree` re-estimates three quantities at every boosting iteration:
`rho`, the within-subject correlation; `phi`, the variance component;
and `lambda`, the P-spline smoothing parameter for the time-covariate
interaction. Their paths diagnose whether the variance structure settled
or is still drifting when boosting stops.

Unlike the error path, these are recorded on every fit and do not
require `cv.flag = TRUE`. A parameter absent from the fit is dropped
silently; it is an error only when none of the requested parameters is
present.

This figure also accepts a `BoostMLR` fit, which records only `Rho` and
`Phi` as M-by-response matrices – the method's default `parameters` is
`c("rho", "phi")` rather than all three. `BoostMLR` has no comparable
`lambda`: its `Lambda_List` holds per-iteration basis coefficients
rather than a scalar smoothing parameter per response, a different
quantity, so requesting `"lambda"` from a `BoostMLR` fit is refused with
that reason instead of silently dropped.

## See also

[`plot.gg_boost_path`](https://ehrlinger.github.io/ggBoostedTrees/reference/autoplot.gg_boost_path.md),
[`gg_boost_error`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_error.md)

## Examples

``` r
# \donttest{
sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
fit <- boostmtree::boostmtree(
  x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
  M = 50, cv.flag = TRUE, verbose = FALSE
)
plot(gg_boost_path(fit))

# }
```
