# Changelog

## ggBoostedTrees 0.0.2

- [`gg_boost_error()`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_error.md)
  and
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html)/`autoplot()`
  for the boosting error path, marking the cross-validated optimal
  iteration. Requires a fit grown with `cv.flag = TRUE`.
- [`gg_boost_path()`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_path.md)
  and
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html)/`autoplot()`
  for the `rho`, `phi` and `lambda` parameter paths.
- `autoplot()` on a `boostmtree` fit as a shortcut to the error path.

## ggBoostedTrees 0.0.1

- Package skeleton, shared utilities, and the testthat scaffold.
