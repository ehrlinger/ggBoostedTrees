# Boosting error trajectory data object

Extract the error path of a boosted multivariate tree fit as a function
of the boosting iteration, together with the optimal iteration selected
by cross-validation.

## Usage

``` r
gg_boost_error(object, use.rmse = TRUE, ...)
```

## Arguments

- object:

  A fitted
  [`boostmtree`](https://rdrr.io/pkg/boostmtree/man/boostmtree.html)
  object.

- use.rmse:

  Logical. When `TRUE` (default) return the standardized `l2` error;
  when `FALSE` return the unstandardized squared error.

- ...:

  Not used; present for S3 consistency.

## Value

A `gg_boost_error` `data.frame` with columns:

- iteration:

  Integer boosting iteration, from 1.

- value:

  Numeric error at that iteration.

- response:

  Factor naming the response.

- optimal:

  Logical, `TRUE` at the cross-validated optimal iteration.

## Details

**The fit must have been grown with `cv.flag = TRUE`.** `boostmtree`
records `err.rate` and `m.opt` only when cross-validation ran; a default
fit carries neither, and there is no error path to extract. If this
function reports that the fit has no error path, refit with
`cv.flag = TRUE`.

`boostmtree` stores the error on the standardized response scale in the
`l2` column. `use.rmse = FALSE` returns `(l2 * y.sd)^2`, the squared
error on the original scale.

## See also

[`plot.gg_boost_error`](https://ehrlinger.github.io/ggBoostedTrees/reference/autoplot.gg_boost_error.md),
[`gg_boost_path`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_path.md)

## Examples

``` r
# \donttest{
sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
fit <- boostmtree::boostmtree(
  x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
  M = 50, cv.flag = TRUE, verbose = FALSE
)
gg_dta <- gg_boost_error(fit)
plot(gg_dta)

# }
```
