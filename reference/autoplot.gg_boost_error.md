# Plot a [`gg_boost_error`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_error.md) object

The error path of a boosted multivariate tree fit against the boosting
iteration, with the cross-validated optimal iteration marked.

## Usage

``` r
# S3 method for class 'gg_boost_error'
autoplot(object, optimal = TRUE, ...)

# S3 method for class 'gg_boost_error'
plot(x, optimal = TRUE, ...)
```

## Arguments

- object:

  A
  [`gg_boost_error`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_error.md)
  object.

- optimal:

  Logical. Draw a vertical rule at the optimal iteration. Defaults to
  `TRUE`.

- ...:

  Passed to
  [`geom_line`](https://ggplot2.tidyverse.org/reference/geom_path.html).

- x:

  A
  [`gg_boost_error`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_error.md)
  object.

## Value

A `ggplot` object.

## Details

The returned plot carries no theme, so it composes with any `ggplot2`
theme or scale. Several responses are drawn as facets rather than as
coloured series, because the responses do not share a y scale.

## See also

[`gg_boost_error`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_error.md)

## Examples

``` r
# \donttest{
sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
fit <- boostmtree::boostmtree(
  x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
  M = 50, cv.flag = TRUE, verbose = FALSE
)
plot(gg_boost_error(fit))

# }
```
