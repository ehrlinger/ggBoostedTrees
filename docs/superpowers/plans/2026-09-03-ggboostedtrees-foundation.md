# ggBoostedTrees Foundation Phase Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the three-layer extractor/contract/renderer architecture end to end by shipping `gg_boost_error` and `gg_boost_path` for `boostmtree` fits, with a complete test scaffold.

**Architecture:** Each figure is an S3 extractor generic dispatching on the model object, returning a tidy `data.frame` with a documented column contract and a `gg_boost_*` class; a matching `autoplot.gg_boost_*` renders it, and `plot.gg_boost_*` is a thin alias. Backends are added by writing extractor methods only — renderers never learn about model classes.

**Tech Stack:** R (>= 4.4.0), `boostmtree` (>= 2.0.1, the CCF fork), `ggplot2`, `dplyr`, `tidyr`, `testthat` 3e, `vdiffr`, `roxygen2`.

## Global Constraints

- Backend is the fork `ehrlinger/boostmtree_src@v2.0.2-ccf`, installed with `subdir = "boostmtree"`. CRAN `boostmtree` 2.0.0 does **not** satisfy the `(>= 2.0.1)` floor and the package will not load against it.
- `DESCRIPTION` declares `Depends: R (>= 4.4.0)` — required by the `hvtiR` registry contract (`MIN_R_VERSION`). Do not raise it.
- `DESCRIPTION` must not `Imports:` any `hvtiR` family member (that includes `ggRandomForests`), or `hvtiR`'s `test-registry-live` fails.
- Fixture models are committed as `.rds` and never refit during `R CMD check`.
- Every fixture carries a provenance file recording backend version and the exact fitting call.
- Package version stays three-digit semantic. Bump the patch digit only; the minor and major digits are the maintainer's call.
- No `.9000` or four-digit dev versions.
- Renderers return a bare `ggplot` with no theme applied.
- Examples that fit a model use `\donttest`, never `\dontrun`.

## Backend facts verified against `boostmtree` 2.0.2

These were confirmed by fitting real models. Do not re-derive them.

- Fitted object class is `c("boostmtree", "grow", "mtree.pspline.learner")`.
- **`err.rate` and `m.opt` are `NULL`/empty unless the fit used `cv.flag = TRUE`.** A default fit yields no error path at all.
- `err.rate` for `n.q == 1` is a **matrix**, `M` rows by 2 columns, `colnames` `c("l1", "l2")`. For `n.q > 1` it is a **list** of such matrices, one per response.
- `rho`, `phi`, `lambda` are **numeric vectors** of length `M` when `n.q == 1`, and `M` x `n.q` **matrices** when `n.q > 1`.
- `q.set` is `NA` for a univariate continuous fit. `n.q` is `1`.
- `y.sd` is a scalar; `err.rate[, "l2"]` is on the standardized scale, so the unstandardized squared error is `(l2 * y.sd)^2`.
- `simLong()` cannot produce `n.q > 1`; even `family = "binary"` returns `n.q == 1`. Multi-response handling is therefore tested with a hand-built object, not a fitted one.

---

### Task 1: Package skeleton that loads and checks clean

**Files:**
- Create: `R/ggBoostedTrees-package.R`
- Create: `R/utils.R`
- Create: `NEWS.md`
- Create: `.Rbuildignore`
- Create: `tests/testthat.R`
- Create: `tests/testthat/test-utils.R`
- Modify: `DESCRIPTION` (add `Config/testthat/edition`)

**Interfaces:**
- Consumes: nothing.
- Produces: `%||%(x, y)`; `.boost_check_grow(object, call_name)` which errors unless `object` inherits `boostmtree`; `.boost_response_labels(object)` returning a `character` vector of length `object$n.q`.

- [ ] **Step 1: Install the backend fork and confirm the version floor**

```bash
Rscript -e 'remotes::install_github("ehrlinger/boostmtree_src", subdir = "boostmtree", ref = "v2.0.2-ccf", upgrade = "never")'
Rscript -e 'stopifnot(packageVersion("boostmtree") >= "2.0.1"); cat("floor satisfied:", as.character(packageVersion("boostmtree")), "\n")'
```

Expected: `floor satisfied: 2.0.2`

- [ ] **Step 2: Write the failing test**

Create `tests/testthat/test-utils.R`:

```r
test_that("%||% returns the left side unless it is NULL", {
  expect_identical(1L %||% 2L, 1L)
  expect_identical(NULL %||% 2L, 2L)
})

test_that(".boost_check_grow rejects non-boostmtree objects", {
  expect_error(
    .boost_check_grow(data.frame(x = 1), "gg_boost_error"),
    "gg_boost_error"
  )
})

test_that(".boost_response_labels falls back to y when q.set is NA", {
  obj <- structure(list(n.q = 1L, q.set = NA), class = "boostmtree")
  expect_identical(.boost_response_labels(obj), "y")
})

test_that(".boost_response_labels uses q.set when it is populated", {
  obj <- structure(list(n.q = 2L, q.set = c("lo", "hi")), class = "boostmtree")
  expect_identical(.boost_response_labels(obj), c("lo", "hi"))
})
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-utils.R")'`
Expected: FAIL — `could not find function ".boost_check_grow"`

- [ ] **Step 4: Write the package doc file**

Create `R/ggBoostedTrees-package.R`:

```r
#' ggBoostedTrees: Visually Exploring Boosted Tree Models
#'
#' Graphic elements for exploring boosted tree models. Each figure is produced
#' in two steps: a `gg_boost_*()` extractor pulls a tidy data frame with a
#' documented column contract out of a fitted model, and `autoplot()` renders
#' that data frame. Adding a new modelling backend means writing extractor
#' methods only.
#'
#' @keywords internal
"_PACKAGE"
```

- [ ] **Step 5: Write the utilities**

Create `R/utils.R`:

```r
# Return the left operand unless it is NULL. Mirrors the helper boostmtree
# uses internally, so ported extraction logic reads the same as its source.
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

# Every extractor front-door calls this so that a wrong object type produces
# one consistent message naming the function the user actually called.
.boost_check_grow <- function(object, call_name) {
  if (!inherits(object, "boostmtree")) {
    stop(
      call_name, ": expected a 'boostmtree' object; got an object of class ",
      paste(class(object), collapse = "/"), ".",
      call. = FALSE
    )
  }
  invisible(object)
}

# Labels for the `response` column. boostmtree records q.set as NA for a
# univariate fit, so a single response is labelled "y" rather than "NA".
.boost_response_labels <- function(object) {
  n_q <- object$n.q %||% 1L
  q_set <- object$q.set
  if (is.null(q_set) || all(is.na(q_set))) {
    if (n_q == 1L) {
      return("y")
    }
    return(paste0("y", seq_len(n_q)))
  }
  as.character(q_set)
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-utils.R")'`
Expected: PASS, 5 assertions, 0 failures

- [ ] **Step 7: Add the testthat runner and build ignores**

Create `tests/testthat.R`:

```r
library(testthat)
library(ggBoostedTrees)

test_check("ggBoostedTrees")
```

Create `.Rbuildignore`:

```
^.*\.Rproj$
^\.Rproj\.user$
^\.github$
^docs$
^LICENSE\.md$
^_pkgdown\.yml$
^\.lintr$
```

Append to `DESCRIPTION`:

```
Config/testthat/edition: 3
```

- [ ] **Step 8: Create NEWS.md**

```markdown
Package: ggBoostedTrees
Version: 0.0.1

# ggBoostedTrees 0.0.1

* Package skeleton, shared utilities, and the testthat scaffold.
```

- [ ] **Step 9: Generate documentation and confirm the package loads**

```bash
Rscript -e 'roxygen2::roxygenise(".")'
Rscript -e 'pkgload::load_all("."); cat("loaded\n")'
```

Expected: `NAMESPACE` written, then `loaded`

- [ ] **Step 10: Commit**

```bash
git add DESCRIPTION NAMESPACE NEWS.md .Rbuildignore R/ tests/
git commit -m "feat: package skeleton, shared utilities, and test scaffold"
```

---

### Task 2: Committed model fixture with provenance

**Files:**
- Create: `tests/testthat/fixtures/make-fixtures.R`
- Create: `tests/testthat/fixtures/boost_continuous.rds`
- Create: `tests/testthat/fixtures/boost_continuous.dcf`
- Create: `tests/testthat/helper-fixtures.R`
- Create: `tests/testthat/test-fixtures.R`

**Interfaces:**
- Consumes: nothing.
- Produces: `boost_fixture()` returning the fitted `boostmtree` object; `boost_multi_fixture()` returning a hand-built list of class `c("boostmtree", "grow")` with `n.q = 2L`, list-valued `err.rate`, and matrix-valued `rho`/`phi`/`lambda`.

- [ ] **Step 1: Write the fixture generation script**

Create `tests/testthat/fixtures/make-fixtures.R`. This is run by hand, never by `R CMD check`.

```r
# Regenerate the committed model fixture.
#
#   Rscript tests/testthat/fixtures/make-fixtures.R
#
# Run this only when the backend version changes. The .rds is committed so
# that R CMD check never refits a model; refitting would blow the check-time
# budget. Re-run rewrites the provenance file alongside it.
#
# cv.flag = TRUE is REQUIRED: without it boostmtree records no err.rate and
# no m.opt, and gg_boost_error() has nothing to extract.

library(boostmtree)

here <- file.path("tests", "testthat", "fixtures")
stopifnot(dir.exists(here))

set.seed(7)
sim <- simLong(
  n = 25, n.time = 4, rho = 0.8, model = 1, family = "continuous"
)$data.list

fit <- boostmtree(
  x = sim$features,
  tm = sim$time,
  id = sim$id,
  y = sim$y,
  family = "continuous",
  M = 50,
  cv.flag = TRUE,
  verbose = FALSE,
  control = boostmtree.control(seed = 7)
)

saveRDS(fit, file.path(here, "boost_continuous.rds"), compress = "xz")

writeLines(
  c(
    "Fixture: boost_continuous.rds",
    paste0("Backend: boostmtree ", as.character(packageVersion("boostmtree"))),
    "Source: ehrlinger/boostmtree_src@v2.0.2-ccf (subdir = boostmtree)",
    paste0("Generated: ", format(Sys.Date())),
    paste0("R: ", R.version.string),
    "Call: simLong(n = 25, n.time = 4, rho = 0.8, model = 1,",
    "  family = 'continuous'); boostmtree(M = 50, cv.flag = TRUE,",
    "  control = boostmtree.control(seed = 7)); set.seed(7)",
    paste0("m.opt: ", fit$m.opt)
  ),
  file.path(here, "boost_continuous.dcf")
)

cat("wrote fixture, m.opt =", fit$m.opt, "\n")
```

- [ ] **Step 2: Run it to produce the fixture**

```bash
Rscript tests/testthat/fixtures/make-fixtures.R
ls -la tests/testthat/fixtures/
```

Expected: `wrote fixture, m.opt = 19`, and `boost_continuous.rds` roughly 350–400 KB

- [ ] **Step 3: Write the fixture helper**

Create `tests/testthat/helper-fixtures.R`:

```r
# The fitted fixture. Read from disk, never refit -- see fixtures/make-fixtures.R.
boost_fixture <- function() {
  readRDS(test_path("fixtures", "boost_continuous.rds"))
}

# A hand-built two-response object. simLong() cannot produce n.q > 1, but
# boostmtree stores err.rate as a LIST and rho/phi/lambda as MATRICES in that
# case, and the extractors must handle both shapes. Only the fields the
# extractors read are populated.
boost_multi_fixture <- function() {
  m <- 4L
  err <- lapply(1:2, function(q) {
    matrix(
      c(seq(1, 0.7, length.out = m), seq(2, 1.4, length.out = m) * q),
      nrow = m, ncol = 2L, dimnames = list(NULL, c("l1", "l2"))
    )
  })
  structure(
    list(
      n.q = 2L,
      q.set = c("lo", "hi"),
      family = "nominal",
      y.sd = 2,
      m.opt = c(2L, 3L),
      err.rate = err,
      rho = matrix(seq(0.1, 0.8, length.out = m * 2L), nrow = m),
      phi = matrix(seq(1, 8, length.out = m * 2L), nrow = m),
      lambda = matrix(seq(10, 80, length.out = m * 2L), nrow = m)
    ),
    class = c("boostmtree", "grow")
  )
}
```

- [ ] **Step 4: Write the fixture test**

Create `tests/testthat/test-fixtures.R`:

```r
test_that("the committed fixture is a cv.flag boostmtree grow object", {
  fit <- boost_fixture()

  expect_s3_class(fit, "boostmtree")
  expect_identical(class(fit)[2], "grow")
  expect_false(is.null(fit$err.rate))
  expect_identical(colnames(fit$err.rate), c("l1", "l2"))
  expect_identical(nrow(fit$err.rate), 50L)
})

test_that("the fixture has an interior optimal iteration", {
  fit <- boost_fixture()

  # An m.opt pinned at 1 or at M would make the `optimal` column untestable.
  expect_gt(fit$m.opt, 1L)
  expect_lt(fit$m.opt, 50L)
})

test_that("fixture provenance is recorded", {
  txt <- readLines(test_path("fixtures", "boost_continuous.dcf"))

  expect_true(any(grepl("^Backend: boostmtree", txt)))
  expect_true(any(grepl("cv.flag = TRUE", txt, fixed = TRUE)))
})

test_that("the multi-response fixture has the shapes boostmtree uses", {
  obj <- boost_multi_fixture()

  expect_true(is.list(obj$err.rate))
  expect_length(obj$err.rate, 2L)
  expect_true(is.matrix(obj$rho))
  expect_identical(ncol(obj$rho), 2L)
})
```

- [ ] **Step 5: Run the tests**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-fixtures.R")'`
Expected: PASS, 0 failures

- [ ] **Step 6: Commit**

```bash
git add tests/testthat/fixtures/ tests/testthat/helper-fixtures.R tests/testthat/test-fixtures.R
git commit -m "test: add committed boostmtree fixture with provenance"
```

---

### Task 3: `gg_boost_error` extractor

**Files:**
- Create: `R/gg_boost_error.R`
- Create: `tests/testthat/test-gg_boost_error.R`

**Interfaces:**
- Consumes: `.boost_check_grow()`, `.boost_response_labels()`, `%||%`, `boost_fixture()`, `boost_multi_fixture()`.
- Produces: `gg_boost_error(object, use.rmse = TRUE, ...)` returning a `data.frame` of class `c("gg_boost_error", "data.frame")` with columns `iteration` (integer), `value` (numeric), `response` (factor), `optimal` (logical).

- [ ] **Step 1: Write the failing test**

Create `tests/testthat/test-gg_boost_error.R`:

```r
test_that("gg_boost_error returns the documented column contract", {
  gg <- gg_boost_error(boost_fixture())

  expect_s3_class(gg, "gg_boost_error")
  expect_s3_class(gg, "data.frame")
  expect_identical(names(gg), c("iteration", "value", "response", "optimal"))
  expect_type(gg$iteration, "integer")
  expect_type(gg$value, "double")
  expect_s3_class(gg$response, "factor")
  expect_type(gg$optimal, "logical")
})

test_that("gg_boost_error returns one row per boosting iteration", {
  fit <- boost_fixture()
  gg <- gg_boost_error(fit)

  expect_identical(nrow(gg), 50L)
  expect_identical(gg$iteration, 1:50)
})

test_that("gg_boost_error takes values from the l2 column", {
  fit <- boost_fixture()
  gg <- gg_boost_error(fit)

  expect_equal(gg$value, unname(fit$err.rate[, "l2"]))
})

test_that("use.rmse = FALSE returns the unstandardized squared error", {
  fit <- boost_fixture()
  gg <- gg_boost_error(fit, use.rmse = FALSE)

  expect_equal(gg$value, unname((fit$err.rate[, "l2"] * fit$y.sd)^2))
})

test_that("optimal marks exactly the m.opt iteration", {
  fit <- boost_fixture()
  gg <- gg_boost_error(fit)

  expect_identical(sum(gg$optimal), 1L)
  expect_identical(gg$iteration[gg$optimal], as.integer(fit$m.opt))
})

test_that("a univariate fit is labelled y", {
  gg <- gg_boost_error(boost_fixture())

  expect_identical(levels(gg$response), "y")
})

test_that("a multi-response object yields one block per response", {
  gg <- gg_boost_error(boost_multi_fixture())

  expect_identical(nrow(gg), 8L)
  expect_identical(levels(gg$response), c("lo", "hi"))
  expect_identical(sum(gg$optimal), 2L)
})

test_that("gg_boost_error rejects a fit without cv.flag", {
  fit <- boost_fixture()
  fit$err.rate <- NULL

  expect_error(gg_boost_error(fit), "cv.flag")
})

test_that("gg_boost_error rejects a non-boostmtree object", {
  expect_error(gg_boost_error(data.frame(x = 1)), "gg_boost_error")
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-gg_boost_error.R")'`
Expected: FAIL — `could not find function "gg_boost_error"`

- [ ] **Step 3: Write the extractor**

Create `R/gg_boost_error.R`:

```r
#' Boosting error trajectory data object
#'
#' Extract the error path of a boosted multivariate tree fit as a function of
#' the boosting iteration, together with the optimal iteration selected by
#' cross-validation.
#'
#' @details
#' \strong{The fit must have been grown with `cv.flag = TRUE`.} `boostmtree`
#' records `err.rate` and `m.opt` only when cross-validation ran; a default fit
#' carries neither, and there is no error path to extract. If this function
#' reports that the fit has no error path, refit with `cv.flag = TRUE`.
#'
#' `boostmtree` stores the error on the standardized response scale in the
#' `l2` column. `use.rmse = FALSE` returns `(l2 * y.sd)^2`, the squared error
#' on the original scale.
#'
#' @param object A fitted \code{\link[boostmtree]{boostmtree}} object.
#' @param use.rmse Logical. When `TRUE` (default) return the standardized `l2`
#'   error; when `FALSE` return the unstandardized squared error.
#' @param ... Not used; present for S3 consistency.
#'
#' @return A `gg_boost_error` `data.frame` with columns:
#'   \describe{
#'     \item{iteration}{Integer boosting iteration, from 1.}
#'     \item{value}{Numeric error at that iteration.}
#'     \item{response}{Factor naming the response.}
#'     \item{optimal}{Logical, `TRUE` at the cross-validated optimal iteration.}
#'   }
#'
#' @seealso \code{\link{plot.gg_boost_error}}, \code{\link{gg_boost_path}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' fit <- boostmtree::boostmtree(
#'   x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, cv.flag = TRUE, verbose = FALSE
#' )
#' gg_dta <- gg_boost_error(fit)
#' plot(gg_dta)
#' }
#'
#' @export
gg_boost_error <- function(object, use.rmse = TRUE, ...) {
  UseMethod("gg_boost_error", object)
}

# Only reached for objects that are not boostmtree fits: a boostmtree object
# dispatches to the method below. So this exists purely to raise the message.
#' @export
gg_boost_error.default <- function(object, use.rmse = TRUE, ...) {
  .boost_check_grow(object, "gg_boost_error")
}

#' @export
gg_boost_error.boostmtree <- function(object, use.rmse = TRUE, ...) {
  .boost_check_grow(object, "gg_boost_error")

  if (is.null(object$err.rate)) {
    stop(
      "gg_boost_error: this fit has no error path. boostmtree records ",
      "err.rate only when grown with cv.flag = TRUE.",
      call. = FALSE
    )
  }

  n_q <- object$n.q %||% 1L
  labels <- .boost_response_labels(object)

  # boostmtree stores err.rate as a bare matrix for a single response and as a
  # list of matrices for several; normalize to the list form before looping.
  err <- object$err.rate
  if (!is.list(err)) {
    err <- list(err)
  }
  m_opt <- object$m.opt

  blocks <- lapply(seq_len(n_q), function(q) {
    value <- unname(err[[q]][, "l2"])
    if (!use.rmse) {
      value <- (value * object$y.sd)^2
    }
    iteration <- seq_along(value)
    opt <- if (length(m_opt) >= q) as.integer(m_opt[q]) else NA_integer_

    data.frame(
      iteration = as.integer(iteration),
      value = as.numeric(value),
      response = factor(labels[q], levels = labels),
      optimal = !is.na(opt) & iteration == opt,
      stringsAsFactors = FALSE
    )
  })

  gg_dta <- do.call(rbind, blocks)
  rownames(gg_dta) <- NULL
  class(gg_dta) <- c("gg_boost_error", class(gg_dta))
  gg_dta
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-gg_boost_error.R")'`
Expected: PASS, 0 failures

- [ ] **Step 5: Commit**

```bash
Rscript -e 'roxygen2::roxygenise(".")'
git add R/gg_boost_error.R tests/testthat/test-gg_boost_error.R NAMESPACE man/
git commit -m "feat: add gg_boost_error extractor"
```

---

### Task 4: `gg_boost_error` renderer

**Files:**
- Create: `R/plot.gg_boost_error.R`
- Create: `tests/testthat/test-plot-gg_boost_error.R`

**Interfaces:**
- Consumes: `gg_boost_error()`.
- Produces: `autoplot.gg_boost_error(object, ...)` returning a `ggplot`; `plot.gg_boost_error(x, ...)` aliasing it.

- [ ] **Step 1: Write the failing test**

Create `tests/testthat/test-plot-gg_boost_error.R`:

```r
test_that("autoplot returns a ggplot", {
  p <- ggplot2::autoplot(gg_boost_error(boost_fixture()))

  expect_s3_class(p, "ggplot")
})

test_that("plot is an alias for autoplot", {
  gg <- gg_boost_error(boost_fixture())

  expect_equal(plot(gg), ggplot2::autoplot(gg))
})

test_that("the renderer rejects a foreign object", {
  expect_error(plot.gg_boost_error(data.frame(x = 1)), "gg_boost_error")
})

test_that("axis labels name the boosting iteration and the error", {
  p <- ggplot2::autoplot(gg_boost_error(boost_fixture()))

  expect_identical(p$labels$x, "Boosting Iteration")
  expect_identical(p$labels$y, "Error")
})

test_that("the optimal iteration is drawn as its own layer", {
  p <- ggplot2::autoplot(gg_boost_error(boost_fixture()))

  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_true("GeomLine" %in% geoms)
  expect_true("GeomVline" %in% geoms)
})

test_that("marking the optimum can be switched off", {
  p <- ggplot2::autoplot(gg_boost_error(boost_fixture()), optimal = FALSE)

  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_false("GeomVline" %in% geoms)
})

test_that("the univariate error plot is stable", {
  skip_on_cran()
  vdiffr::expect_doppelganger(
    "error univariate",
    ggplot2::autoplot(gg_boost_error(boost_fixture()))
  )
})

test_that("the multi-response error plot is stable", {
  skip_on_cran()
  vdiffr::expect_doppelganger(
    "error multi response",
    ggplot2::autoplot(gg_boost_error(boost_multi_fixture()))
  )
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-plot-gg_boost_error.R")'`
Expected: FAIL — no applicable method for `autoplot`

- [ ] **Step 3: Write the renderer**

Create `R/plot.gg_boost_error.R`:

```r
#' Plot a \code{\link{gg_boost_error}} object
#'
#' The error path of a boosted multivariate tree fit against the boosting
#' iteration, with the cross-validated optimal iteration marked.
#'
#' @details
#' The returned plot carries no theme, so it composes with any `ggplot2`
#' theme or scale. Several responses are drawn as facets rather than as
#' coloured series, because the responses do not share a y scale.
#'
#' @param object A \code{\link{gg_boost_error}} object.
#' @param x A \code{\link{gg_boost_error}} object.
#' @param optimal Logical. Draw a vertical rule at the optimal iteration.
#'   Defaults to `TRUE`.
#' @param ... Passed to \code{\link[ggplot2]{geom_line}}.
#'
#' @return A `ggplot` object.
#'
#' @seealso \code{\link{gg_boost_error}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' fit <- boostmtree::boostmtree(
#'   x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, cv.flag = TRUE, verbose = FALSE
#' )
#' plot(gg_boost_error(fit))
#' }
#'
#' @importFrom ggplot2 autoplot ggplot aes geom_line geom_vline facet_wrap labs
#' @export
autoplot.gg_boost_error <- function(object, optimal = TRUE, ...) {
  if (!inherits(object, "gg_boost_error")) {
    stop("Incorrect object type: expected a gg_boost_error object.",
         call. = FALSE)
  }

  gg_plt <- ggplot2::ggplot(
    object,
    ggplot2::aes(x = .data[["iteration"]], y = .data[["value"]])
  ) +
    ggplot2::geom_line(...) +
    ggplot2::labs(x = "Boosting Iteration", y = "Error")

  if (isTRUE(optimal) && any(object$optimal)) {
    rules <- object[object$optimal, c("iteration", "response"), drop = FALSE]
    gg_plt <- gg_plt +
      ggplot2::geom_vline(
        data = rules,
        ggplot2::aes(xintercept = .data[["iteration"]]),
        linetype = "dashed"
      )
  }

  # Facet only when there is something to separate: a single-response fit
  # gets a bare panel rather than a strip labelled "y".
  if (nlevels(object$response) > 1L) {
    gg_plt <- gg_plt + ggplot2::facet_wrap(~ response, scales = "free_y")
  }

  gg_plt
}

#' @rdname autoplot.gg_boost_error
#' @export
plot.gg_boost_error <- function(x, optimal = TRUE, ...) {
  autoplot.gg_boost_error(x, optimal = optimal, ...)
}
```

- [ ] **Step 4: Declare the rlang pronoun**

`.data` needs an import. Append to `R/ggBoostedTrees-package.R`:

```r
#' @importFrom rlang .data
NULL
```

Add `rlang` to `Imports:` in `DESCRIPTION`.

- [ ] **Step 5: Run the test and accept the snapshots**

```bash
Rscript -e 'roxygen2::roxygenise("."); pkgload::load_all("."); testthat::test_file("tests/testthat/test-plot-gg_boost_error.R")'
```

Expected: the two `vdiffr` cases report new snapshots on first run. Inspect the written SVGs under `tests/testthat/_snaps/`, confirm the error curve descends and the dashed rule sits at iteration 19, then accept:

```bash
Rscript -e 'testthat::snapshot_accept()'
```

- [ ] **Step 6: Re-run to verify all pass**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-plot-gg_boost_error.R")'`
Expected: PASS, 0 failures

- [ ] **Step 7: Commit**

```bash
git add R/ tests/ NAMESPACE man/ DESCRIPTION
git commit -m "feat: add gg_boost_error renderer"
```

---

### Task 5: `gg_boost_path` extractor

**Files:**
- Create: `R/gg_boost_path.R`
- Create: `tests/testthat/test-gg_boost_path.R`

**Interfaces:**
- Consumes: `.boost_check_grow()`, `.boost_response_labels()`, `%||%`.
- Produces: `gg_boost_path(object, parameters = c("rho", "phi", "lambda"), ...)` returning a `data.frame` of class `c("gg_boost_path", "data.frame")` with columns `iteration` (integer), `value` (numeric), `parameter` (factor), `response` (factor).

- [ ] **Step 1: Write the failing test**

Create `tests/testthat/test-gg_boost_path.R`:

```r
test_that("gg_boost_path returns the documented column contract", {
  gg <- gg_boost_path(boost_fixture())

  expect_s3_class(gg, "gg_boost_path")
  expect_identical(names(gg), c("iteration", "value", "parameter", "response"))
  expect_type(gg$iteration, "integer")
  expect_type(gg$value, "double")
  expect_s3_class(gg$parameter, "factor")
  expect_s3_class(gg$response, "factor")
})

test_that("all three parameters are returned by default", {
  gg <- gg_boost_path(boost_fixture())

  expect_identical(levels(gg$parameter), c("rho", "phi", "lambda"))
  expect_identical(nrow(gg), 150L)
})

test_that("parameters can be selected", {
  gg <- gg_boost_path(boost_fixture(), parameters = "rho")

  expect_identical(levels(gg$parameter), "rho")
  expect_identical(nrow(gg), 50L)
})

test_that("values match the fitted parameter paths", {
  fit <- boost_fixture()
  gg <- gg_boost_path(fit, parameters = "phi")

  expect_equal(gg$value, as.numeric(fit$phi))
})

test_that("matrix-valued paths are split by response", {
  gg <- gg_boost_path(boost_multi_fixture(), parameters = "rho")

  expect_identical(nrow(gg), 8L)
  expect_identical(levels(gg$response), c("lo", "hi"))
  expect_identical(as.integer(table(gg$response)), c(4L, 4L))
})

test_that("an absent parameter is dropped rather than erroring", {
  fit <- boost_fixture()
  fit$lambda <- NULL
  gg <- gg_boost_path(fit)

  expect_identical(levels(gg$parameter), c("rho", "phi"))
})

test_that("gg_boost_path errors when no requested parameter is present", {
  fit <- boost_fixture()
  fit$rho <- NULL
  fit$phi <- NULL
  fit$lambda <- NULL

  expect_error(gg_boost_path(fit), "no parameter paths")
})

test_that("gg_boost_path rejects an unknown parameter name", {
  expect_error(gg_boost_path(boost_fixture(), parameters = "sigma"), "sigma")
})

test_that("gg_boost_path rejects a non-boostmtree object", {
  expect_error(gg_boost_path(data.frame(x = 1)), "gg_boost_path")
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-gg_boost_path.R")'`
Expected: FAIL — `could not find function "gg_boost_path"`

- [ ] **Step 3: Write the extractor**

Create `R/gg_boost_path.R`:

```r
#' Boosting parameter path data object
#'
#' Extract the estimated correlation, variance, and penalized-spline smoothing
#' parameters of a boosted multivariate tree fit as functions of the boosting
#' iteration.
#'
#' @details
#' `boostmtree` re-estimates three quantities at every boosting iteration:
#' `rho`, the within-subject correlation; `phi`, the variance component; and
#' `lambda`, the P-spline smoothing parameter for the time-covariate
#' interaction. Their paths diagnose whether the variance structure settled or
#' is still drifting when boosting stops.
#'
#' Unlike the error path, these are recorded on every fit and do not require
#' `cv.flag = TRUE`. A parameter absent from the fit is dropped silently; it is
#' an error only when none of the requested parameters is present.
#'
#' @param object A fitted \code{\link[boostmtree]{boostmtree}} object.
#' @param parameters Character vector naming the paths to extract, any of
#'   `"rho"`, `"phi"`, and `"lambda"`. Defaults to all three.
#' @param ... Not used; present for S3 consistency.
#'
#' @return A `gg_boost_path` `data.frame` with columns:
#'   \describe{
#'     \item{iteration}{Integer boosting iteration, from 1.}
#'     \item{value}{Numeric parameter value at that iteration.}
#'     \item{parameter}{Factor naming the parameter.}
#'     \item{response}{Factor naming the response.}
#'   }
#'
#' @seealso \code{\link{plot.gg_boost_path}}, \code{\link{gg_boost_error}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' fit <- boostmtree::boostmtree(
#'   x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, cv.flag = TRUE, verbose = FALSE
#' )
#' plot(gg_boost_path(fit))
#' }
#'
#' @export
gg_boost_path <- function(object,
                          parameters = c("rho", "phi", "lambda"),
                          ...) {
  UseMethod("gg_boost_path", object)
}

# Only reached for objects that are not boostmtree fits; see gg_boost_error.
#' @export
gg_boost_path.default <- function(object,
                                  parameters = c("rho", "phi", "lambda"),
                                  ...) {
  .boost_check_grow(object, "gg_boost_path")
}

#' @export
gg_boost_path.boostmtree <- function(object,
                                     parameters = c("rho", "phi", "lambda"),
                                     ...) {
  .boost_check_grow(object, "gg_boost_path")

  known <- c("rho", "phi", "lambda")
  unknown <- setdiff(parameters, known)
  if (length(unknown) > 0L) {
    stop(
      "gg_boost_path: unknown parameter ",
      paste(sQuote(unknown), collapse = ", "),
      ". Expected any of ", paste(sQuote(known), collapse = ", "), ".",
      call. = FALSE
    )
  }

  n_q <- object$n.q %||% 1L
  labels <- .boost_response_labels(object)

  present <- parameters[vapply(
    parameters, function(p) !is.null(object[[p]]), logical(1)
  )]
  if (length(present) == 0L) {
    stop(
      "gg_boost_path: this fit records no parameter paths for ",
      paste(sQuote(parameters), collapse = ", "), ".",
      call. = FALSE
    )
  }

  blocks <- lapply(present, function(p) {
    # A single response stores each path as a vector; several responses store
    # it as an iteration-by-response matrix. as.matrix() normalizes both.
    path <- as.matrix(object[[p]])
    do.call(rbind, lapply(seq_len(n_q), function(q) {
      value <- as.numeric(path[, min(q, ncol(path))])
      data.frame(
        iteration = seq_along(value),
        value = value,
        parameter = factor(p, levels = present),
        response = factor(labels[q], levels = labels),
        stringsAsFactors = FALSE
      )
    }))
  })

  gg_dta <- do.call(rbind, blocks)
  rownames(gg_dta) <- NULL
  class(gg_dta) <- c("gg_boost_path", class(gg_dta))
  gg_dta
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-gg_boost_path.R")'`
Expected: PASS, 0 failures

- [ ] **Step 5: Commit**

```bash
Rscript -e 'roxygen2::roxygenise(".")'
git add R/gg_boost_path.R tests/testthat/test-gg_boost_path.R NAMESPACE man/
git commit -m "feat: add gg_boost_path extractor"
```

---

### Task 6: `gg_boost_path` renderer

**Files:**
- Create: `R/plot.gg_boost_path.R`
- Create: `tests/testthat/test-plot-gg_boost_path.R`

**Interfaces:**
- Consumes: `gg_boost_path()`.
- Produces: `autoplot.gg_boost_path(object, ...)` returning a `ggplot`; `plot.gg_boost_path(x, ...)` aliasing it.

- [ ] **Step 1: Write the failing test**

Create `tests/testthat/test-plot-gg_boost_path.R`:

```r
test_that("autoplot returns a ggplot", {
  p <- ggplot2::autoplot(gg_boost_path(boost_fixture()))

  expect_s3_class(p, "ggplot")
})

test_that("plot is an alias for autoplot", {
  gg <- gg_boost_path(boost_fixture())

  b1 <- ggplot2::ggplot_build(plot(gg))
  b2 <- ggplot2::ggplot_build(ggplot2::autoplot(gg))

  # Compare BUILT plots, not the ggplot objects. aes() quosures capture
  # S3-dispatch bookkeeping (.Generic, .Method, ...) from the calling frame,
  # so two identical plots differ as objects when one reaches the renderer
  # through dispatch and the other does not. ggplot_build() evaluates the
  # quosures away, and its $data carries the computed geometry -- so this
  # catches a real divergence in layers, facets or mapping.
  expect_equal(b1$data, b2$data)
  expect_equal(b1$layout$layout, b2$layout$layout)
})

test_that("the renderer rejects a foreign object", {
  expect_error(plot.gg_boost_path(data.frame(x = 1)), "gg_boost_path")
})

test_that("axis labels name the iteration and the estimate", {
  p <- ggplot2::autoplot(gg_boost_path(boost_fixture()))

  expect_identical(p$labels$x, "Boosting Iteration")
  expect_identical(p$labels$y, "Estimate")
})

test_that("the three parameters are faceted on free y scales", {
  p <- ggplot2::autoplot(gg_boost_path(boost_fixture()))

  expect_s3_class(p$facet, "FacetWrap")
  expect_true(p$facet$params$free$y)
})

test_that("the parameter path plot is stable", {
  skip_on_cran()
  vdiffr::expect_doppelganger(
    "path all parameters",
    ggplot2::autoplot(gg_boost_path(boost_fixture()))
  )
})

test_that("the multi-response path plot is stable", {
  skip_on_cran()
  vdiffr::expect_doppelganger(
    "path multi response",
    ggplot2::autoplot(gg_boost_path(boost_multi_fixture()))
  )
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-plot-gg_boost_path.R")'`
Expected: FAIL — no applicable method for `autoplot`

- [ ] **Step 3: Write the renderer**

Create `R/plot.gg_boost_path.R`:

```r
#' Plot a \code{\link{gg_boost_path}} object
#'
#' The estimated correlation, variance, and smoothing parameter paths of a
#' boosted multivariate tree fit against the boosting iteration.
#'
#' @details
#' The three parameters live on entirely different scales, so they are always
#' faceted with a free y axis rather than drawn together. With several
#' responses the facet grid is parameter by response.
#'
#' The returned plot carries no theme.
#'
#' @param object A \code{\link{gg_boost_path}} object.
#' @param x A \code{\link{gg_boost_path}} object.
#' @param ... Passed to \code{\link[ggplot2]{geom_line}}.
#'
#' @return A `ggplot` object.
#'
#' @seealso \code{\link{gg_boost_path}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' fit <- boostmtree::boostmtree(
#'   x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, cv.flag = TRUE, verbose = FALSE
#' )
#' plot(gg_boost_path(fit))
#' }
#'
#' @importFrom ggplot2 autoplot ggplot aes geom_line facet_wrap facet_grid labs
#' @export
autoplot.gg_boost_path <- function(object, ...) {
  if (!inherits(object, "gg_boost_path")) {
    stop("Incorrect object type: expected a gg_boost_path object.",
         call. = FALSE)
  }

  gg_plt <- ggplot2::ggplot(
    object,
    ggplot2::aes(x = .data[["iteration"]], y = .data[["value"]])
  ) +
    ggplot2::geom_line(...) +
    ggplot2::labs(x = "Boosting Iteration", y = "Estimate")

  if (nlevels(object$response) > 1L) {
    gg_plt <- gg_plt +
      ggplot2::facet_grid(parameter ~ response, scales = "free_y")
  } else {
    gg_plt <- gg_plt +
      ggplot2::facet_wrap(~ parameter, scales = "free_y", ncol = 1L)
  }

  gg_plt
}

#' @rdname autoplot.gg_boost_path
#' @export
plot.gg_boost_path <- function(x, ...) {
  autoplot.gg_boost_path(x, ...)
}
```

- [ ] **Step 4: Run the test and accept the snapshots**

```bash
Rscript -e 'roxygen2::roxygenise("."); pkgload::load_all("."); testthat::test_file("tests/testthat/test-plot-gg_boost_path.R")'
```

Inspect the written SVGs under `tests/testthat/_snaps/`, confirm three stacked panels with visibly different y ranges, then:

```bash
Rscript -e 'testthat::snapshot_accept()'
```

- [ ] **Step 5: Re-run to verify all pass**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-plot-gg_boost_path.R")'`
Expected: PASS, 0 failures

- [ ] **Step 6: Commit**

```bash
git add R/ tests/ NAMESPACE man/
git commit -m "feat: add gg_boost_path renderer"
```

---

### Task 7: Model-object shortcut and a clean `R CMD check`

**Files:**
- Create: `R/autoplot.boostmtree.R`
- Create: `tests/testthat/test-autoplot-boostmtree.R`
- Modify: `NEWS.md`
- Modify: `DESCRIPTION` (version 0.0.1 to 0.0.2)

**Interfaces:**
- Consumes: `gg_boost_error()`, `autoplot.gg_boost_error()`.
- Produces: `autoplot.boostmtree(object, ...)` returning a `ggplot`.

- [ ] **Step 1: Write the failing test**

Create `tests/testthat/test-autoplot-boostmtree.R`:

```r
test_that("autoplot on a model object gives the error plot", {
  fit <- boost_fixture()

  b1 <- ggplot2::ggplot_build(ggplot2::autoplot(fit))
  b2 <- ggplot2::ggplot_build(ggplot2::autoplot(gg_boost_error(fit)))

  # Compare BUILT plots, not the ggplot objects. aes() quosures capture
  # S3-dispatch bookkeeping (.Generic, .Method, ...) from the calling frame,
  # so two identical plots differ as objects when one reaches the renderer
  # through dispatch and the other does not. ggplot_build() evaluates the
  # quosures away, and its $data carries the computed geometry -- so this
  # catches a real divergence in layers, facets or mapping.
  expect_equal(b1$data, b2$data)
  expect_equal(b1$layout$layout, b2$layout$layout)
})

test_that("autoplot on a model object returns a ggplot", {
  expect_s3_class(ggplot2::autoplot(boost_fixture()), "ggplot")
})

test_that("autoplot on a fit without cv.flag explains the cause", {
  fit <- boost_fixture()
  fit$err.rate <- NULL

  expect_error(ggplot2::autoplot(fit), "cv.flag")
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-autoplot-boostmtree.R")'`
Expected: FAIL — no applicable method for `autoplot` applied to a `boostmtree` object

- [ ] **Step 3: Write the shortcut**

Create `R/autoplot.boostmtree.R`:

```r
#' Plot a boostmtree fit
#'
#' A shortcut to the error trajectory, which is the first thing worth looking
#' at after a fit. Every other figure is reached through its own
#' `gg_boost_*()` extractor.
#'
#' @param object A fitted \code{\link[boostmtree]{boostmtree}} object grown
#'   with `cv.flag = TRUE`.
#' @param ... Passed to \code{\link{autoplot.gg_boost_error}}.
#'
#' @return A `ggplot` object, as produced by
#'   \code{\link{autoplot.gg_boost_error}}.
#'
#' @seealso \code{\link{gg_boost_error}}, \code{\link{gg_boost_path}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' fit <- boostmtree::boostmtree(
#'   x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, cv.flag = TRUE, verbose = FALSE
#' )
#' ggplot2::autoplot(fit)
#' }
#'
#' @importFrom ggplot2 autoplot
#' @export
autoplot.boostmtree <- function(object, ...) {
  autoplot.gg_boost_error(gg_boost_error(object), ...)
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-autoplot-boostmtree.R")'`
Expected: PASS, 0 failures

- [ ] **Step 5: Run the whole suite**

Run: `Rscript -e 'pkgload::load_all("."); testthat::test_local()'`
Expected: 0 failures across every test file

- [ ] **Step 6: Bump the patch version**

In `DESCRIPTION` set `Version: 0.0.2`. In `NEWS.md` set line 2 to `Version: 0.0.2` and add above the 0.0.1 section:

```markdown
# ggBoostedTrees 0.0.2

* `gg_boost_error()` and `plot()`/`autoplot()` for the boosting error path,
  marking the cross-validated optimal iteration. Requires a fit grown with
  `cv.flag = TRUE`.
* `gg_boost_path()` and `plot()`/`autoplot()` for the `rho`, `phi` and
  `lambda` parameter paths.
* `autoplot()` on a `boostmtree` fit as a shortcut to the error path.
```

- [ ] **Step 7: Run R CMD check from a clean export**

Build from `git archive`, not the working tree — an empty `inst/doc` fabricates vignette warnings, and in a worktree `.git` is a file that `R CMD build` fails to exclude.

```bash
Rscript -e 'roxygen2::roxygenise(".")'
TMP=$(mktemp -d) && git archive --format=tar HEAD | tar -x -C "$TMP" && \
  R CMD build "$TMP" && R CMD check --as-cran ggBoostedTrees_0.0.2.tar.gz
```

Expected: 0 errors and 0 warnings. Exactly one NOTE is acceptable — the one
about the `Remotes:` field, which is removed at the phase-5 release gate, not
now. Any other note or warning fails this step.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: add autoplot shortcut for boostmtree fits, bump to 0.0.2"
```

---

## Definition of done

- `gg_boost_error()` and `gg_boost_path()` each return the column contract the spec records, for both single- and multi-response objects.
- Both have `autoplot()` implementations and `plot()` aliases returning unthemed `ggplot` objects.
- `autoplot()` on a `boostmtree` fit produces the error plot.
- The fixture is committed with provenance and no test refits a model.
- `R CMD check --as-cran` is clean apart from the expected `Remotes:` note.
