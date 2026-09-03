# ggBoostedTrees — Design Specification

**Date:** 2026-09-03
**Status:** Approved design, pending implementation plan
**Author:** John Ehrlinger

## Summary

`ggBoostedTrees` is a new R package providing `ggplot2` graphics for boosted-tree
models. Version 1 covers `boostmtree` (hard dependency) and `BoostMLR` (optional),
the two gradient-boosting packages for longitudinal responses from Pande and
Ishwaran. The architecture admits additional backends — `gbm`, `xgboost`,
`lightgbm` — without changes to the rendering layer.

## Decision: new package, not an extension of ggRandomForests

`ggRandomForests` is not extended, for three reasons:

1. **Check-time budget.** `ggRandomForests` 4.0.0 imports `randomForestSRC`,
   `randomForest`, `varPro`, `igraph`, `survival`, and `patchwork`, and was
   archived on 2026-06-10 for exceeding CRAN's ~10-minute `R CMD check` limit.
   Adding two compiled dependencies and a vignette spends margin that is not
   there.
2. **Naming.** "Visually Exploring Random Forests" cannot honestly describe
   boosting diagnostics.
3. **Release coupling.** `ggRandomForests` v4 is a deliberate, human-reviewed
   CRAN line. Tying boosting work to its cadence slows both packages.

The two packages remain fully independent. The `gg_*` / `plot.gg_*` / `autoplot`
idiom is reproduced rather than shared; the small number of helpers needed
(ribbon styling, quantile points) are reimplemented. No third infrastructure
package is created.

## Dependencies

```
Imports:  boostmtree, ggplot2, dplyr, tidyr
Suggests: BoostMLR, patchwork, testthat, vdiffr, knitr, quarto, covr, lintr
```

`boostmtree` is a hard dependency: it is the primary backend and its examples and
vignettes must always run.

`BoostMLR` is optional. Its CRAN release is dated 2023-10-26 with a quiet
maintainer, and a hard dependency would make `ggBoostedTrees` archivable if
`BoostMLR` is archived. Every `BoostMLR` code path — extractor, example, vignette
chunk, and test — is guarded by `requireNamespace("BoostMLR", quietly = TRUE)`.
This is the same guard pattern future optional backends will use, so the
extension mechanism is built once rather than retrofitted.

### Known constraint: the boostmtree fork

CRAN `boostmtree` 2.0.0 is maintained by Kogalur and still contains the
`cv.flag`, `na.action`, and `vimp(joint = TRUE)` defects fixed locally in the
`v2.0.2-ccf` line. A CRAN release of `ggBoostedTrees` must import the CRAN
version. Version 1 examples and vignettes therefore avoid those code paths, or
gate them behind `\donttest`, until the upstream fixes are merged.

## Architecture

Three layers with a single direction of dependency:

```
model object  →  gg_boost_*()  →  tibble w/ documented columns  →  autoplot()  →  ggplot
   (backend)      (extractor,        (the contract)                 (renderer,
                   S3 on model)                                    S3 on gg class)
```

The tidy intermediate is the load-bearing element. Adding a backend means writing
new extractor methods only; no renderer changes. If adding a backend requires
touching a geom, the column contract is wrong and is corrected rather than
worked around.

`boostmtree` already contains most of the boostmtree-side extraction logic in the
internal `boostmtree.plot.data()` (`R/boostmtree_display.R:104`), which resolves
grow-versus-predict objects, unwraps the per-response list nesting, and emits
`iteration`/`value` frames. That logic is ported, not called, since it is not
exported.

### Classes and column contracts

| Class | Columns | boostmtree source |
|---|---|---|
| `gg_boost_error` | `iteration, value, response, optimal` | `err.rate[[q]][, "l2"]`, `m.opt` |
| `gg_boost_path` | `iteration, value, parameter, response` | `rho`, `phi`, `lambda` |
| `gg_boost_trajectory` | `id, time, fitted, observed, response` | `mu`, `y.org`, `time` |
| `gg_boost_vimp` | `variable, importance, response` | `vimp.boostmtree()` |
| `gg_boost_effect` | `variable, x, time, estimate, lower, upper, kind` | `partial.plot()`, `marginal.plot()` |

`parameter` in `gg_boost_path` and `kind` in `gg_boost_effect` are factors. This
lets one renderer produce a faceted multi-panel figure instead of requiring
several near-identical plot methods. Partial and marginal effects are one class
distinguished by `kind`, not two classes.

`response` carries the `q.label` for multivariate fits and holds a single level
for univariate fits, so faceting logic is uniform across both cases.

### File layout

One extractor file and one renderer file per class, mirroring `ggRandomForests`:
`R/gg_boost_error.R`, `R/plot.gg_boost_error.R`, and so on. Backend-specific
extractor methods live with their class. This keeps every file small and
single-purpose.

## User-facing API

Each class provides `autoplot.gg_boost_*()` as the implementation and
`plot.gg_boost_*()` as a thin alias. `autoplot()` is the `ggplot2`-native generic
and the primary documented entry point; `plot()` exists because users reach for
it by habit.

All renderers return an unrendered `ggplot` with no theme imposed, so faceting,
scales, and composition remain under user control. A `theme_boosted()` is
available as an opt-in addition, never a default.

`autoplot()` called on a model object directly (`autoplot.boostmtree()`)
dispatches to the error plot, since convergence is the first question asked. All
other figures require an explicit `gg_boost_*()` call.

`boost_diagnostics(x)` composes error, path, and trajectory panels into one
figure using `patchwork`. It is guarded, since `patchwork` is suggested.

## Testing

Tests split along the layer boundary so extraction bugs and geometry bugs fail as
different tests:

- **Extractors** — `testthat` assertions on column names, types, and values. No
  rendering, fast.
- **Renderers** — `vdiffr` snapshots.

Check time is the binding constraint, because `boostmtree` fits are slow. The
following are requirements, not optimizations:

- Fitted fixture models are saved as `.rds` under `tests/testthat/fixtures/` and
  never refit during `R CMD check`.
- Vignette computations are precomputed offline and stored, with a
  live-computation fallback.
- Examples requiring a real fit are wrapped in `\donttest`, never `\dontrun`.

## Phasing

1. **Foundation** — package skeleton, `gg_boost_error` and `gg_boost_path` for
   `boostmtree`, full test scaffold. Proves the three-layer architecture end to
   end on the two simplest figures.
2. **Longitudinal core** — `gg_boost_trajectory`. Carries the most design
   surface: subject sampling, observed-value overlay, multivariate faceting.
3. **Interpretation** — `gg_boost_vimp` and `gg_boost_effect`.
4. **Second backend** — `BoostMLR` extractors behind `requireNamespace()` guards.
   Validates the extension mechanism.
5. **Release gate** — full CRAN Cookbook audit, `R CMD check --as-cran` with the
   manual built, reverse-dependency check, `urlchecker::url_check()`, and
   check-time profiling against the 10-minute budget.

Version numbers are assigned by the maintainer at each milestone; phases do not
imply minor-version bumps.

## Out of scope for version 1

- `gbm`, `xgboost`, `lightgbm`, and other cross-sectional boosting backends.
  These are already served by `vip`, `DALEX`, and `SHAPforxgboost`. The
  architecture admits them; version 1 does not ship them.
- Shared infrastructure extracted from `ggRandomForests`.
- Interactive or `plotly`-backed output.
