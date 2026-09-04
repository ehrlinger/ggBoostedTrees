# ggBoostedTrees Phase 3: Interpretation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the two interpretation figures — `gg_boost_vimp` (variable importance) and `gg_boost_effect` (partial and marginal effects over time).

**Architecture:** Unchanged. An S3 extractor dispatching on the source object returns a tidy `data.frame` with a documented column contract and a `gg_boost_*` class; `autoplot()` renders it and `plot()` aliases it. The renderer knows only the data frame.

**Tech Stack:** R (>= 4.4.0), `boostmtree` (>= 2.0.1, the CCF fork), `ggplot2`, `rlang`, `testthat` 3e, `vdiffr`, `roxygen2`.

## Global Constraints

- Backend is the fork, declared as `Remotes: boostmtree=ehrlinger/boostmtree_src/boostmtree@v2.0.2-ccf`. The `boostmtree=` prefix and the `/boostmtree` subdir are both load-bearing. Do not touch that line.
- `DESCRIPTION` declares `Depends: R (>= 4.4.0)`. Do not raise it. Do not add any hvtiR family member to `Imports:` (that includes `ggRandomForests`).
- Fixtures are committed as `.rds` and never recomputed during `R CMD check`.
- Renderers return a bare `ggplot` with NO theme applied.
- Package version is three-digit semantic (currently 0.0.3). Bump the PATCH digit only. Never `.9000` or four digits.
- Examples that fit a model use `\donttest`, never `\dontrun`.
- `NAMESPACE` and `man/` are roxygen2-generated. Run `roxygen2::roxygenise(".")`; never hand-edit.
- Run the suite with `Rscript -e 'devtools::test()'`. `pkgload::load_all()` + `testthat::test_file()` leaves `NOT_CRAN` unset and silently skips the vdiffr snapshots.
- Lint clean against the committed `.lintr` (lintr 3.4.0). `dotted.case` is accepted deliberately.
- All `R/*.R` and `man/*.Rd` stay pure ASCII.

## Verified backend facts

Confirmed empirically against `boostmtree` 2.0.2 and the committed fixture. Do not re-derive.

### `vimp.boostmtree()`

- Returns a list of class `c("vimp.boostmtree", "boostmtree.vimp")`. **It is not a `boostmtree` object**, so `.boost_check_grow()` does not apply — this extractor needs its own type check.
- `$main` is a numeric matrix, variables by responses, `dimnames` `list(c("x1","x2","x3","x4"), "response")`.
- `$interaction` is the same shape but its **rownames carry a `:time` suffix**: `x1:time`, `x2:time`, ... The suffix must be stripped so `variable` is comparable across components.
- `$time.effect` is a named scalar per response (`names` = `"response"`). It has no variable to attach to.
- `$x.var.names`, `$q.set`, `$family`, `$joint`, `$metric`, `$baseline.rmse`, `$m.opt` are also present. `$metric` is the string `"relative increase in OOB RMSE"` and belongs on the plot's axis.
- With `joint = TRUE`: `$main` is 1x1 with rowname `joint.vimp`, `$interaction` is 1x1 with rowname `joint.vimp:time`.
- `vimp()` is fast (about 0.1s on the fixture).
- **CRAN `boostmtree` 2.0.0 cannot produce a joint vimp object at all** — it raises `Error: length of 'dimnames' [1] not equal to array extent`. No compatibility layer is needed or wanted; see the spec's Backend provenance section.

### `partial.plot()` and `marginal.plot()`

- Both return class `c("<kind>.plot.boostmtree", "boostmtree.effect.plot")`.
- Both take `x.var.names` (NOT `xvar.names` — a wrong name is silently swallowed by `...` and every variable is computed).
- `partial.plot()` returns `$curves[[var]]`: a wide data frame with column `x` plus one column per time point, named `time.0.50`, `time.0.75`, and so on. One row per grid point.
- `marginal.plot()` returns `$data[[var]]` (raw scatter) and `$smooth[[var]]` (smoothed curve). Each is a list keyed `"time = 0.50"`, `"time = 0.75"`, ..., whose elements are data frames with columns `x` and `y`.
- **Take `$smooth` for the marginal kind**, so both levels of `kind` mean "the fitted effect". The raw `$data` scatter is the observed data and is already reachable through `gg_boost_trajectory`.
- Both carry `$time.points` (numeric), `$x.var.names`, `$response.labels`, `$family`, `$M`.
- Neither computes a confidence interval. There are no `lower`/`upper` columns to extract.
- `partial.plot()` costs about 4.5 seconds for a single variable — far too slow to run inside `R CMD check`, hence the committed fixtures.

---

### Task 1: Interpretation fixtures

**Files:**
- Modify: `tests/testthat/fixtures/make-fixtures.R`
- Create: `tests/testthat/fixtures/vimp_marginal.rds`
- Create: `tests/testthat/fixtures/vimp_joint.rds`
- Create: `tests/testthat/fixtures/effect_partial.rds`
- Create: `tests/testthat/fixtures/effect_marginal.rds`
- Modify: `tests/testthat/fixtures/boost_continuous.dcf`
- Modify: `tests/testthat/helper-fixtures.R`
- Modify: `tests/testthat/test-fixtures.R`

**Interfaces:**
- Produces: `vimp_fixture()`, `vimp_joint_fixture()`, `partial_fixture()`, `marginal_fixture()`, each reading a committed `.rds`.

- [ ] **Step 1: Extend the generation script**

Append to `tests/testthat/fixtures/make-fixtures.R`, after the existing fixture is written and while `fit` is still in scope:

```r
## Interpretation fixtures (Phase 3).
##
## vimp() is cheap but partial.plot() costs seconds per variable, which is far
## too slow for R CMD check. All four are committed and read from disk.
##
## Two variables is enough: it exercises the per-variable list structure while
## keeping generation quick and the files small.
effect.vars <- c("x1", "x2")

saveRDS(
  vimp.boostmtree(fit),
  file.path(here, "vimp_marginal.rds"), compress = "xz"
)
saveRDS(
  vimp.boostmtree(fit, joint = TRUE),
  file.path(here, "vimp_joint.rds"), compress = "xz"
)
saveRDS(
  partial.plot(fit, x.var.names = effect.vars, plot.it = FALSE),
  file.path(here, "effect_partial.rds"), compress = "xz"
)
saveRDS(
  marginal.plot(fit, x.var.names = effect.vars, plot.it = FALSE),
  file.path(here, "effect_marginal.rds"), compress = "xz"
)

cat("wrote interpretation fixtures for", paste(effect.vars, collapse = ", "), "\n")
```

Also extend the provenance block so the `.dcf` records these. Add these lines to the `writeLines()` character vector, before the closing `)`:

```r
    "",
    "Interpretation fixtures: vimp_marginal.rds, vimp_joint.rds,",
    "  effect_partial.rds, effect_marginal.rds",
    "Effect variables: x1, x2",
    "Note: vimp(joint = TRUE) CANNOT be generated under CRAN boostmtree 2.0.0,",
    "  which raises 'length of dimnames [1] not equal to array extent'.",
    "  The fork is required to regenerate vimp_joint.rds."
```

- [ ] **Step 2: Regenerate the fixtures**

```bash
Rscript tests/testthat/fixtures/make-fixtures.R
ls -la tests/testthat/fixtures/
```

Expected: `wrote fixture, m.opt = 19` then `wrote interpretation fixtures for x1, x2`. The four new files are small — roughly 400 bytes to 5 KB each. If any is dramatically larger, STOP and report.

`boost_continuous.rds` is regenerated too and must come out byte-identical to the committed one, since the recipe is unchanged and seeded. Confirm with `git status` that it is NOT modified. If it is, STOP and report — that means the fixture is not reproducible, which invalidates the provenance record.

- [ ] **Step 3: Add the helpers**

Append to `tests/testthat/helper-fixtures.R`:

```r
# Interpretation fixtures. Read from disk, never recomputed -- partial.plot()
# costs seconds per variable. See fixtures/make-fixtures.R.
vimp_fixture <- function() {
  readRDS(testthat::test_path("fixtures", "vimp_marginal.rds"))
}

vimp_joint_fixture <- function() {
  readRDS(testthat::test_path("fixtures", "vimp_joint.rds"))
}

partial_fixture <- function() {
  readRDS(testthat::test_path("fixtures", "effect_partial.rds"))
}

marginal_fixture <- function() {
  readRDS(testthat::test_path("fixtures", "effect_marginal.rds"))
}
```

- [ ] **Step 4: Assert the fixture shapes**

Append to `tests/testthat/test-fixtures.R`:

```r
test_that("the vimp fixtures carry the shapes the extractor reads", {
  v <- vimp_fixture()

  expect_s3_class(v, "vimp.boostmtree")
  expect_true(is.matrix(v$main))
  expect_true(is.matrix(v$interaction))
  expect_identical(rownames(v$main), c("x1", "x2", "x3", "x4"))
  # The interaction rownames carry a :time suffix the extractor must strip.
  expect_identical(rownames(v$interaction), paste0(c("x1", "x2", "x3", "x4"), ":time"))
  expect_false(v$joint)
})

test_that("the joint vimp fixture collapses to one row", {
  v <- vimp_joint_fixture()

  expect_true(v$joint)
  expect_identical(dim(v$main), c(1L, 1L))
  expect_identical(rownames(v$main), "joint.vimp")
  expect_identical(rownames(v$interaction), "joint.vimp:time")
})

test_that("the partial fixture is a wide curve frame per variable", {
  p <- partial_fixture()

  expect_s3_class(p, "partial.plot.boostmtree")
  expect_identical(names(p$curves), c("x1", "x2"))
  expect_identical(names(p$curves$x1)[1], "x")
  expect_true(all(grepl("^time\\.", names(p$curves$x1)[-1])))
  expect_length(p$time.points, ncol(p$curves$x1) - 1L)
})

test_that("the marginal fixture carries raw and smoothed curves", {
  m <- marginal_fixture()

  expect_s3_class(m, "marginal.plot.boostmtree")
  expect_identical(names(m$smooth), c("x1", "x2"))
  expect_true(all(grepl("^time = ", names(m$smooth$x1))))
  expect_identical(names(m$smooth$x1[[1]]), c("x", "y"))
  # The raw scatter is deliberately not extracted; see the spec.
  expect_false(is.null(m$data))
})
```

- [ ] **Step 5: Run and commit**

```bash
Rscript -e 'devtools::test(filter = "fixtures")'
git add tests/testthat/fixtures/ tests/testthat/helper-fixtures.R tests/testthat/test-fixtures.R
git commit -m "test: add interpretation fixtures for vimp and effect extractors"
```

Expected: PASS, 0 failures.

---

### Task 2: `gg_boost_vimp` extractor

**Files:**
- Create: `R/gg_boost_vimp.R`
- Create: `tests/testthat/test-gg_boost_vimp.R`

**Interfaces:**
- Consumes: `%||%` from `R/utils.R`; `vimp_fixture()`, `vimp_joint_fixture()`.
- Produces: `gg_boost_vimp(object, components = c("main", "interaction"), ...)` returning a `data.frame` of class `c("gg_boost_vimp", "data.frame")` with columns `variable` (factor), `importance` (numeric), `component` (factor), `response` (factor), carrying attributes `metric` and `time.effect`.

- [ ] **Step 1: Write the failing tests**

Create `tests/testthat/test-gg_boost_vimp.R`:

```r
test_that("gg_boost_vimp returns the documented column contract", {
  gg <- gg_boost_vimp(vimp_fixture())

  expect_s3_class(gg, "gg_boost_vimp")
  expect_identical(
    names(gg), c("variable", "importance", "component", "response")
  )
  expect_s3_class(gg$variable, "factor")
  expect_type(gg$importance, "double")
  expect_s3_class(gg$component, "factor")
  expect_s3_class(gg$response, "factor")
})

test_that("both components are returned by default", {
  gg <- gg_boost_vimp(vimp_fixture())

  expect_identical(levels(gg$component), c("main", "interaction"))
  expect_identical(nrow(gg), 8L)
})

test_that("components can be selected", {
  gg <- gg_boost_vimp(vimp_fixture(), components = "main")

  expect_identical(levels(gg$component), "main")
  expect_identical(nrow(gg), 4L)
})

test_that("the :time suffix is stripped from interaction variable names", {
  gg <- gg_boost_vimp(vimp_fixture())

  # Without stripping, a variable would appear twice under different labels
  # and could never be compared or dodged across components.
  expect_identical(levels(gg$variable), c("x1", "x2", "x3", "x4"))
  expect_false(any(grepl(":time", gg$variable, fixed = TRUE)))
})

test_that("importance values come from the matching component matrix", {
  v <- vimp_fixture()
  gg <- gg_boost_vimp(v)

  expect_equal(
    gg$importance[gg$component == "main"], unname(v$main[, 1])
  )
  expect_equal(
    gg$importance[gg$component == "interaction"], unname(v$interaction[, 1])
  )
})

test_that("the metric and time effect ride along as attributes", {
  v <- vimp_fixture()
  gg <- gg_boost_vimp(v)

  expect_identical(attr(gg, "metric"), v$metric)
  expect_equal(attr(gg, "time.effect"), v$time.effect)
})

test_that("a joint vimp object collapses to one variable", {
  gg <- gg_boost_vimp(vimp_joint_fixture())

  expect_identical(levels(gg$variable), "joint.vimp")
  expect_identical(nrow(gg), 2L)
})

test_that("gg_boost_vimp rejects an unknown component", {
  expect_error(gg_boost_vimp(vimp_fixture(), components = "spurious"),
               "spurious")
})

test_that("gg_boost_vimp fails loud on a component/response shape mismatch", {
  v <- vimp_fixture()
  v$main <- v$main[, 0, drop = FALSE]

  expect_error(gg_boost_vimp(v), "column")
})

test_that("gg_boost_vimp rejects a non-vimp object", {
  expect_error(gg_boost_vimp(data.frame(x = 1)), "gg_boost_vimp")
  # A fitted model is the most likely wrong input, so name it specifically.
  expect_error(gg_boost_vimp(boost_fixture()), "vimp.boostmtree")
})
```

- [ ] **Step 2: Run to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "gg_boost_vimp")'`
Expected: FAIL — `could not find function "gg_boost_vimp"`

- [ ] **Step 3: Write the extractor**

Create `R/gg_boost_vimp.R`:

```r
#' Variable importance data object
#'
#' Extract variable importance from a \code{\link[boostmtree]{vimp.boostmtree}}
#' object, for both the main effect of each covariate and its interaction with
#' time.
#'
#' @details
#' `boostmtree` reports importance in two parts. The main effect asks what is
#' lost by perturbing a covariate; the interaction asks what is lost by
#' perturbing its interaction with time. For a longitudinal model the second is
#' often the interesting one, since it is where a covariate whose effect
#' *changes* over follow-up shows up.
#'
#' `boostmtree` labels the interaction rows `x1:time`, `x2:time` and so on. The
#' suffix is stripped here, so a variable carries one label across both
#' components and can be compared or dodged against itself.
#'
#' The importance metric is a string on the source object rather than a fixed
#' quantity, so it travels as the `metric` attribute and the renderer uses it to
#' label the axis. The overall time effect has no variable to attach to and
#' travels as the `time.effect` attribute.
#'
#' A joint importance object (`vimp(joint = TRUE)`) reports a single combined
#' value, labelled `joint.vimp`. Note that CRAN `boostmtree` 2.0.0 cannot
#' produce one at all; the patched build this package requires is needed to
#' compute it.
#'
#' @param object A \code{\link[boostmtree]{vimp.boostmtree}} object.
#' @param components Character vector naming the components to extract, any of
#'   `"main"` and `"interaction"`. Defaults to both.
#' @param ... Not used; present for S3 consistency.
#'
#' @return A `gg_boost_vimp` `data.frame` with columns:
#'   \describe{
#'     \item{variable}{Factor covariate name.}
#'     \item{importance}{Numeric importance.}
#'     \item{component}{Factor, `main` or `interaction`.}
#'     \item{response}{Factor naming the response.}
#'   }
#'   with attributes `metric` (the importance metric) and `time.effect`.
#'
#' @seealso \code{\link{plot.gg_boost_vimp}}, \code{\link{gg_boost_effect}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' fit <- boostmtree::boostmtree(
#'   x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, verbose = FALSE
#' )
#' plot(gg_boost_vimp(boostmtree::vimp.boostmtree(fit)))
#' }
#'
#' @export
gg_boost_vimp <- function(object, components = c("main", "interaction"), ...) {
  UseMethod("gg_boost_vimp", object)
}

# Only reached for objects that are not vimp results; see gg_boost_error.
#' @export
gg_boost_vimp.default <- function(object,
                                  components = c("main", "interaction"),
                                  ...) {
  stop(
    "gg_boost_vimp: expected a 'vimp.boostmtree' object; got an object of ",
    "class ", paste(class(object), collapse = "/"),
    ". Produce one with boostmtree::vimp.boostmtree(fit).",
    call. = FALSE
  )
}

#' @export
gg_boost_vimp.vimp.boostmtree <- function(object,
                                          components = c("main", "interaction"),
                                          ...) {
  known <- c("main", "interaction")
  unknown <- setdiff(components, known)
  if (length(unknown) > 0L) {
    stop(
      "gg_boost_vimp: unknown component ",
      paste(sQuote(unknown), collapse = ", "),
      ". Expected any of ", paste(sQuote(known), collapse = ", "), ".",
      call. = FALSE
    )
  }

  present <- components[vapply(
    components, function(cm) !is.null(object[[cm]]), logical(1)
  )]
  if (length(present) == 0L) {
    stop(
      "gg_boost_vimp: this object records no importance for ",
      paste(sQuote(components), collapse = ", "), ".",
      call. = FALSE
    )
  }

  # Variable labels come from the main matrix when it is present, because the
  # interaction rownames carry a ':time' suffix that must not leak into the
  # factor levels.
  strip_time <- function(x) sub(":time$", "", x)
  reference <- object[[present[1]]]
  var_levels <- strip_time(rownames(reference))

  blocks <- lapply(present, function(cm) {
    mat <- object[[cm]]
    if (ncol(mat) < 1L) {
      stop(
        "gg_boost_vimp: the '", cm, "' component has no response column.",
        call. = FALSE
      )
    }
    variables <- strip_time(rownames(mat))
    if (!identical(variables, var_levels)) {
      stop(
        "gg_boost_vimp: the '", cm, "' component names ", length(variables),
        " variable(s) that do not match the ", length(var_levels),
        " in '", present[1], "'.",
        call. = FALSE
      )
    }
    response_labels <- colnames(mat) %||% paste0("y", seq_len(ncol(mat)))

    do.call(rbind, lapply(seq_len(ncol(mat)), function(q) {
      data.frame(
        variable = factor(variables, levels = var_levels),
        importance = as.numeric(mat[, q]),
        component = factor(cm, levels = present),
        response = factor(response_labels[q], levels = response_labels),
        stringsAsFactors = FALSE
      )
    }))
  })

  gg_dta <- do.call(rbind, blocks)
  rownames(gg_dta) <- NULL
  class(gg_dta) <- c("gg_boost_vimp", class(gg_dta))
  attr(gg_dta, "metric") <- object$metric
  attr(gg_dta, "time.effect") <- object$time.effect
  gg_dta
}
```

- [ ] **Step 4: Run the tests, the full suite, and lint**

```bash
Rscript -e 'roxygen2::roxygenise("."); devtools::test()'
Rscript -e 'pkgload::load_all("."); print(lintr::lint_package())'
```

Expected: 0 failures, 0 skips; no lints.

- [ ] **Step 5: Commit**

```bash
git add R/gg_boost_vimp.R tests/ NAMESPACE man/
git commit -m "feat: add gg_boost_vimp extractor"
```

---

### Task 3: `gg_boost_vimp` renderer

**Files:**
- Create: `R/plot.gg_boost_vimp.R`
- Create: `tests/testthat/test-plot-gg_boost_vimp.R`

**Interfaces:**
- Consumes: `gg_boost_vimp()`.
- Produces: `autoplot.gg_boost_vimp(object, ...)` returning a `ggplot`; `plot.gg_boost_vimp(x, ...)` aliasing it.

Design: a horizontal bar chart, variables ordered by importance, faceted by component. Horizontal because variable names are text and read better along the y axis; ordered because an unordered importance chart is nearly unreadable. The metric attribute labels the x axis.

- [ ] **Step 1: Write the failing tests**

Create `tests/testthat/test-plot-gg_boost_vimp.R`:

```r
test_that("autoplot returns a ggplot", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_fixture()))

  expect_s3_class(p, "ggplot")
})

test_that("plot is an alias for autoplot", {
  gg <- gg_boost_vimp(vimp_fixture())

  b1 <- ggplot2::ggplot_build(plot(gg))
  b2 <- ggplot2::ggplot_build(ggplot2::autoplot(gg))

  # Compare BUILT plots, not the ggplot objects. aes() quosures capture
  # S3-dispatch bookkeeping (.Generic, .Method, ...) from the calling frame.
  expect_equal(b1$data, b2$data)
  expect_equal(b1$layout$layout, b2$layout$layout)
})

test_that("the renderer rejects a foreign object", {
  expect_error(plot.gg_boost_vimp(data.frame(x = 1)), "gg_boost_vimp")
})

test_that("the x axis is labelled with the metric from the source object", {
  v <- vimp_fixture()
  p <- ggplot2::autoplot(gg_boost_vimp(v))

  # coord_flip() swaps the drawn axes but not the aesthetic names, so the
  # metric lives on $labels$y and is drawn horizontally. Verified.
  #
  # The metric is a property of how vimp was computed, not a constant, so a
  # hard-coded axis label would be a lie on some objects.
  expect_identical(p$labels$y, v$metric)
  expect_identical(p$labels$x, "Variable")
})

test_that("variables are ordered by importance rather than by name", {
  gg <- gg_boost_vimp(vimp_fixture(), components = "main")
  p <- ggplot2::autoplot(gg)

  ord <- order(gg$importance)
  expect_identical(levels(p$data$variable), as.character(gg$variable[ord]))
})

test_that("components are faceted", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_fixture()))

  expect_s3_class(p$facet, "FacetWrap")
})

test_that("a single component draws without facets", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_fixture(), components = "main"))

  expect_s3_class(p$facet, "FacetNull")
})

test_that("the importance plot is stable", {
  skip_on_cran()
  # Text rendering is not byte-identical across platforms, and the committed
  # reference SVGs were generated on macOS.
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "vimp both components",
    ggplot2::autoplot(gg_boost_vimp(vimp_fixture()))
  )
})

test_that("the joint importance plot is stable", {
  skip_on_cran()
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "vimp joint",
    ggplot2::autoplot(gg_boost_vimp(vimp_joint_fixture()))
  )
})
```

- [ ] **Step 2: Run to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "plot-gg_boost_vimp")'`
Expected: FAIL — no applicable method for `autoplot`

- [ ] **Step 3: Write the renderer**

Create `R/plot.gg_boost_vimp.R`:

```r
#' Plot a \code{\link{gg_boost_vimp}} object
#'
#' Variable importance as a horizontal bar chart, ordered by importance and
#' faceted by component.
#'
#' @details
#' Bars run horizontally because variable names are text and read better along
#' the y axis than rotated beneath it, and variables are ordered by importance
#' because an importance chart in arbitrary order is close to unreadable.
#'
#' The x axis is labelled with the `metric` attribute carried by the extracted
#' object. That metric is a property of how importance was computed rather than
#' a fixed quantity, so a hard-coded label would misdescribe some objects.
#'
#' A negative importance is not an error: with a permutation-style metric a
#' variable that contributes nothing can score slightly below zero by chance.
#'
#' The returned plot carries no theme.
#'
#' @param object A \code{\link{gg_boost_vimp}} object.
#' @param x A \code{\link{gg_boost_vimp}} object.
#' @param ... Passed to \code{\link[ggplot2]{geom_col}}.
#'
#' @return A `ggplot` object.
#'
#' @seealso \code{\link{gg_boost_vimp}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' fit <- boostmtree::boostmtree(
#'   x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, verbose = FALSE
#' )
#' plot(gg_boost_vimp(boostmtree::vimp.boostmtree(fit)))
#' }
#'
#' @importFrom ggplot2 autoplot ggplot aes geom_col coord_flip facet_wrap labs
#' @export
autoplot.gg_boost_vimp <- function(object, ...) {
  if (!inherits(object, "gg_boost_vimp")) {
    stop("Incorrect object type: expected a gg_boost_vimp object.",
         call. = FALSE)
  }

  # Order by the largest importance a variable reaches in any component, so
  # both facets share one ordering and a variable sits on the same row in each.
  by_variable <- tapply(object$importance, object$variable, max, na.rm = TRUE)
  ordered_levels <- names(sort(by_variable))
  object$variable <- factor(as.character(object$variable),
                            levels = ordered_levels)

  metric <- attr(object, "metric") %||% "Importance"

  gg_plt <- ggplot2::ggplot(
    object,
    ggplot2::aes(x = .data[["variable"]], y = .data[["importance"]])
  ) +
    ggplot2::geom_col(...) +
    ggplot2::coord_flip() +
    ggplot2::labs(x = "Variable", y = metric)

  if (nlevels(object$component) > 1L) {
    gg_plt <- gg_plt + ggplot2::facet_wrap(~ component)
  }
  if (nlevels(object$response) > 1L) {
    gg_plt <- gg_plt +
      ggplot2::facet_wrap(~ component + response)
  }

  gg_plt
}

#' @rdname autoplot.gg_boost_vimp
#' @export
plot.gg_boost_vimp <- function(x, ...) {
  autoplot.gg_boost_vimp(x, ...)
}
```

Note: `coord_flip()` swaps the drawn axes but not the aesthetic names. Verified: with `labs(x = "Variable", y = metric)`, `p$labels$y` holds the metric and is what appears on the horizontal axis. The test above asserts that, and needs no adjustment.

- [ ] **Step 4: Run the tests and accept the snapshots**

```bash
Rscript -e 'roxygen2::roxygenise("."); devtools::test(filter = "plot-gg_boost_vimp")'
```

Inspect the generated SVGs under `tests/testthat/_snaps/` before accepting: confirm the first has two facet panels with four horizontal bars each, and the second a single bar labelled `joint.vimp`. If a snapshot is empty or wrong, STOP and report.

```bash
Rscript -e 'testthat::snapshot_accept()'
```

- [ ] **Step 5: Run the full suite and lint, then commit**

```bash
Rscript -e 'devtools::test()'
Rscript -e 'pkgload::load_all("."); print(lintr::lint_package())'
git add R/ tests/ NAMESPACE man/
git commit -m "feat: add gg_boost_vimp renderer"
```

---

### Task 4: `gg_boost_effect` extractor and renderer

**Files:**
- Create: `R/gg_boost_effect.R`
- Create: `R/plot.gg_boost_effect.R`
- Create: `tests/testthat/test-gg_boost_effect.R`
- Create: `tests/testthat/test-plot-gg_boost_effect.R`

**Interfaces:**
- Consumes: `%||%`; `partial_fixture()`, `marginal_fixture()`.
- Produces: `gg_boost_effect(object, ...)` returning a `data.frame` of class `c("gg_boost_effect", "data.frame")` with columns `variable` (factor), `x` (numeric), `time` (numeric), `estimate` (numeric), `kind` (factor); and `autoplot.gg_boost_effect(object, ...)` / `plot.gg_boost_effect(x, ...)`.

This task pairs the extractor and renderer because the two source shapes are asymmetric and the renderer is short — splitting them would put a review gate in the middle of one idea.

- [ ] **Step 1: Write the failing extractor tests**

Create `tests/testthat/test-gg_boost_effect.R`:

```r
test_that("gg_boost_effect returns the documented column contract", {
  gg <- gg_boost_effect(partial_fixture())

  expect_s3_class(gg, "gg_boost_effect")
  expect_identical(
    names(gg), c("variable", "x", "time", "estimate", "kind")
  )
  expect_s3_class(gg$variable, "factor")
  expect_type(gg$x, "double")
  expect_type(gg$time, "double")
  expect_type(gg$estimate, "double")
  expect_s3_class(gg$kind, "factor")
})

test_that("a partial object is labelled partial", {
  gg <- gg_boost_effect(partial_fixture())

  expect_identical(levels(gg$kind), "partial")
})

test_that("a marginal object is labelled marginal", {
  gg <- gg_boost_effect(marginal_fixture())

  expect_identical(levels(gg$kind), "marginal")
})

test_that("every variable and time point becomes rows", {
  p <- partial_fixture()
  gg <- gg_boost_effect(p)

  expect_identical(levels(gg$variable), c("x1", "x2"))
  expect_setequal(unique(gg$time), p$time.points)
  expect_identical(
    nrow(gg),
    nrow(p$curves$x1) * length(p$time.points) * length(p$curves)
  )
})

test_that("partial estimates are the wide curve columns pivoted long", {
  p <- partial_fixture()
  gg <- gg_boost_effect(p)

  first <- gg[gg$variable == "x1" & gg$time == p$time.points[1], ]
  expect_equal(first$x, p$curves$x1$x)
  expect_equal(first$estimate, p$curves$x1[[2]])
})

test_that("time is parsed to a number, not left as a label", {
  gg <- gg_boost_effect(marginal_fixture())

  expect_type(gg$time, "double")
  expect_false(any(is.na(gg$time)))
  expect_setequal(unique(gg$time), marginal_fixture()$time.points)
})

test_that("the marginal kind takes the smoothed curve, not the raw scatter", {
  m <- marginal_fixture()
  gg <- gg_boost_effect(m)

  first <- gg[gg$variable == "x1" & gg$time == m$time.points[1], ]
  expect_equal(first$x, m$smooth$x1[[1]]$x)
  expect_equal(first$estimate, m$smooth$x1[[1]]$y)
})

test_that("gg_boost_effect rejects a non-effect object", {
  expect_error(gg_boost_effect(data.frame(x = 1)), "gg_boost_effect")
  expect_error(gg_boost_effect(boost_fixture()), "partial.plot")
})
```

- [ ] **Step 2: Run to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "gg_boost_effect")'`
Expected: FAIL — `could not find function "gg_boost_effect"`

- [ ] **Step 3: Write the extractor**

Create `R/gg_boost_effect.R`:

```r
#' Partial and marginal effect data object
#'
#' Extract covariate effect curves over time from a
#' \code{\link[boostmtree]{partial.plot}} or
#' \code{\link[boostmtree]{marginal.plot}} object.
#'
#' @details
#' The two differ in what they hold constant. A partial effect varies one
#' covariate while averaging over the others; a marginal effect reads the fitted
#' surface as the data actually distribute it. Both are covariate-by-time
#' surfaces, so both land in this one class, distinguished by `kind`.
#'
#' `marginal.plot()` returns a raw scatter alongside its smoothed curve. The
#' smoothed curve is what is extracted, so that both levels of `kind` mean the
#' same thing: the fitted effect. The raw observations are available through
#' \code{\link{gg_boost_trajectory}}.
#'
#' Neither source computes a confidence interval, so none is reported here.
#'
#' @param object A `partial.plot.boostmtree` or `marginal.plot.boostmtree`
#'   object, as returned by `boostmtree::partial.plot()` or
#'   `boostmtree::marginal.plot()` with `plot.it = FALSE`.
#' @param ... Not used; present for S3 consistency.
#'
#' @return A `gg_boost_effect` `data.frame` with columns:
#'   \describe{
#'     \item{variable}{Factor covariate name.}
#'     \item{x}{Numeric covariate value.}
#'     \item{time}{Numeric time point.}
#'     \item{estimate}{Numeric fitted effect.}
#'     \item{kind}{Factor, `partial` or `marginal`.}
#'   }
#'
#' @seealso \code{\link{plot.gg_boost_effect}}, \code{\link{gg_boost_vimp}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' fit <- boostmtree::boostmtree(
#'   x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, verbose = FALSE
#' )
#' pp <- boostmtree::partial.plot(fit, x.var.names = "x1", plot.it = FALSE)
#' plot(gg_boost_effect(pp))
#' }
#'
#' @export
gg_boost_effect <- function(object, ...) {
  UseMethod("gg_boost_effect", object)
}

# Only reached for objects that are neither effect type; see gg_boost_error.
#' @export
gg_boost_effect.default <- function(object, ...) {
  stop(
    "gg_boost_effect: expected a 'partial.plot.boostmtree' or ",
    "'marginal.plot.boostmtree' object; got an object of class ",
    paste(class(object), collapse = "/"),
    ". Produce one with boostmtree::partial.plot(fit, plot.it = FALSE).",
    call. = FALSE
  )
}

#' @export
gg_boost_effect.partial.plot.boostmtree <- function(object, ...) {
  curves <- object$curves
  if (is.null(curves) || length(curves) == 0L) {
    stop("gg_boost_effect: this object records no effect curves.",
         call. = FALSE)
  }
  time_points <- object$time.points
  var_levels <- names(curves)

  blocks <- lapply(var_levels, function(nm) {
    wide <- curves[[nm]]
    # Column 1 is the covariate grid; the rest are one column per time point,
    # named time.0.50 and so on. Take the times from $time.points rather than
    # parsing those labels, so precision is not lost to the label's rounding.
    value_cols <- seq_len(ncol(wide))[-1]
    if (length(value_cols) != length(time_points)) {
      stop(
        "gg_boost_effect: variable '", nm, "' has ", length(value_cols),
        " curve column(s) but the object records ", length(time_points),
        " time point(s).",
        call. = FALSE
      )
    }
    do.call(rbind, lapply(seq_along(value_cols), function(k) {
      data.frame(
        variable = factor(nm, levels = var_levels),
        x = as.numeric(wide[[1]]),
        time = as.numeric(time_points[k]),
        estimate = as.numeric(wide[[value_cols[k]]]),
        kind = factor("partial", levels = "partial"),
        stringsAsFactors = FALSE
      )
    }))
  })

  .gg_boost_effect_frame(blocks)
}

#' @export
gg_boost_effect.marginal.plot.boostmtree <- function(object, ...) {
  smooth <- object$smooth
  if (is.null(smooth) || length(smooth) == 0L) {
    stop("gg_boost_effect: this object records no smoothed effect curves.",
         call. = FALSE)
  }
  time_points <- object$time.points
  var_levels <- names(smooth)

  blocks <- lapply(var_levels, function(nm) {
    per_time <- smooth[[nm]]
    if (length(per_time) != length(time_points)) {
      stop(
        "gg_boost_effect: variable '", nm, "' has ", length(per_time),
        " smoothed curve(s) but the object records ", length(time_points),
        " time point(s).",
        call. = FALSE
      )
    }
    do.call(rbind, lapply(seq_along(per_time), function(k) {
      curve <- per_time[[k]]
      data.frame(
        variable = factor(nm, levels = var_levels),
        x = as.numeric(curve$x),
        time = as.numeric(time_points[k]),
        estimate = as.numeric(curve$y),
        kind = factor("marginal", levels = "marginal"),
        stringsAsFactors = FALSE
      )
    }))
  })

  .gg_boost_effect_frame(blocks)
}

# Shared tail of both methods: bind the per-variable blocks and class the
# result. The two methods differ only in how they reach a list of blocks.
.gg_boost_effect_frame <- function(blocks) {
  gg_dta <- do.call(rbind, blocks)
  rownames(gg_dta) <- NULL
  class(gg_dta) <- c("gg_boost_effect", class(gg_dta))
  gg_dta
}
```

- [ ] **Step 4: Run the extractor tests**

Run: `Rscript -e 'roxygen2::roxygenise("."); devtools::test(filter = "gg_boost_effect")'`
Expected: PASS, 0 failures

- [ ] **Step 5: Write the failing renderer tests**

Create `tests/testthat/test-plot-gg_boost_effect.R`:

```r
test_that("autoplot returns a ggplot", {
  p <- ggplot2::autoplot(gg_boost_effect(partial_fixture()))

  expect_s3_class(p, "ggplot")
})

test_that("plot is an alias for autoplot", {
  gg <- gg_boost_effect(partial_fixture())

  b1 <- ggplot2::ggplot_build(plot(gg))
  b2 <- ggplot2::ggplot_build(ggplot2::autoplot(gg))

  # Compare BUILT plots, not the ggplot objects; see plot.gg_boost_error.
  expect_equal(b1$data, b2$data)
  expect_equal(b1$layout$layout, b2$layout$layout)
})

test_that("the renderer rejects a foreign object", {
  expect_error(plot.gg_boost_effect(data.frame(x = 1)), "gg_boost_effect")
})

test_that("axis labels name the covariate and the effect", {
  p <- ggplot2::autoplot(gg_boost_effect(partial_fixture()))

  expect_identical(p$labels$x, "Covariate value")
  expect_identical(p$labels$y, "Effect")
})

test_that("one line is drawn per time point", {
  gg <- gg_boost_effect(partial_fixture())
  p <- ggplot2::autoplot(gg)

  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_true("GeomLine" %in% geoms)
  built <- ggplot2::ggplot_build(p)
  expect_identical(
    length(unique(built$data[[1]]$group)),
    length(unique(gg$time)) * nlevels(gg$variable)
  )
})

test_that("variables are faceted", {
  p <- ggplot2::autoplot(gg_boost_effect(partial_fixture()))

  expect_s3_class(p$facet, "FacetWrap")
})

test_that("the partial effect plot is stable", {
  skip_on_cran()
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "effect partial",
    ggplot2::autoplot(gg_boost_effect(partial_fixture()))
  )
})

test_that("the marginal effect plot is stable", {
  skip_on_cran()
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "effect marginal",
    ggplot2::autoplot(gg_boost_effect(marginal_fixture()))
  )
})
```

- [ ] **Step 6: Write the renderer**

Create `R/plot.gg_boost_effect.R`:

```r
#' Plot a \code{\link{gg_boost_effect}} object
#'
#' Covariate effect curves, one line per time point, faceted by variable.
#'
#' @details
#' Time is mapped to colour rather than to a facet because the question this
#' figure answers is how a covariate's effect *changes* across follow-up, and
#' that change is legible only when the curves share one panel. Variables get
#' the facets instead, since their x scales are unrelated.
#'
#' The returned plot carries no theme.
#'
#' @param object A \code{\link{gg_boost_effect}} object.
#' @param x A \code{\link{gg_boost_effect}} object.
#' @param ... Passed to \code{\link[ggplot2]{geom_line}}.
#'
#' @return A `ggplot` object.
#'
#' @seealso \code{\link{gg_boost_effect}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' fit <- boostmtree::boostmtree(
#'   x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, verbose = FALSE
#' )
#' pp <- boostmtree::partial.plot(fit, x.var.names = "x1", plot.it = FALSE)
#' plot(gg_boost_effect(pp))
#' }
#'
#' @importFrom ggplot2 autoplot ggplot aes geom_line facet_wrap labs
#' @export
autoplot.gg_boost_effect <- function(object, ...) {
  if (!inherits(object, "gg_boost_effect")) {
    stop("Incorrect object type: expected a gg_boost_effect object.",
         call. = FALSE)
  }

  gg_plt <- ggplot2::ggplot(
    object,
    ggplot2::aes(
      x = .data[["x"]],
      y = .data[["estimate"]],
      colour = .data[["time"]],
      group = interaction(.data[["time"]], .data[["variable"]])
    )
  ) +
    ggplot2::geom_line(...) +
    ggplot2::labs(x = "Covariate value", y = "Effect", colour = "Time")

  if (nlevels(object$variable) > 1L) {
    gg_plt <- gg_plt +
      ggplot2::facet_wrap(~ variable, scales = "free_x")
  }

  gg_plt
}

#' @rdname autoplot.gg_boost_effect
#' @export
plot.gg_boost_effect <- function(x, ...) {
  autoplot.gg_boost_effect(x, ...)
}
```

- [ ] **Step 7: Run, inspect the snapshots, accept**

```bash
Rscript -e 'roxygen2::roxygenise("."); devtools::test(filter = "plot-gg_boost_effect")'
```

Inspect the generated SVGs before accepting: confirm two facet panels, several coloured lines per panel, and a colour legend titled `Time`. If a snapshot is empty or wrong, STOP and report.

```bash
Rscript -e 'testthat::snapshot_accept()'
```

- [ ] **Step 8: Run the full suite and lint, then commit**

```bash
Rscript -e 'devtools::test()'
Rscript -e 'pkgload::load_all("."); print(lintr::lint_package())'
git add R/ tests/ NAMESPACE man/
git commit -m "feat: add gg_boost_effect extractor and renderer"
```

---

### Task 5: Documentation, version, and a clean check

**Files:**
- Modify: `README.md`, `NEWS.md`, `DESCRIPTION`, `_pkgdown.yml`

- [ ] **Step 1: Bump the patch version**

`DESCRIPTION` to `Version: 0.0.4`; `NEWS.md` line 2 to `Version: 0.0.4`. Add above the 0.0.3 section:

```markdown
# ggBoostedTrees 0.0.4

* `gg_boost_vimp()` and `plot()`/`autoplot()` for variable importance,
  covering both the main effect of each covariate and its interaction with
  time. The axis is labelled with the metric recorded on the source object
  rather than a hard-coded string.
* `gg_boost_effect()` and `plot()`/`autoplot()` for partial and marginal
  covariate effects over time, as one class distinguished by `kind`.
* Neither `partial.plot()` nor `marginal.plot()` computes a confidence
  interval, so `gg_boost_effect()` reports none.
```

- [ ] **Step 2: Update the README**

In the Status table, change the variable-importance and partial/marginal rows from `Not yet` to `Implemented`. Leave the `BoostMLR` row alone. Update the sentence counting implemented figures — it currently says three; there are now five.

In the "Figure data" table add:

```markdown
| `gg_boost_vimp()` | Variable importance for the main effect and the time interaction. |
| `gg_boost_effect()` | Partial and marginal covariate effects over time. |
```

In the "Rendering" table add:

```markdown
| `autoplot.gg_boost_vimp()` | Ordered horizontal bars, faceted by component. |
| `autoplot.gg_boost_effect()` | Effect curves coloured by time, faceted by variable. |
```

- [ ] **Step 3: Add the new topics to `_pkgdown.yml`**

Under `- title: "1. Extract — pull a data frame out of a fit"`, append to `contents:`:

```yaml
  - gg_boost_vimp
  - gg_boost_effect
```

Under `- title: "2. Render — draw the extracted object"`, append to `contents:`:

```yaml
  - autoplot.gg_boost_vimp
  - autoplot.gg_boost_effect
```

- [ ] **Step 4: Verify pkgdown covers every topic**

```bash
Rscript -e 'roxygen2::roxygenise("."); pkgdown::check_pkgdown()'
```

Expected: no error.

- [ ] **Step 5: Run the full suite, lint, and the URL check**

```bash
Rscript -e 'devtools::test()'
Rscript -e 'pkgload::load_all("."); print(lintr::lint_package())'
Rscript -e 'urlchecker::url_check(".")'
```

Expected: 0 failures, 0 skips; no lints; no invalid URLs.

- [ ] **Step 6: Run R CMD check from a clean export**

Commit first so `git archive HEAD` sees the changes.

```bash
TMP=$(mktemp -d) && git archive --format=tar HEAD | tar -x -C "$TMP" && \
  R CMD build "$TMP" && \
  _R_CHECK_FORCE_SUGGESTS_=false R CMD check --as-cran ggBoostedTrees_0.0.4.tar.gz
```

Expected: 0 errors, 0 warnings, exactly one NOTE — the `Remotes:` field note. Report every note and warning verbatim. Any other note fails this step.

Confirm all `R/*.R` and `man/*.Rd` remain pure ASCII and say how you checked.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "docs: document the interpretation figures, bump to 0.0.4"
```

---

## Definition of done

- `gg_boost_vimp()` returns `variable, importance, component, response` with `metric` and `time.effect` attributes, strips the `:time` suffix, and handles a joint object.
- `gg_boost_effect()` returns `variable, x, time, estimate, kind` from both source shapes, taking the smoothed curve for the marginal kind.
- Both have `autoplot()` implementations and `plot()` aliases returning unthemed `ggplot` objects.
- Fixtures are committed with provenance and no test recomputes importance or an effect surface.
- README, NEWS, and the pkgdown reference index list both new figures.
- `R CMD check --as-cran` is clean apart from the expected `Remotes:` note.
