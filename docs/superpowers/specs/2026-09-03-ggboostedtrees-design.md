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
Imports:  boostmtree (>= 2.0.1), ggplot2, dplyr, tidyr
Suggests: BoostMLR, patchwork, testthat, vdiffr, knitr, quarto, covr, lintr
Remotes:  ehrlinger/boostmtree_src@v2.0.2-ccf
```

The version floor and the `Remotes:` line exist because development runs against
a patched fork of `boostmtree`. See "Backend provenance" below; both lines are
removed at the release gate.

`boostmtree` is a hard dependency: it is the primary backend and its examples and
vignettes must always run.

`BoostMLR` is optional. Its CRAN release is dated 2023-10-26 with a quiet
maintainer, and a hard dependency would make `ggBoostedTrees` archivable if
`BoostMLR` is archived. Every `BoostMLR` code path — extractor, example, vignette
chunk, and test — is guarded by `requireNamespace("BoostMLR", quietly = TRUE)`.
This is the same guard pattern future optional backends will use, so the
extension mechanism is built once rather than retrofitted.

## Backend provenance: the boostmtree fork

Development runs against `ehrlinger/boostmtree_src@v2.0.2-ccf`, not CRAN
`boostmtree` 2.0.0. The fork carries fixes for three defects found in the CRAN
release: frozen residuals under `cv.flag = TRUE`, incorrect `na.action`
handling, and malformed dimnames from `vimp(joint = TRUE)`.

R resolves dependencies by package name and version, never by source. The fork
declares `Version: 2.0.2` while CRAN sits at `2.0.0`, so the floor
`boostmtree (>= 2.0.1)` is satisfiable only by the fork. This makes the fork
requirement machine-enforced rather than a README request: a CRAN install fails
resolution instead of silently supplying the defective backend. The `Remotes:`
line tells `pak` and `devtools` where to find it, accounting for the fork's
`subdir` layout.

This constraint reaches three parts of the package, and they are not equally
exposed.

### Dependency resolution

`Imports: boostmtree (>= 2.0.1)` and `Remotes: ehrlinger/boostmtree_src@v2.0.2-ccf`
are development-only. CRAN rejects a `Remotes:` field, and rejects a version
floor that no CRAN release satisfies. **Removing both is a mandatory item on the
release-gate checklist**, resolved either by upstream merging the fixes (floor
relaxed to whatever CRAN then offers) or by dropping the floor and documenting
the affected code paths.

### Extractor correctness

Only one of the three fixes can break extractor code, because only one changes
object *structure* rather than values:

| Fix | What it changes | Exposure |
|---|---|---|
| `cv.flag` frozen residuals | `mu` and `err.rate` values | Extractors unaffected; plotted values wrong under CRAN 2.0.0 |
| `na.action` handling | which rows survive the fit | None structurally |
| `vimp(joint = TRUE)` dimnames | structure of the vimp object | Real — `gg_boost_vimp` reads those dimnames |

No phase is *structurally* exposed except Interpretation. But structural
indifference is not the same as correctness, and the Foundation phase is
affected by values in a way first noticed while planning it:

**`gg_boost_error` requires a fit grown with `cv.flag = TRUE`.** Verified
against `boostmtree` 2.0.2 — a default fit records neither `err.rate` nor
`m.opt`, so there is no error path to extract at all. That makes the headline
Foundation figure a direct consumer of the exact code path the `cv.flag` fix
repairs. The extractor reads the same fields under either backend and will not
break, but under CRAN 2.0.0 it will faithfully plot the wrong error path and
the wrong optimal iteration.

The consequence is for examples and vignettes, not for the extractor code: any
`gg_boost_error` example is a `cv.flag = TRUE` example, and until upstream
merges the fix those must stay behind `\donttest` and out of the vignettes.

**Requirement:** `gg_boost_vimp` normalizes vimp dimnames defensively, handling
both the CRAN and fork shapes, rather than assuming the fork. This removes the
coupling for the one class that has it, at negligible cost.

**Open item:** the value-versus-structure classification above derives from prior
debugging sessions and has not been re-verified against the fork diff. It must be
confirmed before Interpretation-phase work begins. A direct
`git diff release_2_0_0 v2.0.2-ccf` is not usable for this — the fork moved
package files into a `boostmtree/` subdirectory, so the diff reads as pure
insertion.

### Test fixtures

Fixtures fitted under `v2.0.2-ccf` and stored as `.rds` bake the corrected values
in. Extraction tests read the `.rds` and never invoke the backend, so the suite
is insulated from backend version differences — a second argument for the fixture
strategy beyond check time.

The corollary is that a green suite does not demonstrate that a user running CRAN
`boostmtree` 2.0.0 gets correct figures. Fixtures therefore carry a provenance
record — backend package version and the exact fitting call — stored alongside
them, and are regenerated whenever the backend version changes.

### Strategic note

Phases 1 through 4 represent months of work, and the upstream fixes may merge
before the release gate is reached, in which case this section expires. The
architecture is not contorted around a constraint with a reasonable chance of
resolving itself: the fork is targeted during development, the removal stays on
the checklist, and only the single genuinely exposed extractor is written
defensively.

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
5. **Release gate** — removal of the `Remotes:` field and the `boostmtree`
   version floor (see "Backend provenance"), full CRAN Cookbook audit,
   `R CMD check --as-cran` with the manual built, reverse-dependency check,
   `urlchecker::url_check()`, and check-time profiling against the 10-minute
   budget.

Version numbers are assigned by the maintainer at each milestone; phases do not
imply minor-version bumps.

## Out of scope for version 1

- `gbm`, `xgboost`, `lightgbm`, and other cross-sectional boosting backends.
  These are already served by `vip`, `DALEX`, and `SHAPforxgboost`. The
  architecture admits them; version 1 does not ship them.
- Shared infrastructure extracted from `ggRandomForests`.
- Interactive or `plotly`-backed output.
