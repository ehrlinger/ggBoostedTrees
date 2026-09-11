# gg_boost_calibration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `gg_boost_calibration()`: observed against fitted over follow-up, binned by equal-count time bins, with an optional cohort mean curve from a predict object, plus its renderer.

**Architecture:** Same two-step shape as the other five figures. An S3 extractor returns a tidy `data.frame` of class `gg_boost_calibration`; `autoplot.gg_boost_calibration()` renders it and `plot()` aliases it. The extractor calls the existing `gg_boost_trajectory()` for its per-observation rows and adds only binning, so it inherits both backends' storage handling. The cohort curve rides as a `cohort` attribute because it has a different grain from the bin rows.

**Tech Stack:** R (>= 4.4.0), `boostmtree` (>= 2.0.1, the CCF fork), `ggplot2` (4.0.3 installed), `rlang`, `stats`, `testthat` 3e, `vdiffr`, `roxygen2`.

**Spec:** `docs/superpowers/specs/2026-09-11-gg-boost-calibration-design.md`

## Global Constraints

- Work on branch `feat/calibration` (already exists, spec committed at `270f84a`). Never commit to `main`; the PR is merged by the maintainer.
- Backend is the fork, declared as `Remotes: boostmtree=ehrlinger/boostmtree_src/boostmtree@v2.0.2-ccf`. Do not touch that line.
- `DESCRIPTION` declares `Depends: R (>= 4.4.0)`. Do not raise it.
- `DESCRIPTION` must not `Imports:` any hvtiR family member (that includes `ggRandomForests`).
- Fixture models are read from committed `.rds` files and never refit during tests or `R CMD check`.
- Renderers return a bare `ggplot` with NO theme applied.
- Version is three-digit semantic, currently 0.0.6. This change bumps the PATCH digit to 0.0.7. Never `.9000`, never a fourth digit, never the minor digit.
- Examples that fit a model use `\donttest`, never `\dontrun`.
- `NAMESPACE` and `man/` are roxygen2-generated. Run `Rscript -e 'roxygen2::roxygenise(".")'`; never hand-edit either.
- Run the suite with `Rscript -e 'devtools::test()'`. `pkgload::load_all()` plus `testthat::test_file()` leaves `NOT_CRAN` unset and silently skips the vdiffr snapshots.
- Lint with `Rscript -e 'pkgload::load_all(quiet = TRUE); print(lintr::lint_package())'`. Without `load_all()` first, `object_usage_linter` reports about 35 spurious warnings about the package's own functions. Target: 0 lints. Lines at most 80 characters; wrapped `if (` conditions indent their continuation 8 spaces.
- No em-dashes (U+2014) in anything you write: a pre-edit hook rejects them. Use a comma, colon, parentheses or two sentences. Existing em-dashes in files you edit stay as they are; do not include them in an edit's replacement text.
- New arguments are snake_case (`n_bins`, `breaks`, `ci`), matching `n_max` and `subset` in the trajectory renderer.

## Verified facts

Confirmed on 2026-09-11 against the committed fixtures and `boostmtree` 2.0.2 (SHA `5449f5f`). Do not re-derive.

- `boost_continuous.rds`: 25 subjects, 189 observations, observation times from 0.25 to 3 on a 0.25 grid (12 distinct values). Ten quantile bins produce 10 rows, all edges distinct.
- `boostmlr_grow.rds`: class `c("BoostMLR", "grow")`, 130 observations, 3 responses (`y1`, `y2`, `y3`). `gg_boost_trajectory()` on it yields 390 rows.
- `predict(fit, x = fit$x)` on the committed fit returns class `c("boostmtree", "predict", "mtree.pspline.learner")`, is deterministic (two calls give identical `mu`), and is 4.4 MB in memory. Keeping only `n.q`, `q.set`, `id.unique`, `time`, `mu` and the class gives a 0.9 KB `.rds` for which `gg_boost_trajectory()` returns output identical to the full object's.
- In that predict object every subject's `time` element is the same 15-point grid. When `predict()` is given `tm` and `id`, the elements differ per subject.
- `gg_boost_trajectory()` already accepts a boostmtree predict object: it returns one row per subject per grid time with `observed` all `NA`.
- `ggplot2::geom_errorbarh()` is deprecated since ggplot2 4.0.0. Use `geom_segment()` for the horizontal bin span.
- Nothing in `R/` calls `stats::` yet, and `stats` is not in `Imports`. This change adds it.
- The implementation code in Tasks 3 to 5 was run as a prototype against these fixtures before this plan was written, with a script asserting each behaviour the tests below check: the column contract, the hand-computed bin means, the tied-times, single-observation and out-of-range cases, every refusal, the cohort equalling the row means, and a warning-free render with and without the cohort. The testthat files themselves have not been run; the task steps do that. Linting the prototype found two continuation-indent lints, fixed below.

---

### Task 1: Recompose the house style artifact

`.claude/house-style.md` is stale against the vault sources, and the `house-style` workflow fails any PR until it is recomposed. The pinned `house-style-v1` tag is level with `origin/main` of `ehrlinger/house-style`, and its mirrored `sources/` are byte-identical to the vault, so a local recompose produces exactly what CI checks.

**Files:**
- Modify: `.claude/house-style.md` (generated; never hand-edit)

**Interfaces:**
- Consumes: nothing.
- Produces: a current `.claude/house-style.md`.

- [ ] **Step 1: Confirm the drift**

Run:
```bash
Rscript ~/Documents/GitHub/house-style/compose-house-style.R --check --repo ggBoostedTrees
```
Expected: `DRIFT ggBoostedTrees (stale)` and exit code 2.

- [ ] **Step 2: Recompose**

Run:
```bash
Rscript ~/Documents/GitHub/house-style/compose-house-style.R --repo ggBoostedTrees
```
Expected: it names `sources: /Users/ehrlinj/Documents/ObsidianVault/memory` and writes `.claude/house-style.md`.

- [ ] **Step 3: Verify it is now current**

Run the Step 1 command again.
Expected: `OK    ggBoostedTrees`, exit code 0. `git status --short` shows only `M .claude/house-style.md`.

- [ ] **Step 4: Commit**

```bash
git add .claude/house-style.md
git commit -m "chore: recompose the house style artifact

The house-style check fails every PR until the artifact matches the
current sources.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Test fixtures

Two fixtures: a slimmed predict object (committed `.rds`) and a hand-built fit whose times are mostly tied (a helper, no file).

**Files:**
- Create: `tests/testthat/fixtures/boost_predict.rds` (generated by the snippet below)
- Modify: `tests/testthat/fixtures/make-fixtures.R`
- Modify: `tests/testthat/helper-fixtures.R`
- Modify: `tests/testthat/test-fixtures.R`

**Interfaces:**
- Consumes: `tests/testthat/fixtures/boost_continuous.rds`.
- Produces: `boost_predict_fixture()` returning a `c("boostmtree", "predict", "mtree.pspline.learner")` object with fields `n.q`, `q.set`, `id.unique`, `time`, `mu`; `boost_tied_fixture()` returning a `c("boostmtree", "grow")` object with 4 subjects and 12 observations, 8 of them at time 0.

- [ ] **Step 1: Write the failing fixture tests**

Append to `tests/testthat/test-fixtures.R`:

```r
test_that("the predict fixture is a slimmed boostmtree predict object", {
  pred <- boost_predict_fixture()

  expect_s3_class(pred, "boostmtree")
  expect_identical(class(pred)[2], "predict")
  expect_identical(
    sort(names(pred)), sort(c("n.q", "q.set", "id.unique", "time", "mu"))
  )
  expect_length(pred$time, 25L)
  expect_identical(lengths(pred$time), lengths(pred$mu))
})

test_that("the predict fixture puts every subject on one time grid", {
  pred <- boost_predict_fixture()

  expect_true(all(vapply(pred$time, identical, logical(1), pred$time[[1]])))
})

test_that("the predict fixture stays small", {
  # The full predict object is about 4.4 MB. The slimmed one must stay far
  # inside the 5 MB tarball budget.
  expect_lt(file.size(test_path("fixtures", "boost_predict.rds")), 10000)
})

test_that("the tied helper has most observations at one time", {
  obj <- boost_tied_fixture()
  tm <- unlist(obj$time)

  expect_length(tm, 12L)
  expect_identical(sum(tm == 0), 8L)
  expect_identical(lengths(obj$time), lengths(obj$y.org))
})
```

- [ ] **Step 2: Run them to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "fixtures")'`
Expected: FAIL with `could not find function "boost_predict_fixture"` and `could not find function "boost_tied_fixture"`.

- [ ] **Step 3: Add the generator section**

In `tests/testthat/fixtures/make-fixtures.R`, insert this block immediately after the line `cat("wrote fixture, m.opt =", fit$m.opt, "\n")`:

```r
## Slimmed predict fixture (calibration cohort curve).
##
## predict(fit, x = fit$x) on the committed fit is deterministic, but the full
## object is about 4.4 MB. Only the fields gg_boost_trajectory() reads are
## kept, with the class, which leaves under 1 KB.
pred <- predict(fit, x = fit$x)
pred.slim <- structure(
  pred[c("n.q", "q.set", "id.unique", "time", "mu")],
  class = class(pred)
)
saveRDS(pred.slim, file.path(here, "boost_predict.rds"), compress = "xz")
cat("wrote slimmed predict fixture\n")
```

In the same file, inside the `writeLines(c(...))` call, add these three lines immediately after the line `"  optimal column is all FALSE for this backend."` (put a comma after that existing line):

```r
    "",
    "Predict fixture: boost_predict.rds, predict(fit, x = fit$x) keeping n.q,",
    "  q.set, id.unique, time and mu only (the full object is about 4.4 MB)."
```

- [ ] **Step 4: Generate ONLY the new fixture**

Do NOT run the whole generator: it also rewrites the interpretation and factor fixtures, whose refits can change bytes and invalidate committed snapshots. Run just the new block:

```bash
Rscript -e '
here <- file.path("tests", "testthat", "fixtures")
fit <- readRDS(file.path(here, "boost_continuous.rds"))
pred <- predict(fit, x = fit$x)
pred.slim <- structure(
  pred[c("n.q", "q.set", "id.unique", "time", "mu")],
  class = class(pred)
)
saveRDS(pred.slim, file.path(here, "boost_predict.rds"), compress = "xz")
cat(file.size(file.path(here, "boost_predict.rds")), "bytes\n")'
```
Expected: about 900 bytes. `git status --short tests/` shows only `?? tests/testthat/fixtures/boost_predict.rds` plus the two modified `.R` files, and no other `.rds`.

- [ ] **Step 5: Add the helpers**

Append to `tests/testthat/helper-fixtures.R`:

```r
# The slimmed predict object: predict(fit, x = fit$x) on the committed fit,
# keeping only the fields gg_boost_trajectory() reads. Every subject shares
# one 15-point time grid. See fixtures/make-fixtures.R.
boost_predict_fixture <- function() {
  readRDS(testthat::test_path("fixtures", "boost_predict.rds"))
}

# A hand-built fit whose times are mostly tied at 0, as echoes at discharge
# are in clinical data. Eight of twelve observations sit at time 0, so the
# quantile edges collapse. Four bins requested give two:
# [0, 5.25] with 9 observations and (5.25, 8] with 3.
boost_tied_fixture <- function() {
  structure(
    list(
      n.q = 1L,
      q.set = NA,
      id.unique = 1:4,
      time = list(c(0, 0, 0, 5), c(0, 0, 6), c(0, 0, 7), c(0, 8)),
      mu = list(c(1, 1, 1, 2), c(1, 1, 3), c(1, 1, 4), c(1, 5)),
      y.org = list(c(1, 2, 3, 2), c(1, 2, 3), c(2, 1, 4), c(1, 5))
    ),
    class = c("boostmtree", "grow")
  )
}
```

- [ ] **Step 6: Run the fixture tests to verify they pass**

Run: `Rscript -e 'devtools::test(filter = "fixtures")'`
Expected: PASS, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add tests/testthat/fixtures/boost_predict.rds tests/testthat/fixtures/make-fixtures.R tests/testthat/helper-fixtures.R tests/testthat/test-fixtures.R
git commit -m "test: add predict and tied-times fixtures for calibration

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: The binning extractor, both backends

**Files:**
- Create: `R/gg_boost_calibration.R`
- Create: `tests/testthat/test-gg_boost_calibration.R`
- Modify: `DESCRIPTION` (add `stats` to `Imports`)

**Interfaces:**
- Consumes: `gg_boost_trajectory()` (returns `id` factor, `time`, `fitted`, `observed`, `response` factor); `.boost_check_grow(object, call_name)` and `.boost_check_mlr_grow(object, call_name)` from `R/utils.R`; `boost_fixture()`, `boostmlr_fixture()`, `boost_tied_fixture()`, `boost_predict_fixture()`.
- Produces: `gg_boost_calibration(object, pred = NULL, n_bins = 10, breaks = NULL, ...)` returning a `data.frame` of class `c("gg_boost_calibration", "data.frame")` with columns, in order: `response` (factor), `bin` (factor), `time_lo`, `time_hi`, `time` (numeric), `n_obs`, `n_subject` (integer), `observed`, `observed_lo`, `observed_hi`, `fitted` (numeric). Internal helpers `.boost_calibration_check_args(n_bins, breaks)` and `.boost_calibration_bins(traj, n_bins, breaks)`. In this task `pred` is accepted but ignored on the boostmtree path; Task 4 wires it.

- [ ] **Step 1: Write the failing extractor tests**

Create `tests/testthat/test-gg_boost_calibration.R`:

```r
test_that("gg_boost_calibration returns the documented column contract", {
  gg <- gg_boost_calibration(boost_fixture())

  expect_s3_class(gg, "gg_boost_calibration")
  expect_identical(
    names(gg),
    c("response", "bin", "time_lo", "time_hi", "time", "n_obs",
      "n_subject", "observed", "observed_lo", "observed_hi", "fitted")
  )
  expect_s3_class(gg$response, "factor")
  expect_s3_class(gg$bin, "factor")
  expect_type(gg$time, "double")
  expect_type(gg$n_obs, "integer")
  expect_type(gg$n_subject, "integer")
  expect_type(gg$observed, "double")
  expect_type(gg$fitted, "double")
})

test_that("every observation lands in exactly one bin", {
  gg <- gg_boost_calibration(boost_fixture())

  expect_identical(sum(gg$n_obs), 189L)
  expect_true(all(gg$n_subject <= 25L))
  expect_identical(nrow(gg), 10L)
})

test_that("bins are ordered by time and have positive width", {
  gg <- gg_boost_calibration(boost_fixture())

  expect_false(is.unsorted(gg$time_lo))
  expect_true(all(gg$time_lo < gg$time_hi))
  expect_identical(levels(gg$bin), as.character(gg$bin))
})

test_that("bin means match a hand computation", {
  fit <- boost_fixture()
  gg <- gg_boost_calibration(fit, breaks = c(0, 1, 2, 3))

  tm <- unlist(fit$time)
  y <- unlist(fit$y.org)
  mu <- unlist(fit$mu)
  # Right-closed bins, the lowest closed on the left too.
  groups <- list(tm <= 1, tm > 1 & tm <= 2, tm > 2)

  expect_identical(nrow(gg), 3L)
  expect_equal(gg$observed, vapply(groups, function(g) mean(y[g]), 0))
  expect_equal(gg$fitted, vapply(groups, function(g) mean(mu[g]), 0))
  expect_identical(gg$n_obs, vapply(groups, sum, 0L))
})

test_that("the interval is mean +/- 1.96 standard errors", {
  fit <- boost_fixture()
  gg <- gg_boost_calibration(fit, breaks = c(0, 1, 2, 3))

  tm <- unlist(fit$time)
  y <- unlist(fit$y.org)[tm <= 1]
  half <- 1.96 * sd(y) / sqrt(length(y))

  expect_equal(gg$observed_lo[1], mean(y) - half)
  expect_equal(gg$observed_hi[1], mean(y) + half)
})

test_that("tied times merge quantile bins and say so", {
  expect_message(
    gg <- gg_boost_calibration(boost_tied_fixture(), n_bins = 4),
    "tied times left 2 of 4 bins"
  )
  expect_identical(nrow(gg), 2L)
  expect_identical(gg$n_obs, c(9L, 3L))
  expect_equal(gg$time_hi, c(5.25, 8))
})

test_that("a single-observation bin gets NA interval bounds", {
  gg <- gg_boost_calibration(boost_tied_fixture(), breaks = c(0, 7.5, 8))

  expect_identical(gg$n_obs[2], 1L)
  expect_true(is.na(gg$observed_lo[2]))
  expect_true(is.na(gg$observed_hi[2]))
})

test_that("breaks override n_bins and drop out-of-range rows loudly", {
  expect_message(
    gg <- gg_boost_calibration(boost_tied_fixture(), breaks = c(0, 6)),
    "dropped 2 observation"
  )
  expect_identical(sum(gg$n_obs), 10L)
})

test_that("a fit with no observed values is refused", {
  obj <- boost_tied_fixture()
  obj$y.org <- NULL

  expect_error(gg_boost_calibration(obj), "no observed values")
})

test_that("n_bins and breaks are validated", {
  fit <- boost_fixture()

  expect_error(gg_boost_calibration(fit, n_bins = 0), "n_bins")
  expect_error(gg_boost_calibration(fit, n_bins = 2.5), "n_bins")
  expect_error(gg_boost_calibration(fit, n_bins = c(2, 3)), "n_bins")
  expect_error(gg_boost_calibration(fit, breaks = "a"), "breaks")
  expect_error(gg_boost_calibration(fit, breaks = c(1, 1)), "breaks")
})

test_that("a foreign object is refused by name", {
  expect_error(
    gg_boost_calibration(data.frame(x = 1)), "gg_boost_calibration"
  )
})

test_that("a predict object passed as object is refused", {
  expect_error(
    gg_boost_calibration(boost_predict_fixture()), "Pass a predict object"
  )
})

test_that("a BoostMLR fit yields one block of bins per response", {
  gg <- gg_boost_calibration(boostmlr_fixture())

  expect_identical(levels(gg$response), c("y1", "y2", "y3"))
  expect_true(all(table(gg$response) > 0L))
  expect_identical(sum(gg$n_obs), 390L)
})

test_that("a BoostMLR fit refuses a cohort curve", {
  expect_error(
    gg_boost_calibration(boostmlr_fixture(), pred = boost_predict_fixture()),
    "boostmtree fits only"
  )
})
```

- [ ] **Step 2: Run them to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "gg_boost_calibration")'`
Expected: FAIL with `could not find function "gg_boost_calibration"`.

- [ ] **Step 3: Add `stats` to Imports**

In `DESCRIPTION`, change:
```
Imports:
    boostmtree (>= 2.0.1),
    ggplot2,
    rlang
```
to:
```
Imports:
    boostmtree (>= 2.0.1),
    ggplot2,
    rlang,
    stats
```

- [ ] **Step 4: Write the extractor**

Create `R/gg_boost_calibration.R`:

```r
#' Calibration over follow-up data object
#'
#' Compare observed and fitted values over follow-up time, binned by time, with
#' an optional cohort mean curve.
#'
#' @details
#' A cohort's predicted curves say what the model expects; they cannot say
#' whether it matches the data. This figure answers that. Observations are
#' binned by time, and each bin reports the mean observed value, the mean
#' fitted value at the same observations, and how many observations and
#' distinct subjects stand behind it.
#'
#' Bins hold roughly equal numbers of observations by default: the edges are
#' quantiles of observed time, computed per response. Tied times, common in
#' clinical data where many measurements share a visit time, merge quantile
#' edges; duplicates are removed and a message says how many bins survived.
#' Supply `breaks`, in the fit's own time units, to choose the edges yourself.
#' Observations outside the range of `breaks` are dropped, with a message
#' giving the count.
#'
#' With equal-count bins, `n_obs` is nearly constant by construction, so it
#' cannot show where data thins out. Two columns can: bin width
#' (`time_hi - time_lo`), which grows where observations are sparse, and
#' `n_subject`, which falls when a late bin rests on repeat measurements of a
#' few subjects.
#'
#' The interval on `observed` is a normal approximation that treats
#' observations as independent. Repeated measurements within a subject make it
#' too narrow. Read it as a visual guide, not an inferential claim.
#'
#' Supplying `pred` adds the cohort curve: the mean over subjects of the
#' predicted curves on a common time grid, attached as the `cohort` attribute.
#' Make `pred` with `predict(fit, x = ...)` and no `tm` or `id`; with them,
#' each subject is predicted at its own times and a mean across subjects
#' changes composition from one time to the next. The cohort curve is
#' available for \code{boostmtree} fits only.
#'
#' This figure accepts either a \code{boostmtree} or a \code{BoostMLR} grow
#' fit. It reads its rows from \code{\link{gg_boost_trajectory}}, so both
#' backends' storage layouts are handled there.
#'
#' @param object A fitted \code{\link[boostmtree]{boostmtree}} object, or a
#'   fitted \code{BoostMLR} object. Not a predict object: pass that as
#'   `pred`.
#' @param pred Optional \code{boostmtree} predict object from
#'   `predict(fit, x = ...)`, used for the cohort curve.
#' @param n_bins Number of equal-count time bins. Defaults to 10.
#' @param breaks Optional numeric vector of bin edges in the fit's time units.
#'   Overrides `n_bins`.
#' @param ... Not used; present for S3 consistency.
#'
#' @return A `gg_boost_calibration` `data.frame` with one row per response and
#'   bin, ordered by response then time, with columns:
#'   \describe{
#'     \item{response}{Factor naming the response.}
#'     \item{bin}{Factor bin label, ordered by time.}
#'     \item{time_lo, time_hi}{Numeric bin edges.}
#'     \item{time}{Numeric median observed time within the bin.}
#'     \item{n_obs}{Integer count of observations in the bin.}
#'     \item{n_subject}{Integer count of distinct subjects in the bin.}
#'     \item{observed}{Numeric mean observed value.}
#'     \item{observed_lo, observed_hi}{Numeric 95\% interval on `observed`;
#'       `NA` when the bin holds one observation.}
#'     \item{fitted}{Numeric mean fitted value at the same observations.}
#'   }
#'   When `pred` is supplied, the attribute `cohort` holds a `data.frame`
#'   with columns `response` (factor), `time` and `fitted` (numeric).
#'
#' @seealso \code{\link{plot.gg_boost_calibration}},
#'   \code{\link{gg_boost_trajectory}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' fit <- boostmtree::boostmtree(
#'   x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, verbose = FALSE
#' )
#' pred <- predict(fit, x = fit$x)
#' gg <- gg_boost_calibration(fit, pred = pred)
#' plot(gg)
#'
#' # The predicted curves themselves, for a look at who drives the tail:
#' plot(gg_boost_trajectory(pred), n_max = 10)
#' }
#'
#' @export
gg_boost_calibration <- function(object, pred = NULL, n_bins = 10,
                                 breaks = NULL, ...) {
  UseMethod("gg_boost_calibration", object)
}

# Only reached for objects that are not boostmtree or BoostMLR fits.
#' @export
gg_boost_calibration.default <- function(object, pred = NULL, n_bins = 10,
                                         breaks = NULL, ...) {
  .boost_check_grow(object, "gg_boost_calibration")
}

#' @export
gg_boost_calibration.boostmtree <- function(object, pred = NULL, n_bins = 10,
                                            breaks = NULL, ...) {
  # A predict object is also class boostmtree, so dispatch alone does not
  # catch the arguments swapped. Say which slot it belongs in.
  if (!inherits(object, "grow")) {
    stop(
      "gg_boost_calibration: `object` must be a fitted (grow) model. ",
      "Pass a predict object as `pred`.",
      call. = FALSE
    )
  }
  .boost_calibration_check_args(n_bins, breaks)

  .boost_calibration_bins(gg_boost_trajectory(object), n_bins, breaks)
}

#' @export
gg_boost_calibration.BoostMLR <- function(object, pred = NULL, n_bins = 10,
                                          breaks = NULL, ...) {
  .boost_check_mlr_grow(object, "gg_boost_calibration")
  if (!is.null(pred)) {
    stop(
      "gg_boost_calibration: a cohort curve (`pred`) is available for ",
      "boostmtree fits only.",
      call. = FALSE
    )
  }
  .boost_calibration_check_args(n_bins, breaks)

  .boost_calibration_bins(gg_boost_trajectory(object), n_bins, breaks)
}

.boost_calibration_check_args <- function(n_bins, breaks) {
  if (!is.numeric(n_bins) || length(n_bins) != 1L || is.na(n_bins) ||
        n_bins < 1 || n_bins != round(n_bins)) {
    stop(
      "gg_boost_calibration: `n_bins` must be a single whole number of ",
      "at least 1.",
      call. = FALSE
    )
  }
  if (!is.null(breaks) &&
        (!is.numeric(breaks) || anyNA(breaks) ||
           length(unique(breaks)) < 2L)) {
    stop(
      "gg_boost_calibration: `breaks` must be numeric with at least two ",
      "distinct values.",
      call. = FALSE
    )
  }
  invisible(NULL)
}

# Bin one gg_boost_trajectory frame per response. Rows missing either value
# are dropped first: a bin mean over mismatched rows would compare observed
# and fitted values from different observations.
.boost_calibration_bins <- function(traj, n_bins, breaks) {
  traj <- traj[!is.na(traj$observed) & !is.na(traj$fitted), , drop = FALSE]
  if (nrow(traj) == 0L) {
    stop(
      "gg_boost_calibration: this fit records no observed values to ",
      "calibrate against.",
      call. = FALSE
    )
  }

  labels <- levels(traj$response)
  blocks <- lapply(labels, function(r) {
    d <- traj[traj$response == r, , drop = FALSE]

    if (is.null(breaks)) {
      edges <- unique(stats::quantile(
        d$time, probs = seq(0, 1, length.out = n_bins + 1L), names = FALSE
      ))
      if (length(edges) < 2L) {
        stop(
          "gg_boost_calibration: every observation of response '", r,
          "' is at one time; there is nothing to bin.",
          call. = FALSE
        )
      }
      if (length(edges) - 1L < n_bins) {
        message(
          "gg_boost_calibration: tied times left ", length(edges) - 1L,
          " of ", n_bins, " bins for response '", r, "'."
        )
      }
    } else {
      edges <- sort(unique(breaks))
      out <- d$time < edges[1L] | d$time > edges[length(edges)]
      if (any(out)) {
        message(
          "gg_boost_calibration: dropped ", sum(out),
          " observation(s) of response '", r,
          "' outside the range of `breaks`."
        )
        d <- d[!out, , drop = FALSE]
      }
    }

    bin <- cut(d$time, edges, include.lowest = TRUE)
    # drop = TRUE: a supplied `breaks` can leave bins empty, and an empty bin
    # has no mean to report.
    idx <- split(seq_len(nrow(d)), bin, drop = TRUE)

    rows <- lapply(names(idx), function(b) {
      i <- idx[[b]]
      y <- d$observed[i]
      n <- length(i)
      half <- if (n >= 2L) 1.96 * stats::sd(y) / sqrt(n) else NA_real_
      k <- match(b, levels(bin))
      data.frame(
        response = factor(r, levels = labels),
        bin = b,
        time_lo = edges[k],
        time_hi = edges[k + 1L],
        time = stats::median(d$time[i]),
        n_obs = n,
        n_subject = length(unique(d$id[i])),
        observed = mean(y),
        observed_lo = mean(y) - half,
        observed_hi = mean(y) + half,
        fitted = mean(d$fitted[i]),
        stringsAsFactors = FALSE
      )
    })
    do.call(rbind, rows)
  })

  gg_dta <- do.call(rbind, blocks)
  gg_dta$bin <- factor(gg_dta$bin, levels = unique(gg_dta$bin))
  rownames(gg_dta) <- NULL
  class(gg_dta) <- c("gg_boost_calibration", "data.frame")
  gg_dta
}
```

- [ ] **Step 5: Regenerate NAMESPACE and man/**

Run: `Rscript -e 'roxygen2::roxygenise(".")'`
Expected: writes `man/gg_boost_calibration.Rd` and adds `S3method(gg_boost_calibration,BoostMLR)`, `S3method(gg_boost_calibration,boostmtree)`, `S3method(gg_boost_calibration,default)` and `export(gg_boost_calibration)` to `NAMESPACE`. A warning that `plot.gg_boost_calibration` is an unresolved link is expected until Task 5.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `Rscript -e 'devtools::test(filter = "gg_boost_calibration")'`
Expected: PASS, 0 failures. The tied-times and out-of-range messages are captured by `expect_message()` and do not print.

- [ ] **Step 7: Lint**

Run: `Rscript -e 'pkgload::load_all(quiet = TRUE); print(lintr::lint_package())'`
Expected: no lints.

- [ ] **Step 8: Commit**

```bash
git add DESCRIPTION NAMESPACE R/gg_boost_calibration.R man/gg_boost_calibration.Rd tests/testthat/test-gg_boost_calibration.R
git commit -m "feat: gg_boost_calibration extractor for both backends

Bins observed and fitted values by equal-count time bins, per response,
reading rows from gg_boost_trajectory().

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: The cohort curve

**Files:**
- Modify: `R/gg_boost_calibration.R`
- Modify: `tests/testthat/test-gg_boost_calibration.R`

**Interfaces:**
- Consumes: `gg_boost_calibration.boostmtree()` from Task 3; `boost_predict_fixture()`.
- Produces: `.boost_calibration_cohort(pred, object)` returning a `data.frame` with columns `response` (factor), `time`, `fitted` (numeric), ordered by response then time; attached by the boostmtree method as `attr(gg, "cohort")` when `pred` is not `NULL`.

- [ ] **Step 1: Write the failing cohort tests**

Append to `tests/testthat/test-gg_boost_calibration.R`:

```r
test_that("no pred means no cohort attribute", {
  expect_null(attr(gg_boost_calibration(boost_fixture()), "cohort"))
})

test_that("the cohort curve is the mean predicted curve", {
  pred <- boost_predict_fixture()
  gg <- gg_boost_calibration(boost_fixture(), pred = pred)
  cohort <- attr(gg, "cohort")

  expect_identical(names(cohort), c("response", "time", "fitted"))
  expect_s3_class(cohort$response, "factor")
  expect_equal(cohort$time, sort(pred$time[[1]]))
  # One column per subject, rows are grid times.
  expect_equal(cohort$fitted, rowMeans(do.call(cbind, pred$mu)))
})

test_that("a pred of the wrong class is refused", {
  expect_error(
    gg_boost_calibration(boost_fixture(), pred = list(a = 1)),
    "must be a boostmtree predict object"
  )
})

test_that("a pred with a different response count is refused", {
  pred <- boost_predict_fixture()
  pred$n.q <- 2L

  expect_error(
    gg_boost_calibration(boost_fixture(), pred = pred),
    "records 2 response"
  )
})

test_that("a pred on subject-specific times is refused", {
  pred <- boost_predict_fixture()
  # What predict() produces when given tm and id: ragged time vectors.
  pred$time[[1]] <- pred$time[[1]][-1]
  pred$mu[[1]] <- pred$mu[[1]][-1]

  expect_error(
    gg_boost_calibration(boost_fixture(), pred = pred),
    "without `tm` and `id`"
  )
})
```

- [ ] **Step 2: Run them to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "gg_boost_calibration")'`
Expected: FAIL. `the cohort curve is the mean predicted curve` fails because the attribute is `NULL`; the three refusal tests fail because no error is raised.

- [ ] **Step 3: Wire `pred` into the boostmtree method**

In `R/gg_boost_calibration.R`, replace the last statement of `gg_boost_calibration.boostmtree()`:

```r
  .boost_calibration_bins(gg_boost_trajectory(object), n_bins, breaks)
}

#' @export
gg_boost_calibration.BoostMLR <- function(object, pred = NULL, n_bins = 10,
```

with:

```r
  gg_dta <- .boost_calibration_bins(
    gg_boost_trajectory(object), n_bins, breaks
  )
  if (!is.null(pred)) {
    attr(gg_dta, "cohort") <- .boost_calibration_cohort(pred, object)
  }
  gg_dta
}

#' @export
gg_boost_calibration.BoostMLR <- function(object, pred = NULL, n_bins = 10,
```

- [ ] **Step 4: Add the cohort helper**

Append to `R/gg_boost_calibration.R`:

```r
# The cohort curve: the mean over subjects of the predicted curves. It is only
# meaningful when every subject is predicted on the same grid, which is what
# predict(fit, x = ...) does without tm and id. Averaging ragged time sets
# would change which subjects contribute from one time to the next.
.boost_calibration_cohort <- function(pred, object) {
  if (!inherits(pred, "boostmtree") || !inherits(pred, "predict")) {
    stop(
      "gg_boost_calibration: `pred` must be a boostmtree predict object, ",
      "from predict(fit, x = ...).",
      call. = FALSE
    )
  }
  n_q <- object$n.q %||% 1L
  n_q_pred <- pred$n.q %||% 1L
  if (n_q_pred != n_q) {
    stop(
      "gg_boost_calibration: `pred` records ", n_q_pred,
      " response(s) but the fit records ", n_q, ".",
      call. = FALSE
    )
  }

  times <- pred$time
  same_grid <- length(times) > 0L &&
    all(vapply(times, identical, logical(1), times[[1L]]))
  if (!same_grid) {
    stop(
      "gg_boost_calibration: `pred` does not predict every subject on ",
      "one time grid. Call predict(fit, x = ...) without `tm` and `id`.",
      call. = FALSE
    )
  }

  traj <- gg_boost_trajectory(pred)
  cohort <- stats::aggregate(
    fitted ~ response + time, data = traj, FUN = mean
  )
  cohort <- cohort[
    order(cohort$response, cohort$time), c("response", "time", "fitted")
  ]
  rownames(cohort) <- NULL
  cohort
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `Rscript -e 'devtools::test(filter = "gg_boost_calibration")'`
Expected: PASS, 0 failures.

- [ ] **Step 6: Lint**

Run: `Rscript -e 'pkgload::load_all(quiet = TRUE); print(lintr::lint_package())'`
Expected: no lints.

- [ ] **Step 7: Commit**

```bash
git add R/gg_boost_calibration.R tests/testthat/test-gg_boost_calibration.R
git commit -m "feat: cohort mean curve for gg_boost_calibration

Supplying a boostmtree predict object attaches the mean predicted curve
as the cohort attribute. A pred on subject-specific times is refused.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: The renderer

**Files:**
- Create: `R/plot.gg_boost_calibration.R`
- Create: `tests/testthat/test-plot-gg_boost_calibration.R`
- Create: `tests/testthat/_snaps/plot-gg_boost_calibration/*.svg` (generated by vdiffr)

**Interfaces:**
- Consumes: a `gg_boost_calibration` object and its optional `cohort` attribute (Tasks 3 and 4); `.boost_check_gg(object, class_name)` from `R/utils.R`.
- Produces: `autoplot.gg_boost_calibration(object, ci = TRUE, ...)` and `plot.gg_boost_calibration(x, ci = TRUE, ...)`, each returning a `ggplot`.

- [ ] **Step 1: Write the failing renderer tests**

Create `tests/testthat/test-plot-gg_boost_calibration.R`:

```r
layer_geoms <- function(p) {
  vapply(p$layers, function(l) class(l$geom)[1], character(1))
}

test_that("autoplot returns a ggplot", {
  p <- ggplot2::autoplot(gg_boost_calibration(boost_fixture()))

  expect_s3_class(p, "ggplot")
})

test_that("plot is an alias for autoplot", {
  gg <- gg_boost_calibration(boost_fixture())

  b1 <- ggplot2::ggplot_build(plot(gg))
  b2 <- ggplot2::ggplot_build(ggplot2::autoplot(gg))

  # Compare BUILT plots: aes() quosures capture dispatch bookkeeping, so two
  # identical plots differ as objects when only one went through dispatch.
  expect_equal(b1$data, b2$data)
  expect_equal(b1$layout$layout, b2$layout$layout)
})

test_that("the renderer rejects a foreign object", {
  expect_error(
    plot.gg_boost_calibration(data.frame(x = 1)), "gg_boost_calibration"
  )
})

test_that("axis labels name time and the response", {
  p <- ggplot2::autoplot(gg_boost_calibration(boost_fixture()))

  expect_identical(p$labels$x, "Time")
  expect_identical(p$labels$y, "Response")
})

test_that("bin spans, intervals, fitted line and points are drawn", {
  p <- ggplot2::autoplot(gg_boost_calibration(boost_fixture()))

  expect_identical(
    layer_geoms(p),
    c("GeomSegment", "GeomLinerange", "GeomLine", "GeomPoint")
  )
})

test_that("ci = FALSE drops the interval layer", {
  p <- ggplot2::autoplot(gg_boost_calibration(boost_fixture()), ci = FALSE)

  expect_false("GeomLinerange" %in% layer_geoms(p))
})

test_that("a cohort attribute adds the cohort line", {
  gg <- gg_boost_calibration(boost_fixture(), pred = boost_predict_fixture())
  p <- ggplot2::autoplot(gg)

  expect_identical(sum(layer_geoms(p) == "GeomLine"), 2L)
})

test_that("building does not warn, including single-observation bins", {
  gg <- gg_boost_calibration(boost_tied_fixture(), breaks = c(0, 7.5, 8))

  expect_no_warning(ggplot2::ggplot_build(ggplot2::autoplot(gg)))
  expect_no_warning(ggplot2::ggplot_build(ggplot2::autoplot(
    gg_boost_calibration(boost_fixture(), pred = boost_predict_fixture())
  )))
})

test_that("several responses facet and one does not", {
  multi <- ggplot2::autoplot(gg_boost_calibration(boostmlr_fixture()))
  single <- ggplot2::autoplot(gg_boost_calibration(boost_fixture()))

  expect_s3_class(multi$facet, "FacetWrap")
  expect_false(inherits(single$facet, "FacetWrap"))
})

test_that("the univariate calibration plot is stable", {
  skip_on_cran()
  # Text rendering is not byte-identical across platforms, and the committed
  # reference SVGs were generated on macOS.
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "calibration univariate",
    ggplot2::autoplot(gg_boost_calibration(boost_fixture()))
  )
})

test_that("the calibration plot with a cohort curve is stable", {
  skip_on_cran()
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "calibration cohort",
    ggplot2::autoplot(
      gg_boost_calibration(boost_fixture(), pred = boost_predict_fixture())
    )
  )
})

test_that("the multi-response calibration plot is stable", {
  skip_on_cran()
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "calibration multi response",
    ggplot2::autoplot(gg_boost_calibration(boostmlr_fixture()))
  )
})
```

- [ ] **Step 2: Run them to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "plot-gg_boost_calibration")'`
Expected: FAIL with `could not find function "plot.gg_boost_calibration"` and no ggplot returned by `autoplot`.

- [ ] **Step 3: Write the renderer**

Create `R/plot.gg_boost_calibration.R`:

```r
#' Plot a \code{\link{gg_boost_calibration}} object
#'
#' Observed against fitted over follow-up: bin means of the observed values
#' with their intervals, the fitted bin means beside them, and the cohort mean
#' curve when the object carries one.
#'
#' @details
#' Each bin is drawn as a thin horizontal segment spanning its time range at
#' the observed mean. With equal-count bins that segment is the tail-support
#' signal: where observations are sparse, a bin has to stretch further to
#' collect its share, so a long segment late in follow-up means a thin tail.
#'
#' Observed bin means are points with vertical 95\% intervals (`ci = TRUE`);
#' fitted bin means are a second point series in another shape, joined by a
#' dashed line. Where the two agree bin by bin, the model is calibrated over
#' that stretch of follow-up. The cohort curve, drawn as a heavier line, is
#' the mean predicted curve across all subjects; it can depart from the bin
#' means late in follow-up when the subjects still being measured differ from
#' the cohort, which is a property of follow-up rather than of the model.
#'
#' The returned plot carries no theme.
#'
#' @param object A \code{\link{gg_boost_calibration}} object.
#' @param x A \code{\link{gg_boost_calibration}} object.
#' @param ci Logical. Draw 95\% intervals on the observed bin means. Defaults
#'   to `TRUE`; bins holding one observation have none.
#' @param ... Not used; present for S3 consistency.
#'
#' @return A `ggplot` object.
#'
#' @seealso \code{\link{gg_boost_calibration}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' fit <- boostmtree::boostmtree(
#'   x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, verbose = FALSE
#' )
#' plot(gg_boost_calibration(fit, pred = predict(fit, x = fit$x)))
#' }
#'
#' @importFrom ggplot2 autoplot ggplot aes geom_segment geom_linerange
#'   geom_line geom_point facet_wrap labs
#' @export
autoplot.gg_boost_calibration <- function(object, ci = TRUE, ...) {
  .boost_check_gg(object, "gg_boost_calibration")

  cohort <- attr(object, "cohort")
  dta <- as.data.frame(unclass(object), stringsAsFactors = FALSE)

  # Observed and fitted share the point layer so one shape legend
  # distinguishes them.
  pts <- rbind(
    data.frame(response = dta$response, time = dta$time,
               value = dta$observed, series = "Observed"),
    data.frame(response = dta$response, time = dta$time,
               value = dta$fitted, series = "Fitted")
  )
  pts$series <- factor(pts$series, levels = c("Observed", "Fitted"))

  gg_plt <- ggplot2::ggplot() +
    ggplot2::geom_segment(
      data = dta,
      ggplot2::aes(
        x = .data[["time_lo"]], xend = .data[["time_hi"]],
        y = .data[["observed"]], yend = .data[["observed"]]
      ),
      colour = "grey60"
    )

  if (isTRUE(ci)) {
    # A single-observation bin has NA bounds; drawing it would emit a
    # removed-rows warning and show nothing.
    gg_plt <- gg_plt +
      ggplot2::geom_linerange(
        data = dta[!is.na(dta$observed_lo), , drop = FALSE],
        ggplot2::aes(
          x = .data[["time"]], ymin = .data[["observed_lo"]],
          ymax = .data[["observed_hi"]]
        )
      )
  }

  gg_plt <- gg_plt +
    ggplot2::geom_line(
      data = pts[pts$series == "Fitted", , drop = FALSE],
      ggplot2::aes(
        x = .data[["time"]], y = .data[["value"]],
        group = .data[["response"]]
      ),
      linetype = "dashed"
    ) +
    ggplot2::geom_point(
      data = pts,
      ggplot2::aes(
        x = .data[["time"]], y = .data[["value"]],
        shape = .data[["series"]]
      ),
      size = 2
    )

  if (!is.null(cohort)) {
    gg_plt <- gg_plt +
      ggplot2::geom_line(
        data = cohort,
        ggplot2::aes(
          x = .data[["time"]], y = .data[["fitted"]],
          group = .data[["response"]]
        ),
        linewidth = 1.2
      )
  }

  gg_plt <- gg_plt +
    ggplot2::labs(x = "Time", y = "Response", shape = NULL)

  if (nlevels(dta$response) > 1L) {
    gg_plt <- gg_plt +
      ggplot2::facet_wrap(~ response, scales = "free_y")
  }

  gg_plt
}

#' @rdname autoplot.gg_boost_calibration
#' @export
plot.gg_boost_calibration <- function(x, ci = TRUE, ...) {
  autoplot.gg_boost_calibration(x, ci = ci, ...)
}
```

- [ ] **Step 4: Regenerate NAMESPACE and man/**

Run: `Rscript -e 'roxygen2::roxygenise(".")'`
Expected: writes `man/autoplot.gg_boost_calibration.Rd`; `NAMESPACE` gains `S3method(autoplot,gg_boost_calibration)`, `S3method(plot,gg_boost_calibration)`, and `geom_linerange` and `geom_segment` in the `importFrom(ggplot2, ...)` block. The Task 3 unresolved-link warning is gone.

- [ ] **Step 5: Run the tests; generate the snapshots**

Run: `Rscript -e 'devtools::test(filter = "plot-gg_boost_calibration")'`
Expected: all non-snapshot tests PASS. The three `expect_doppelganger()` calls report new snapshots being added under `tests/testthat/_snaps/plot-gg_boost_calibration/`, which is expected on a first run.

- [ ] **Step 6: Inspect the snapshots, then re-run**

Open the three new `.svg` files and check: grey horizontal segments at each observed mean; circles with vertical intervals; triangles joined by a dashed line; a heavy line in `calibration-cohort.svg` only; three facets `y1`, `y2`, `y3` in `calibration-multi-response.svg`.

Run the Step 5 command again.
Expected: PASS, 0 failures, 0 new snapshots.

- [ ] **Step 7: Run the full suite and lint**

Run: `Rscript -e 'devtools::test()'`
Expected: 0 failures, 0 warnings; the pre-existing snapshots are unchanged.

Run: `Rscript -e 'pkgload::load_all(quiet = TRUE); print(lintr::lint_package())'`
Expected: no lints.

- [ ] **Step 8: Commit**

```bash
git add NAMESPACE R/plot.gg_boost_calibration.R man/autoplot.gg_boost_calibration.Rd tests/testthat/test-plot-gg_boost_calibration.R tests/testthat/_snaps/plot-gg_boost_calibration
git commit -m "feat: renderer for gg_boost_calibration

Bin spans carry the tail-support signal; observed and fitted bin means
share one shape legend; the cohort curve draws when present.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Documentation, version, gate and PR

**Files:**
- Modify: `DESCRIPTION` (lines `Version:` and `Date:`)
- Modify: `NEWS.md`
- Modify: `README.md` (status table; lines 26 and 38)
- Modify: `R/gg_boost_effect.R:36`
- Modify: `_pkgdown.yml`

**Interfaces:**
- Consumes: everything above.
- Produces: an open PR from `feat/calibration` to `main`.

- [ ] **Step 1: Bump the version**

In `DESCRIPTION`, change `Version: 0.0.6` to `Version: 0.0.7` and `Date: 2026-09-04` to `Date: 2026-09-11`.

- [ ] **Step 2: Add the NEWS entry**

In `NEWS.md`, change line 2 from `Version: 0.0.6` to `Version: 0.0.7` (a test greps NEWS for the exact DESCRIPTION version), then insert above `# ggBoostedTrees 0.0.6`:

```markdown
# ggBoostedTrees 0.0.7

* New `gg_boost_calibration()` compares observed and fitted values over
  follow-up. Observations are binned by time into equal-count bins, and each
  bin reports the observed mean with a 95% interval, the fitted mean at the
  same observations, and how many observations and distinct subjects stand
  behind it. It accepts `boostmtree` and `BoostMLR` fits.
* Supplying a `boostmtree` predict object as `pred` adds the cohort mean
  curve. A predict object made with `tm` and `id` is refused, because each
  subject is then predicted at its own times and a mean across subjects
  would change composition along the curve.
* The renderer draws each bin's time span, so a thin tail shows as a long
  late bin.

```

- [ ] **Step 3: Update the counts and the status table**

`README.md` line 26: change `The five implemented figures are complete and tested.` to `The six implemented figures are complete and tested.`

`README.md` line 38: change `three of the five figures` to `four of the six figures`.

`R/gg_boost_effect.R` line 36: change `the one class of the five without a` to `the one class of the six without a`. Then run `Rscript -e 'roxygen2::roxygenise(".")'` so `man/gg_boost_effect.Rd` follows.

In the `README.md` status table, insert this row after the `| Partial and marginal effects | Implemented |` row:

```markdown
| Calibration over follow-up, observed against fitted, with the cohort mean curve | Implemented |
```

In the `BoostMLR` row of the same table, edit only its list of function names. Replace the substring:

```
`gg_boost_trajectory()`, `gg_boost_error()` and `gg_boost_path()` accept it
```

with:

```
`gg_boost_trajectory()`, `gg_boost_error()`, `gg_boost_path()` and `gg_boost_calibration()` accept it
```

Everything else in that row, including its punctuation, stays exactly as it is.

Verify: `grep -n -i "five" README.md R/*.R` returns nothing.

- [ ] **Step 4: Add the reference entries**

In `_pkgdown.yml`, add `  - gg_boost_calibration` after `  - gg_boost_effect` in section `1. Extract`, and `  - autoplot.gg_boost_calibration` after `  - autoplot.gg_boost_effect` in section `2. Render`.

Verify: `Rscript -e 'pkgdown::check_pkgdown()'` reports no problems.

- [ ] **Step 5: Run the local gate**

Run each; all must be clean before the PR.
```bash
Rscript -e 'devtools::test()'
```
Expected: 0 failures, 0 warnings, and no skips beyond the platform skips already in the suite.

```bash
Rscript -e 'pkgload::load_all(quiet = TRUE); print(lintr::lint_package())'
```
Expected: no lints.

```bash
Rscript -e 'devtools::check(document = FALSE)'
```
Expected: 0 errors, 0 warnings, 1 note: the deliberate `Remotes:` note. Any other note, in particular an undeclared `stats` import, is a failure to fix.

```bash
Rscript ~/Documents/GitHub/house-style/compose-house-style.R --check --repo ggBoostedTrees
```
Expected: `OK    ggBoostedTrees`.

- [ ] **Step 6: Commit**

```bash
git add DESCRIPTION NEWS.md README.md R/gg_boost_effect.R man/gg_boost_effect.Rd _pkgdown.yml
git commit -m "docs: version 0.0.7, NEWS, README and pkgdown for calibration

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

- [ ] **Step 7: Push and open the PR**

```bash
git push -u origin feat/calibration
gh pr create --base main --title "feat: gg_boost_calibration, observed against fitted over follow-up" --body "$(cat <<'EOF'
Adds `gg_boost_calibration()` and its renderer, per `docs/superpowers/specs/2026-09-11-gg-boost-calibration-design.md`.

- Bins observed and fitted values by equal-count time bins, per response, for `boostmtree` and `BoostMLR` fits. Rows come from `gg_boost_trajectory()`, so both storage layouts are handled there.
- A `boostmtree` predict object as `pred` adds the cohort mean curve; a predict object on subject-specific times is refused.
- Bin spans carry the tail-support signal that equal-count bins remove from `n_obs`.
- Recomposes `.claude/house-style.md`, which had drifted from its sources.
- Version 0.0.6 to 0.0.7 (patch).

Motivated by a cohort analysis where the mean predicted curve could not be checked against the data from the existing figures.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
Expected: a PR URL. Do not merge; the maintainer merges.
