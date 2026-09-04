# Partial and marginal effect data object

Extract covariate effect curves over time from a
[`partial.plot`](https://rdrr.io/pkg/boostmtree/man/partial.plot.boostmtree.html)
or
[`marginal.plot`](https://rdrr.io/pkg/boostmtree/man/marginal.plot.boostmtree.html)
object.

## Usage

``` r
gg_boost_effect(object, ...)
```

## Arguments

- object:

  A `partial.plot.boostmtree` or `marginal.plot.boostmtree` object, as
  returned by
  [`boostmtree::partial.plot()`](https://rdrr.io/pkg/boostmtree/man/partial.plot.boostmtree.html)
  or
  [`boostmtree::marginal.plot()`](https://rdrr.io/pkg/boostmtree/man/marginal.plot.boostmtree.html)
  with `output = "data", verbose = FALSE`.

- ...:

  Not used; present for S3 consistency.

## Value

A `gg_boost_effect` `data.frame` with columns:

- variable:

  Factor covariate name.

- x:

  Numeric covariate value. For a continuous covariate this is the
  covariate itself; for a discrete (factor) covariate this is an integer
  position, one per level.

- x_label:

  Character level label for a discrete covariate, `NA` for a continuous
  one.

- time:

  Numeric time point.

- estimate:

  Numeric fitted effect.

- kind:

  Factor, `partial` or `marginal`.

## Details

The two differ in what they hold constant. A partial effect varies one
covariate while averaging over the others; a marginal effect reads the
fitted surface as the data actually distribute it. Both are
covariate-by-time surfaces, so both land in this one class,
distinguished by `kind`.

`marginal.plot()` returns a raw scatter alongside its smoothed curve.
That scatter is not the raw observations: it holds one unsmoothed fitted
prediction per subject at the subject's own observed covariate value,
not the observed response and not the stored fitted values. It is also
not reconstructable from
[`gg_boost_trajectory`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_trajectory.md),
which carries no covariate column. `gg_boost_effect` extracts the
smoothed curve instead, so that both levels of `kind` mean the same
thing: the fitted effect.

Neither source computes a confidence interval, so none is reported here.

`boostmtree` accepts factor covariates. For those, `partial.plot()` and
`marginal.plot()` return a character (or, for `marginal.plot()$data`,
factor) `x` column with one row per level rather than a numeric grid.
`gg_boost_effect` detects this and maps each level to an integer
position in `x`, carrying the level itself in `x_label`; a continuous
covariate keeps its numeric value in `x` and leaves `x_label` `NA`. The
grid is resolved once per variable so every time point shares the same
level ordering.

`gg_boost_effect` is currently single-response only. `boostmtree` nests
`$curves` / `$smooth` as `[[response]][[variable]]` and flattens the
outer level only when the fit has a single response; a multi-response
object is rejected with an informative error rather than mishandled.
This is also why `gg_boost_effect` is the one class of the five without
a `response` column.

## See also

[`plot.gg_boost_effect`](https://ehrlinger.github.io/ggBoostedTrees/reference/autoplot.gg_boost_effect.md),
[`gg_boost_vimp`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_vimp.md)

## Examples

``` r
# \donttest{
sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
fit <- boostmtree::boostmtree(
  x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
  M = 50, verbose = FALSE
)
pp <- boostmtree::partial.plot(
  fit, x.var.names = "x1", output = "data", verbose = FALSE
)
plot(gg_boost_effect(pp))

# }
```
