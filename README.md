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
| Calibration over follow-up, observed against fitted, with the cohort mean curve | Implemented |
| `BoostMLR` as a second backend | Partial — all six figures accept a `BoostMLR` fit, with partial effects through `boostmlr_partial()`; marginal effects and joint importance are not supported |

The six implemented figures are complete and tested. The API for what exists
is not expected to change; the list above is what is missing, not what is
provisional.

ggBoostedTrees draws diagnostic figures for boosted tree models fit with
[boostmtree](https://cran.r-project.org/package=boostmtree), which implements
Friedman's gradient descent boosting with multivariate tree base learners for
longitudinal responses, with partial support for `BoostMLR` fits (see the
status table above). It is the boosting counterpart to
[ggRandomForests](https://github.com/ehrlinger/ggRandomForests), and follows
the same two-step idiom: an extractor pulls a tidy data frame out of a fitted
model, and `autoplot()` renders it. If you have a `boostmtree` fit and want to
know whether it converged, this is the package. All six figures also accept
a `BoostMLR` fit, within the limits in the status table.

The full reference — every function and the changelog — is online at
<https://ehrlinger.github.io/ggBoostedTrees/>.

## Installation

ggBoostedTrees is part of the HVTI R family. Install it with the rest of
the family through [hvtiR](https://github.com/ehrlinger/hvtiR):

```r
# install.packages("pak")
pak::pak("ehrlinger/hvtiR")
hvtiR::install()
```

`hvtiR::install()` installs every member in one call, so the versions the
members require of one another resolve together. Update later with
`hvtiR::update()`, from a fresh R session: it will not overwrite a package
that is already loaded.

To install ggBoostedTrees on its own:

```r
pak::pak("ehrlinger/ggBoostedTrees")
```

ggBoostedTrees requires a **patched build of boostmtree**, not the CRAN
release. CRAN's `boostmtree` 2.0.0 has three defects that reach these figures:
frozen residuals under `cv.flag = TRUE` (which is exactly the flag the error
path depends on), incorrect `na.action` handling, and malformed dimnames from
`vimp(joint = TRUE)`. The fixes live in a fork pending upstream merge.

That requirement is enforced rather than documented: the `Imports` floor is
`boostmtree (>= 2.0.1)`, and CRAN's 2.0.0 cannot satisfy it. An install
against the defective backend fails to resolve instead of silently producing
wrong figures.

The `Remotes:` field points at the fork, so either command above installs the
correct `boostmtree` for you. To install the backend on its own:

```r
pak::pak("ehrlinger/boostmtree_src/boostmtree@v2.0.8-ccf")
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

It is also where the time goes. Cross-validation refits each step once for
every subject left out of the tree, so its cost grows with the square of the
number of subjects. Profiled on a laptop with simulated data of about 9 visits
per subject, a 50-step fit on boostmtree 2.0.3 took 2.9 s at 75 subjects, 29 s
at 300 and 108 s at 600, about 9 times the cost of the same fit without it at
300. `boostmtree` 2.0.4 runs those refits in parallel through
`boostmtree.control(cv.cores = )`, and the fit is identical on any number of
cores; at 600 subjects, 4 laptop cores took 33 s. Windows cannot fork and uses
one core.

On a shared server the limit is memory, not speed. Each core is a forked copy
of R, and about 80% of the fit runs in parallel, so speed levels off near 4 to 5
times however many cores it has. Measured on our server (boostmtree 2.0.4, an
ordinal response, 10 steps), with peak memory at those 10 steps:

| subjects | 1 core | 4 cores | 8 cores |
|---|---|---|---|
| 1,000 | 654 s, 1 GB | 263 s, 5 GB | 184 s, 11 GB |
| 2,000 | 2,552 s, 3 GB | 1,006 s, 19 GB | 790 s, 30 GB |
| 4,000 | 11,003 s, 13 GB | 3,987 s, 69 GB | ran out of memory |

Time grows in proportion to the number of steps: at 4,000 subjects and 1,000
steps, the fit takes between four and five days on 4 cores. Memory grows with
the steps too, because the fit keeps every one, about 0.35 MB per step per
1,000 visits for an ordinal response. The figures above are upper bounds at 10
steps only; at 1,000 steps add about 11 GB at 4,000 subjects for the fit
itself, and possibly more for each core, which has not been measured.

A full run at study size, measured on our server on 2026-10-21: a continuous
response, 1,391 subjects and 4,771 visits (about 3.4 per subject), 1,000 steps,
`nu = 0.05`, `mtry = 8`, 8 cores, in Workbench's Medium profile (64 GiB), whose
memory limit is enforced at 76.8 GiB, 1.2 times the profile. Partial effects are
three variables, 56 predictions. Memory is RStudio's session memory, the figure
in its memory report and its limit warning: everything in the session,
including the fitted model and every forked worker, not R's own allocation.
Each reading was taken once during the step, so the step's true peak may be
higher.

| step | boostmtree 2.0.7 | boostmtree 2.0.8 |
|---|---|---|
| cross-validated fit, saved | 74 min | 64 min |
| variable importance | 12 min | 13 min |
| partial effects | 94 min, 70.0 GiB | 32 min, 11.3 GiB |

The two runs give identical error paths, importances and partial effects. On
2.0.7 the partial-effects step reached 70.0 GiB of that 76.8 GiB limit, so a
study this size needed more memory for its partial effects than for its fit;
2.0.8 removes that.

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
| `gg_boost_calibration()` | Observed and fitted values over follow-up, summarized in equal-count time bins with observed confidence intervals. |
| `gg_boost_vimp()` | Variable importance for the main effect and the time interaction. |
| `gg_boost_effect()` | Partial and marginal covariate effects over time, for both continuous and discrete (factor) covariates, and per response for ordinal, nominal and `BoostMLR` fits. |
| `boostmlr_partial()` | Computes `BoostMLR` partial effects for one or more covariates, in the form `gg_boost_effect()` accepts. |

### Rendering

| Function | Description |
|---|---|
| `autoplot.gg_boost_error()` | Error path as a line, with a dashed rule at the optimal iteration. |
| `autoplot.gg_boost_path()` | Parameter paths, faceted by parameter on a free y scale. |
| `autoplot.gg_boost_trajectory()` | Fitted trajectories as lines and observed values as points, thinned by `subset`/`n_max` with transparency scaled to cohort size. |
| `autoplot.gg_boost_calibration()` | Observed and fitted bin means with observed confidence intervals and each bin's time span. |
| `autoplot.boostmtree()` | Shortcut from a fitted model straight to the error plot. |
| `autoplot.gg_boost_vimp()` | Ordered horizontal bars, faceted by component. |
| `autoplot.gg_boost_effect()` | Effect curves coloured by time, faceted by variable and, for several responses, by response. |

`plot()` is an alias for `autoplot()` on every `gg_boost_*` object.

## Documentation

- [Overview](https://ehrlinger.github.io/ggBoostedTrees/articles/ggBoostedTrees.html), `vignette("ggBoostedTrees")`, fits one small simulated model and walks it through every figure, from the error path to partial effects, then finishes a plot with `+`.

## Related packages

- [ggRandomForests](https://github.com/ehrlinger/ggRandomForests) — the same
  idiom for random forests, covering `randomForestSRC`, `randomForest` and
  `varPro`.
- [boostmtree](https://cran.r-project.org/package=boostmtree) — the backend
  modelled here.
- [BoostMLR](https://cran.r-project.org/package=BoostMLR) — boosting for
  multivariate longitudinal responses, a supported second backend for
  `gg_boost_trajectory()`, `gg_boost_error()` and `gg_boost_path()`.
