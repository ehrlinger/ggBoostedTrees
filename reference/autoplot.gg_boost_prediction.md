# Plot a [`gg_boost_prediction`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_prediction.md) object

Each subject's predicted response at a fixed time, against one
covariate.

## Usage

``` r
# S3 method for class 'gg_boost_prediction'
autoplot(object, covariate, ...)

# S3 method for class 'gg_boost_prediction'
plot(x, covariate, ...)
```

## Arguments

- object:

  A
  [`gg_boost_prediction`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_prediction.md)
  object.

- covariate:

  Name of the covariate to place on the x axis.

- ...:

  Passed to
  [`geom_point`](https://ggplot2.tidyverse.org/reference/geom_point.html).

- x:

  A
  [`gg_boost_prediction`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_prediction.md)
  object.

## Value

A `ggplot` object.

## Details

For a numeric covariate every subject is a point and a loess smoother
traces the trend. The smoother summarises the points; it is not a
partial effect, because the other covariates are left at each subject's
own values. A flat smoother over a wide scatter says the covariate
matters little at this time and the others drive the spread.

For a factor covariate the points are grouped by level with each level's
mean marked.

The returned plot carries no theme.

## See also

[`gg_boost_prediction`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_prediction.md)

## Examples

``` r
# \donttest{
sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
fit <- boostmtree::boostmtree(
  x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
  M = 50, cv.flag = TRUE, verbose = FALSE
)
plot(gg_boost_prediction(fit, time = 1), covariate = "x1")

# }
```
