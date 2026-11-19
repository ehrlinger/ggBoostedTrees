# Plot a [`gg_boost_vimp`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_vimp.md) object

Variable importance as a dot chart: one panel for the main effect of
each covariate and one for its interaction with time, sharing a variable
axis, with the noise band shaded in each.

## Usage

``` r
# S3 method for class 'gg_boost_vimp'
autoplot(object, ...)

# S3 method for class 'gg_boost_vimp'
plot(x, ...)
```

## Arguments

- object:

  A
  [`gg_boost_vimp`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_vimp.md)
  object.

- ...:

  Passed to
  [`geom_point`](https://ggplot2.tidyverse.org/reference/geom_point.html).

- x:

  A
  [`gg_boost_vimp`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_vimp.md)
  object.

## Value

A `ggplot` object.

## Details

The two panels share one variable axis, so a covariate reads across a
row: a long stem under "Main effect" and a hollow dot under "Interaction
with time" is a covariate whose effect is constant over follow-up; a
stem in the second panel means its effect changes with time. Variables
run top to bottom by the largest importance they reach in either
component. Both panels share one importance scale, so an interaction can
be judged against the main effects, not only against other interactions.

`boostmtree` reports importance as the relative increase in error after
perturbing a covariate, so a covariate that contributes nothing scores
near zero and is as often slightly negative as slightly positive. The
negative values therefore show how far noise alone reaches. The shaded
band runs from minus to plus the largest absolute negative importance
for the response, across both components; a value is detectable only
when it lies to the right of the band, and is then drawn as a filled dot
on a stem. Values inside the band are hollow. With no negative values
there is no band and any positive value is detectable. This is a reading
aid, not a test.

Every value is drawn at its signed importance. When no covariate has a
detectable interaction with time, that panel says so in words. The
overall time effect, when the source object records one, is reported in
the caption: it says whether the trajectory has a shape at all, which
the per-covariate interactions cannot.

The x axis is labelled with the `metric` attribute carried by the
extracted object. The returned plot carries no theme.

## See also

[`gg_boost_vimp`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_vimp.md)

## Examples

``` r
# \donttest{
sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
fit <- boostmtree::boostmtree(
  x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
  M = 50, cv.flag = TRUE, verbose = FALSE
)
plot(gg_boost_vimp(boostmtree::vimp.boostmtree(fit)))

# }
```
