# ggBoostedTrees — ggplot2 graphics for boosted tree models
<!-- badges: start -->
[![R-CMD-check](https://github.com/ehrlinger/ggBoostedTrees/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/ehrlinger/ggBoostedTrees/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/ehrlinger/ggBoostedTrees/graph/badge.svg)](https://app.codecov.io/gh/ehrlinger/ggBoostedTrees)
[![wip](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/badges/latest/wip.svg)
[![pkgdown](https://github.com/ehrlinger/ggBoostedTrees/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/ehrlinger/ggBoostedTrees/actions/workflows/pkgdown.yaml)

[![R package version](https://img.shields.io/github/r-package/v/ehrlinger/ggBoostedTrees)](https://github.com/ehrlinger/ggBoostedTrees)

[![lint](https://github.com/ehrlinger/ggBoostedTrees/actions/workflows/lint.yaml/badge.svg)](https://github.com/ehrlinger/ggBoostedTrees/actions/workflows/lint.yaml)
<!-- badges: end -->

## Status

Pre-1.0 and under active development. What exists today:

| Figure | Status |
|---|---|
| Boosting error path, with the optimal iteration marked | Implemented |
| `rho` / `phi` / `lambda` parameter paths | Implemented |
| Subject trajectories, observed against fitted | Implemented |
| Variable importance | Implemented |
| Partial and marginal effects | Implemented |
| `BoostMLR` as a second backend | Partial — `gg_boost_trajectory()`, `gg_boost_error()` and `gg_boost_path()` accept it; `gg_boost_vimp()` and `gg_boost_effect()` remain `boostmtree` only |

The five implemented figures are complete and tested. The API for what exists
is not expected to change; the list above is what is missing, not what is
provisional.

ggBoostedTrees draws diagnostic figures for boosted tree models fit with
[boostmtree](https://cran.r-project.org/package=boostmtree), which implements
Friedman's gradient descent boosting with multivariate tree base learners for
longitudinal responses. It is the boosting counterpart to
[ggRandomForests](https://github.com/ehrlinger/ggRandomForests), and follows
the same two-step idiom: an extractor pulls a tidy data frame out of a fitted
model, and `autoplot()` renders it. If you have a `boostmtree` fit and want to
know whether it converged, this is the package.

The full reference — every function and the changelog — is online at
<https://ehrlinger.github.io/ggBoostedTrees/>.

## Installation

ggBoostedTrees requires a **patched build of boostmtree**, not the CRAN
release. CRAN's `boostmtree` 2.0.0 has three defects that reach these figures:
frozen residuals under `cv.flag = TRUE` (which is exactly the flag the error
path depends on), incorrect `na.action` handling, and malformed dimnames from
`vimp(joint = TRUE)`. The fixes live in a fork pending upstream merge.

That requirement is enforced rather than documented: the `Imports` floor is
`boostmtree (>= 2.0.1)`, and CRAN's 2.0.0 cannot satisfy it. An install
against the defective backend fails to resolve instead of silently producing
wrong figures.

```r
remotes::install_github("ehrlinger/ggBoostedTrees")
```

The `Remotes:` field points at the fork, so the correct `boostmtree` is
installed for you. To install the backend on its own:

```r
remotes::install_github("ehrlinger/boostmtree_src", subdir = "boostmtree",
                        ref = "v2.0.2-ccf")
```

## Quick Start

Fit a model with `cv.flag = TRUE`, then ask whether it converged:

```r
library(ggBoostedTrees)

set.seed(7)
sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
fit <- boostmtree::boostmtree(
  x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
  M = 50, cv.flag = TRUE, verbose = FALSE,
  control = boostmtree::boostmtree.control(seed = 7)
)

# The error path, with the cross-validated optimal iteration marked.
autoplot(fit)
```

`cv.flag = TRUE` is not optional for the error path. `boostmtree` records
`err.rate` and `m.opt` only when cross-validation ran, so a default fit has no
error path to draw and `gg_boost_error()` will say so.

Every figure is available as data as well as a plot, because the tidy frame is
the point rather than an implementation detail:

```r
gg_dta <- gg_boost_error(fit)
head(gg_dta, 3)
#>   iteration     value response optimal
#> 1         1 1.0118738        y   FALSE
#> 2         2 1.0008788        y   FALSE
#> 3         3 0.9912097        y   FALSE

# Returns a bare ggplot, so it composes with any theme or scale.
autoplot(gg_dta) + ggplot2::theme_bw()
```

The variance and smoothing parameter paths diagnose whether the variance
structure settled before boosting stopped. They are always faceted on a free
y scale, because `rho`, `phi` and `lambda` span three orders of magnitude:

```r
autoplot(gg_boost_path(fit))
```

The trajectory plot is the one longitudinal boosting exists for — whether the
model tracks individual subjects, not just the population mean:

```r
autoplot(gg_boost_trajectory(fit))
```

## Function reference

### Figure data

| Function | Description |
|---|---|
| `gg_boost_error()` | Boosting error path by iteration, with the cross-validated optimal iteration flagged. Requires `cv.flag = TRUE`. |
| `gg_boost_path()` | Estimated `rho`, `phi` and `lambda` by iteration. Available on any fit. |
| `gg_boost_trajectory()` | Observed and fitted subject trajectories over time, sorted within subject. |
| `gg_boost_vimp()` | Variable importance for the main effect and the time interaction. |
| `gg_boost_effect()` | Partial and marginal covariate effects over time, for both continuous and discrete (factor) covariates. |

### Rendering

| Function | Description |
|---|---|
| `autoplot.gg_boost_error()` | Error path as a line, with a dashed rule at the optimal iteration. |
| `autoplot.gg_boost_path()` | Parameter paths, faceted by parameter on a free y scale. |
| `autoplot.gg_boost_trajectory()` | Fitted trajectories as lines and observed values as points, thinned by `subset`/`n_max` with transparency scaled to cohort size. |
| `autoplot.boostmtree()` | Shortcut from a fitted model straight to the error plot. |
| `autoplot.gg_boost_vimp()` | Ordered horizontal bars, faceted by component. |
| `autoplot.gg_boost_effect()` | Effect curves coloured by time, faceted by variable. |

`plot()` is an alias for `autoplot()` on every `gg_boost_*` object.

## Related packages

- [ggRandomForests](https://github.com/ehrlinger/ggRandomForests) — the same
  idiom for random forests, covering `randomForestSRC`, `randomForest` and
  `varPro`.
- [boostmtree](https://cran.r-project.org/package=boostmtree) — the backend
  modelled here.
- [BoostMLR](https://cran.r-project.org/package=BoostMLR) — boosting for
  multivariate longitudinal responses, a supported second backend for
  `gg_boost_trajectory()`, `gg_boost_error()` and `gg_boost_path()`.
