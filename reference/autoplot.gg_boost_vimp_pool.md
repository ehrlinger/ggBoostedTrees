# Plot a [`gg_boost_vimp_pool`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_vimp_pool.md) object

Pooled variable importance: for each covariate, the spread over runs of
its importance minus that run's shadow band, with the share of runs in
which it cleared the band.

## Usage

``` r
# S3 method for class 'gg_boost_vimp_pool'
autoplot(object, ...)

# S3 method for class 'gg_boost_vimp_pool'
plot(x, ...)
```

## Arguments

- object:

  A
  [`gg_boost_vimp_pool`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_vimp_pool.md)
  object.

- ...:

  Passed to
  [`geom_point`](https://ggplot2.tidyverse.org/reference/geom_point.html)
  for the run points.

- x:

  A
  [`gg_boost_vimp_pool`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_vimp_pool.md)
  object.

## Value

A `ggplot` object.

## Details

The layout follows
[`plot.gg_boost_vimp`](https://ehrlinger.github.io/ggBoostedTrees/reference/autoplot.gg_boost_vimp.md):
one panel for the main effect and one for the interaction with time,
sharing a variable axis, with covariates running top to bottom by the
largest median they reach in either panel.

Each run has its own band, so the runs are not drawn on the importance
scale against one shaded band. Instead the x axis is the margin over the
band: each run's importance minus the band of that run and panel. Zero
is then the line every run was judged against, and a run right of it
cleared its band. The box spans the 25th to 75th percentile of the
margin across runs, the whiskers the 15th to 85th, and each run is a
small point. The label at the right of each row, such as `18/50`, counts
the runs that cleared the band.

A box well right of zero is a covariate that clears the band in nearly
every run; one straddling zero is borderline, and its verdict from any
single run is not to be trusted. The share is a measure of stability,
not a test.

The x axis is labelled with the `metric` attribute. The caption gives
the number of runs and, when every run records one, the median overall
time effect. The returned plot carries no theme.

## See also

[`gg_boost_vimp_pool`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_vimp_pool.md),
[`plot.gg_boost_vimp`](https://ehrlinger.github.io/ggBoostedTrees/reference/autoplot.gg_boost_vimp.md)

## Examples

``` r
# \donttest{
sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
x <- boost_shadow(sim$features, sim$id, k = 2)
fit <- boostmtree::boostmtree(
  x = x, tm = sim$time, id = sim$id, y = sim$y,
  M = 50, cv.flag = TRUE, verbose = FALSE
)
runs <- lapply(1:3, function(i) boostmtree::vimp.boostmtree(fit))
plot(gg_boost_vimp(runs))

# }
```
