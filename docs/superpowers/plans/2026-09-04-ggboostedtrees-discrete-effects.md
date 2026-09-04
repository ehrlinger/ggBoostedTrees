# ggBoostedTrees: Discrete Covariates in Effect Figures

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `gg_boost_effect` handle factor covariates, which currently produce a blank plot, and close two smaller review findings.

**Architecture:** Unchanged three layers. The change widens one column contract and gives the renderer a second geometry.

**Tech Stack:** R (>= 4.4.0), `boostmtree` (>= 2.0.1, the CCF fork), `ggplot2`, `rlang`, `testthat` 3e, `vdiffr`, `roxygen2`.

## Why

A review of PR #5 found that `gg_boost_effect()` calls `as.numeric()` unconditionally on the covariate grid. Verified against the backend: `boostmtree` accepts factor predictors, and `partial.plot()` returns their `x` column as **character**. The extractor therefore emits coercion warnings, produces an all-`NA` `x`, and the renderer draws **0 of 18 rows** — a blank figure with warnings rather than an error. Treatment arm and sex are ordinary covariates in longitudinal models, so this is real data loss.

## Global Constraints

- Backend is the fork: `Remotes: boostmtree=ehrlinger/boostmtree_src/boostmtree@v2.0.2-ccf`. Do not touch that line, or `DESCRIPTION`'s `URL:` (its trailing slash is deliberate).
- `Depends: R (>= 4.4.0)`. No hvtiR family member in `Imports:` (that includes `ggRandomForests`).
- Fixtures are committed as `.rds` and never recomputed during `R CMD check`.
- Renderers return a bare `ggplot` with NO theme applied.
- Version is three-digit semantic (currently 0.0.4). PATCH digit only.
- `\donttest`, never `\dontrun`. `NAMESPACE`/`man/` roxygen-generated only.
- Run the suite with `Rscript -e 'devtools::test()'` — `pkgload::load_all()` + `testthat::test_file()` leaves `NOT_CRAN` unset and silently skips vdiffr snapshots.
- `lintr::lint_package()` must stay at 0.
- All `R/*.R` and `man/*.Rd` pure ASCII.
- Effect functions take `output = "data", verbose = FALSE`. There is **no** `plot.it` argument; passing one is swallowed by `...` and the call draws a figure.

## Verified backend facts

Confirmed empirically against `boostmtree` 2.0.2.

- `boostmtree()` accepts a factor column in `x` and fits without complaint.
- For a factor covariate, `partial.plot()$curves[[var]]$x` is **character**, with one row per level (2 rows for a two-level factor), not a grid.
- `marginal.plot()` is inconsistent: `$smooth[[var]][[k]]$x` is **character**, while `$data[[var]][[k]]$x` is a **factor**. Only `$smooth` is extracted, but any type check must tolerate both.
- A mixed request is legitimate: `partial.plot(fit, x.var.names = c("x1", "x2"))` with `x1` numeric and `x2` a factor returns `$curves$x1$x` numeric (20 rows) and `$curves$x2$x` character (2 rows).
- `ggplot2` permits one scale type per aesthetic across all facets, so a single figure cannot show continuous and discrete covariates together.

## Contract change

`gg_boost_effect` gains one column. The full contract becomes:

| Column | Type | Meaning |
|---|---|---|
| `variable` | factor | Covariate name |
| `x` | numeric | The covariate value; for a discrete covariate, the integer level index |
| `x_label` | character | The level label for a discrete covariate; `NA` for a continuous one |
| `time` | numeric | Time point |
| `estimate` | numeric | Fitted effect |
| `kind` | factor | `partial` or `marginal` |

`x` stays numeric so the continuous path is unchanged and the column has one type. `x_label` is what tells the renderer a variable is discrete, and what labels its axis.

---

### Task 1: Extractor supports discrete covariates

**Files:**
- Modify: `R/gg_boost_effect.R`
- Modify: `tests/testthat/fixtures/make-fixtures.R`
- Create: `tests/testthat/fixtures/effect_partial_factor.rds`
- Create: `tests/testthat/fixtures/effect_marginal_factor.rds`
- Modify: `tests/testthat/helper-fixtures.R`
- Modify: `tests/testthat/test-gg_boost_effect.R`

**Interfaces:**
- Produces: `gg_boost_effect()` returning the six-column contract above; helpers `partial_factor_fixture()` and `marginal_factor_fixture()`.

- [ ] **Step 1: Add the factor fixtures to the generator**

Append to `tests/testthat/fixtures/make-fixtures.R`. Note this fits its own small model with a factor covariate but **does not commit that fit** — only the effect objects, which are tiny.

```r
## Effect fixtures with a FACTOR covariate.
##
## boostmtree returns a character x column for a factor predictor, one row per
## level rather than a grid. The fit itself is not committed: only the effect
## objects are needed, and they are a few kilobytes.
set.seed(11)
fac.sim <- simLong(n = 20, n.time = 4, model = 1)$data.list
fac.x <- fac.sim$features
fac.x$x2 <- factor(ifelse(fac.x$x2 > median(fac.x$x2), "high", "low"))

fac.fit <- boostmtree(
  x = fac.x, tm = fac.sim$time, id = fac.sim$id, y = fac.sim$y,
  M = 20, cv.flag = TRUE, verbose = FALSE,
  control = boostmtree.control(seed = 11)
)

saveRDS(
  partial.plot(fac.fit, x.var.names = "x2", output = "data", verbose = FALSE),
  file.path(here, "effect_partial_factor.rds"), compress = "xz"
)
saveRDS(
  marginal.plot(fac.fit, x.var.names = "x2", output = "data", verbose = FALSE),
  file.path(here, "effect_marginal_factor.rds"), compress = "xz"
)

cat("wrote factor-covariate effect fixtures\n")
```

Add to the provenance `writeLines()` vector:

```r
    "",
    "Factor-covariate effect fixtures: effect_partial_factor.rds,",
    "  effect_marginal_factor.rds (covariate x2 as a two-level factor).",
    "  The underlying fit is deliberately NOT committed; only the effect",
    "  objects are needed and they are small.",
```

- [ ] **Step 2: Generate and confirm**

```bash
Rscript tests/testthat/fixtures/make-fixtures.R
ls -la tests/testthat/fixtures/*factor*
git status --short tests/testthat/fixtures/
```

Expected: two new small files (a few KB). `boost_continuous.rds` must remain unmodified — the guard prevents refitting it. If it is modified, STOP and report.

- [ ] **Step 3: Add the helpers**

Append to `tests/testthat/helper-fixtures.R`:

```r
# Effect fixtures whose covariate is a two-level factor. boostmtree returns a
# character x column for these, one row per level.
partial_factor_fixture <- function() {
  readRDS(testthat::test_path("fixtures", "effect_partial_factor.rds"))
}

marginal_factor_fixture <- function() {
  readRDS(testthat::test_path("fixtures", "effect_marginal_factor.rds"))
}
```

- [ ] **Step 4: Write the failing tests**

Append to `tests/testthat/test-gg_boost_effect.R`:

```r
test_that("the contract carries an x_label column", {
  gg <- gg_boost_effect(partial_fixture())

  expect_identical(
    names(gg), c("variable", "x", "x_label", "time", "estimate", "kind")
  )
  expect_type(gg$x_label, "character")
})

test_that("a continuous covariate leaves x_label NA", {
  gg <- gg_boost_effect(partial_fixture())

  expect_true(all(is.na(gg$x_label)))
})

test_that("a factor covariate is extracted without coercion warnings", {
  # The defect this fixes: as.numeric() on a character grid produced an
  # all-NA x, four coercion warnings, and a plot with zero rows.
  expect_no_warning(gg <- gg_boost_effect(partial_factor_fixture()))

  expect_false(any(is.na(gg$x)))
  expect_false(any(is.na(gg$x_label)))
})

test_that("factor levels become labels with integer positions", {
  gg <- gg_boost_effect(partial_factor_fixture())

  expect_setequal(unique(gg$x_label), c("high", "low"))
  expect_setequal(unique(gg$x), c(1, 2))
  # The position must map one-to-one onto the label, or the axis lies.
  expect_identical(
    length(unique(paste(gg$x, gg$x_label))), length(unique(gg$x_label))
  )
})

test_that("a discrete covariate yields one row per level per time", {
  p <- partial_factor_fixture()
  gg <- gg_boost_effect(p)

  expect_identical(nrow(gg), 2L * length(p$time.points))
})

test_that("the marginal factor path extracts without warnings", {
  expect_no_warning(gg <- gg_boost_effect(marginal_factor_fixture()))

  expect_setequal(unique(gg$x_label), c("high", "low"))
  expect_identical(levels(gg$kind), "marginal")
})
```

- [ ] **Step 5: Run to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "gg_boost_effect")'`
Expected: FAIL — the contract has five columns, and the factor tests warn and produce `NA`.

- [ ] **Step 6: Implement**

In `R/gg_boost_effect.R`, add a shared helper near `.gg_boost_effect_frame()`:

```r
# Resolve a covariate grid into a numeric position and an optional label.
#
# boostmtree returns a character (partial, marginal $smooth) or factor
# (marginal $data) x column for a factor predictor, with one row per level
# rather than a grid. Coercing that with as.numeric() silently produced an
# all-NA column and a blank figure, which is the defect this exists to prevent.
#
# A continuous covariate keeps its value in `x` and gets no label. A discrete
# one gets an integer position in `x` -- so the column keeps one type -- and
# its level in `x_label`, which is what the renderer puts on the axis.
.boost_effect_grid <- function(x) {
  if (is.numeric(x)) {
    return(list(x = as.numeric(x), x_label = NA_character_))
  }
  labels <- as.character(x)
  levels_seen <- unique(labels)
  list(
    x = as.numeric(match(labels, levels_seen)),
    x_label = labels
  )
}
```

Then in **both** methods, replace the `x = as.numeric(...)` assignment with a call to that helper, and add the `x_label` column in the contract's position (between `x` and `time`). In the partial method the grid is `wide[[1]]`; in the marginal method it is `curve$x`.

Resolve the grid **once per variable**, outside the per-time-point loop, so every time point of a variable shares one level ordering. Resolving it per time point would let two time points disagree about which level is position 1.

- [ ] **Step 7: Run the tests, the full suite, and lint**

```bash
Rscript -e 'roxygen2::roxygenise("."); devtools::test()'
Rscript -e 'pkgload::load_all("."); print(lintr::lint_package())'
```

Expected: 0 failures, 0 skips, 0 lints. The existing snapshot tests must still pass — the continuous path is unchanged, so a snapshot difference means the numeric path regressed. If a snapshot fails, STOP and report rather than accepting the new one.

- [ ] **Step 8: Update the roxygen contract and commit**

Document `x_label` in the `@return` block and explain the discrete case in `@details`. Then:

```bash
Rscript -e 'roxygen2::roxygenise(".")'
git add R/gg_boost_effect.R tests/ man/ NAMESPACE
git commit -m "fix: extract discrete covariates in gg_boost_effect"
```

---

### Task 2: Renderer draws discrete covariates

**Files:**
- Modify: `R/plot.gg_boost_effect.R`
- Modify: `tests/testthat/test-plot-gg_boost_effect.R`

**Interfaces:**
- Consumes: the six-column contract from Task 1.
- Produces: `autoplot.gg_boost_effect()` handling continuous, discrete, and mixed objects.

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-plot-gg_boost_effect.R`:

```r
test_that("a discrete covariate draws points on a labelled axis", {
  p <- ggplot2::autoplot(gg_boost_effect(partial_factor_fixture()))

  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  # Lines across a discrete axis would imply an ordering the data lacks.
  expect_true("GeomPoint" %in% geoms)
  expect_false("GeomLine" %in% geoms)
})

test_that("the discrete axis is labelled with levels, not positions", {
  p <- ggplot2::autoplot(gg_boost_effect(partial_factor_fixture()))
  built <- ggplot2::ggplot_build(p)

  labels <- as.character(built$layout$panel_params[[1]]$x$get_labels())
  expect_setequal(labels[!is.na(labels)], c("high", "low"))
})

test_that("a continuous covariate still draws lines", {
  p <- ggplot2::autoplot(gg_boost_effect(partial_fixture()))

  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_true("GeomLine" %in% geoms)
  expect_false("GeomPoint" %in% geoms)
})

test_that("a mixed object is refused with guidance", {
  mixed <- rbind(
    gg_boost_effect(partial_fixture()),
    gg_boost_effect(partial_factor_fixture())
  )
  class(mixed) <- c("gg_boost_effect", "data.frame")

  # ggplot2 allows one scale type per aesthetic across all facets, so a
  # continuous and a discrete covariate cannot share a figure.
  expect_error(ggplot2::autoplot(mixed), "one at a time")
})

test_that("the discrete effect plot is stable", {
  skip_on_cran()
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "effect partial factor",
    ggplot2::autoplot(gg_boost_effect(partial_factor_fixture()))
  )
})
```

- [ ] **Step 2: Run to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "plot-gg_boost_effect")'`
Expected: FAIL — the renderer draws lines against a numeric position and does not refuse mixed objects.

- [ ] **Step 3: Implement**

In `autoplot.gg_boost_effect()`, after the class check, decide the geometry from `x_label`:

```r
  # x_label is NA exactly for continuous covariates, so its pattern says which
  # geometry applies. ggplot2 permits one scale type per aesthetic across all
  # facets, so an object mixing the two cannot be drawn as one figure.
  discrete_by_variable <- tapply(
    !is.na(object$x_label), object$variable, any
  )
  discrete_by_variable <- discrete_by_variable[!is.na(discrete_by_variable)]

  if (length(unique(discrete_by_variable)) > 1L) {
    stop(
      "autoplot.gg_boost_effect: this object mixes continuous and discrete ",
      "covariates, which cannot share one figure. Extract and plot them one ",
      "at a time.",
      call. = FALSE
    )
  }
  discrete <- isTRUE(all(discrete_by_variable))
```

For the discrete branch map `x = .data[["x_label"]]` and use `geom_point(...)`; for the continuous branch keep the existing `x = .data[["x"]]` with `geom_line(...)` and its `group` mapping. Keep `labs()`, the colour mapping on `time`, and the `facet_wrap(~ variable, scales = "free_x")` shared between both branches rather than duplicating them per branch.

- [ ] **Step 4: Run, inspect the snapshot, accept**

```bash
Rscript -e 'roxygen2::roxygenise("."); devtools::test(filter = "plot-gg_boost_effect")'
```

Inspect the new SVG under `tests/testthat/_snaps/` before accepting: confirm it shows discrete points at two x positions labelled `high` and `low`, coloured by time, and no connecting lines. The three pre-existing effect snapshots must be unchanged — a diff there means the continuous path regressed. If so, STOP and report.

```bash
Rscript -e 'testthat::snapshot_accept()'
```

- [ ] **Step 5: Document, run the full suite and lint, commit**

Explain the two geometries and the mixed-object refusal in `@details`. Then:

```bash
Rscript -e 'roxygen2::roxygenise("."); devtools::test()'
Rscript -e 'pkgload::load_all("."); print(lintr::lint_package())'
git add R/ tests/ man/ NAMESPACE
git commit -m "feat: draw discrete covariates in the effect renderer"
```

---

### Task 3: Remaining review findings, docs, and check

**Files:**
- Modify: `R/gg_boost_effect.R`, `R/gg_boost_vimp.R`, `tests/testthat/test-gg_boost_vimp.R`
- Modify: `README.md`, `NEWS.md`, `DESCRIPTION`

- [ ] **Step 1: Correct the marginal `$data` documentation**

`R/gg_boost_effect.R` `@details` currently says `marginal.plot()`'s `$data` holds "the raw observations", "already reachable through `gg_boost_trajectory`". Both halves are wrong, verified: `$data` has one row per subject (25, against 189 observations) and matches neither the observed response nor the stored fitted values — it is the unsmoothed fitted prediction at each subject's observed covariate value. And `gg_boost_trajectory` carries no covariate column, so that scatter cannot be reconstructed from it.

Rewrite the sentence to say what `$data` actually is and why the smoothed curve is extracted instead. Do not overclaim a substitute.

- [ ] **Step 2: Validate the `components` argument**

Verified failures in `gg_boost_vimp()`:

- `components = c("main", "main")` reaches `factor()` and dies with a bare `factor level [2] is duplicated`, with no function prefix.
- `components = character(0)` produces `"records no importance for ."` — a dangling message.

Add validation before the existing unknown-component check: require a non-empty character vector, and de-duplicate while preserving order. Match the package's fail-loud style — function-name prefix, `call. = FALSE`, say what was wrong.

Add tests for both cases:

```r
test_that("gg_boost_vimp rejects an empty components vector", {
  expect_error(gg_boost_vimp(vimp_fixture(), components = character(0)),
               "gg_boost_vimp")
})

test_that("duplicate components are de-duplicated rather than erroring", {
  gg <- gg_boost_vimp(vimp_fixture(), components = c("main", "main"))

  expect_identical(levels(gg$component), "main")
  expect_identical(nrow(gg), 4L)
})
```

- [ ] **Step 3: Bump the patch version**

`DESCRIPTION` to `Version: 0.0.5`; `NEWS.md` line 2 to `Version: 0.0.5`. Add above the 0.0.4 section:

```markdown
# ggBoostedTrees 0.0.5

* `gg_boost_effect()` now handles factor covariates. It previously coerced
  their labels with `as.numeric()`, producing an all-`NA` covariate column and
  a blank figure. The contract gains an `x_label` column, and the renderer
  draws discrete covariates as points on a labelled axis.
* An object mixing continuous and discrete covariates is refused with
  guidance, since one figure permits only one scale type per aesthetic.
* `gg_boost_vimp()` validates `components`: an empty vector is rejected and
  duplicates are de-duplicated rather than reaching an opaque `factor()` error.
* Corrected the description of `marginal.plot()`'s `$data`, which holds
  unsmoothed fitted predictions rather than raw observations.
```

- [ ] **Step 4: Update the README**

In the "Figure data" table, extend the `gg_boost_effect()` row to mention that discrete covariates are supported. Check whether any sentence counting implemented figures needs updating — it has gone stale twice before.

- [ ] **Step 5: Verify everything**

```bash
Rscript -e 'roxygen2::roxygenise("."); devtools::test()'
Rscript -e 'pkgload::load_all("."); print(lintr::lint_package())'
Rscript -e 'pkgdown::check_pkgdown()'
Rscript -e 'urlchecker::url_check(".")'
```

Expected: 0 failures, 0 skips, 0 lints, no pkgdown problems, no invalid URLs.

- [ ] **Step 6: Run R CMD check from a clean export**

Commit first so `git archive HEAD` sees the changes.

```bash
TMP=$(mktemp -d) && git archive --format=tar HEAD | tar -x -C "$TMP" && \
  R CMD build "$TMP" && \
  _R_CHECK_FORCE_SUGGESTS_=false R CMD check --as-cran ggBoostedTrees_0.0.5.tar.gz
```

Expected: 0 errors, 0 warnings, exactly one NOTE — the `Remotes:` field note. Report every note and warning verbatim. Confirm no `Rplots.pdf` appears anywhere, and that all `R/*.R` and `man/*.Rd` are pure ASCII.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "docs: document discrete covariate support, bump to 0.0.5"
```

---

## Definition of done

- `gg_boost_effect()` extracts factor covariates without warnings, with `x_label` carrying levels and `x` their positions, consistent across time points.
- The renderer draws discrete covariates as points on a level-labelled axis, continuous ones as lines unchanged, and refuses mixed objects with guidance.
- The three pre-existing effect snapshots are unchanged.
- `gg_boost_vimp()` validates `components`.
- The `marginal.plot()` `$data` description is accurate.
- `R CMD check --as-cran` clean apart from the expected `Remotes:` note.
