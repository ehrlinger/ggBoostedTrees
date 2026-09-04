# Plot a boostmtree fit

A shortcut to the error trajectory, which is the first thing worth
looking at after a fit. Every other figure is reached through its own
`gg_boost_*()` extractor.

## Usage

``` r
# S3 method for class 'boostmtree'
autoplot(object, ...)
```

## Arguments

- object:

  A fitted
  [`boostmtree`](https://rdrr.io/pkg/boostmtree/man/boostmtree.html)
  object grown with `cv.flag = TRUE`.

- ...:

  Passed to
  [`autoplot.gg_boost_error`](https://ehrlinger.github.io/ggBoostedTrees/reference/autoplot.gg_boost_error.md).

## Value

A `ggplot` object, as produced by
[`autoplot.gg_boost_error`](https://ehrlinger.github.io/ggBoostedTrees/reference/autoplot.gg_boost_error.md).

## See also

[`gg_boost_error`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_error.md),
[`gg_boost_path`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_path.md),
[`gg_boost_trajectory`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_trajectory.md)

## Examples

``` r
# \donttest{
sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
fit <- boostmtree::boostmtree(
  x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
  M = 50, cv.flag = TRUE, verbose = FALSE
)
ggplot2::autoplot(fit)

# }
```
