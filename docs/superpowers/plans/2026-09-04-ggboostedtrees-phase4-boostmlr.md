# ggBoostedTrees Phase 4: BoostMLR as a Second Backend

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `BoostMLR` as a second modelling backend for three figures — trajectory, error and parameter paths — by writing extractor methods only, touching no renderer.

**Architecture:** This phase is the test of the claim the architecture was built on. If adding a backend requires changing a renderer, the tidy contract was wrong. It must not.

**Tech Stack:** R (>= 4.4.0), `boostmtree` (>= 2.0.1, the CCF fork), `BoostMLR` (Suggests), `ggplot2`, `rlang`, `testthat` 3e, `vdiffr`, `roxygen2`.

## Scope, decided before planning

`BoostMLR` maps cleanly onto three of the five figures. Two are deliberately out of scope and get their own phase:

- **`gg_boost_vimp`** — `vimp.BoostMLR()` needs a *predict* object rather than a grow object, and returns `Main_Eff` plus **13** `Int_Eff.*` columns rather than one interaction. That is a different decomposition, not the same one in a different shape, and it would require widening a published contract.
- **`gg_boost_effect`** — `partial.BoostMLR()` returns a **plain unclassed list**, so there is nothing for S3 to dispatch on. Supporting it needs a non-S3 entry point, which is a design change rather than an extractor.

Both exclusions are findings about the architecture's limits and belong in the spec, not silently in a plan.

## Global Constraints

- Backend for the primary package is the fork: `Remotes: boostmtree=ehrlinger/boostmtree_src/boostmtree@v2.0.2-ccf`. Do not touch that line, or `DESCRIPTION`'s `URL:` (its trailing slash is deliberate).
- `BoostMLR` stays in **`Suggests:`**, never `Imports:`. Its CRAN release is 1.0.3 with a quiet maintainer, and a hard dependency would make this package archivable if it were archived.
- `Depends: R (>= 4.4.0)`. No hvtiR family member in `Imports:` (that includes `ggRandomForests`).
- Fixtures are committed as `.rds` and never recomputed during `R CMD check`.
- Renderers return a bare `ggplot` with NO theme applied. **No renderer file may be modified in this phase.**
- Version is three-digit semantic (currently 0.0.5). PATCH digit only.
- `\donttest`, never `\dontrun`. `NAMESPACE`/`man/` roxygen-generated only.
- Run the suite with `Rscript -e 'devtools::test()'` — `pkgload::load_all()` + `testthat::test_file()` leaves `NOT_CRAN` unset and silently skips vdiffr snapshots.
- `lintr::lint_package()` must stay at 0.
- All `R/*.R` and `man/*.Rd` pure ASCII.
- Stage files explicitly when committing. `git add -A` has twice swept unintended artifacts into commits in this repository.

## Verified backend facts

Confirmed empirically against `BoostMLR` **1.0.3**, which is what CRAN serves and therefore what `Suggests:` resolves to. (A 2.1.0 exists in a local clone but is not on CRAN; it drops `updateBoostMLR` and is otherwise the same API. Target 1.0.3.)

- A fitted object has class `c("BoostMLR", "grow")` — `grow` in second position, the same convention `boostmtree` uses.
- `$y_Names` holds the response names (`y1`, `y2`, `y3`). `$mu` has **no** column names, so response labels must come from `$y_Names`, never from `colnames(mu)`.
- `$Error_Rate`, `$Rho` and `$Phi` are all M-by-n_response matrices whose colnames match `$y_Names` exactly.
- `$mu` and `$y` are n_observation-by-n_response matrices; `$tm` and `$id` are flat vectors of length n_observation. This is a completely different in-memory layout from `boostmtree`'s nested per-subject lists, holding the same information.
- `$y` is the observed response; `$mu` the fitted.
- Observations arrive already sorted by time within subject. Sort anyway — the contract guarantees it and the cost is nothing.
- **There is no optimal-iteration field.** No `m.opt`, no `Mopt`, nothing in `$Grow_Object`. `partial.BoostMLR()` takes `Mopt` as a user-supplied argument. `gg_boost_error`'s `optimal` column is therefore all `FALSE` for this backend, and that is documented rather than derived.
- `$Lambda_List` is a length-M list of unnamed lists of length-39 numeric vectors — per-iteration basis coefficients, **not** a scalar smoothing parameter per response. It does not correspond to `boostmtree`'s `lambda` and is not extracted.
- A fit with `n = 20, N = 3, M = 50` yields 130 observations across 3 responses and a 307 KB compressed fixture.

## The dependency point worth understanding

These extractors **read list elements; they never call a `BoostMLR` function**. S3 dispatch works off the class attribute alone, so the methods register and work whether or not `BoostMLR` is installed. `requireNamespace()` guards are therefore needed only where a `BoostMLR` object is *created* — the fixture generator — and not in `R/`. Do not add guards to the extractors; they would be cargo cult.

Tests read the committed fixture, so they need no guard either.

---

### Task 1: BoostMLR fixture

**Files:**
- Modify: `tests/testthat/fixtures/make-fixtures.R`
- Create: `tests/testthat/fixtures/boostmlr_grow.rds`
- Modify: `tests/testthat/fixtures/boost_continuous.dcf`
- Modify: `tests/testthat/helper-fixtures.R`
- Modify: `tests/testthat/test-fixtures.R`

**Interfaces:**
- Produces: `boostmlr_fixture()` reading the committed `.rds`.

- [ ] **Step 1: Add the fixture to the generator**

Append to `tests/testthat/fixtures/make-fixtures.R`:

```r
## BoostMLR fixture (Phase 4).
##
## BoostMLR is a Suggests package, so guard its use here. The extractors
## themselves need no guard: they read list elements and never call a BoostMLR
## function, so S3 dispatch works off the class attribute alone.
##
## n = 20, N = 3, M = 50 gives 130 observations across 3 responses in about
## 300 KB. BoostMLR is natively multi-response, which is why this fixture is
## worth having beyond the second-backend proof: it is the first real
## multi-response object in the suite.
if (!requireNamespace("BoostMLR", quietly = TRUE)) {
  message("BoostMLR not installed; skipping boostmlr_grow.rds.")
} else {
  set.seed(3)
  mlr.sim <- BoostMLR::simLong(
    n = 20, N = 3, rho = 0.8, model = 1, q_x = 2, q_y = 0
  )$dtaL

  mlr.fit <- BoostMLR::BoostMLR(
    x = mlr.sim$features, tm = mlr.sim$time, id = mlr.sim$id, y = mlr.sim$y,
    M = 50, VarFlag = TRUE, Verbose = FALSE
  )

  saveRDS(mlr.fit, file.path(here, "boostmlr_grow.rds"), compress = "xz")
  cat("wrote BoostMLR fixture:", length(mlr.fit$tm), "observations,",
      ncol(mlr.fit$y), "responses\n")
}
```

Add to the provenance `writeLines()` vector:

```r
    "",
    "BoostMLR fixture: boostmlr_grow.rds",
    paste0("  BoostMLR ", if (requireNamespace("BoostMLR", quietly = TRUE)) {
      as.character(utils::packageVersion("BoostMLR"))
    } else {
      "not installed"
    }, " (CRAN); simLong(n = 20, N = 3, rho = 0.8, model = 1,"),
    "  q_x = 2, q_y = 0); BoostMLR(M = 50, VarFlag = TRUE); set.seed(3)",
    "  BoostMLR records no optimal iteration, so gg_boost_error()'s",
    "  optimal column is all FALSE for this backend.",
```

- [ ] **Step 2: Generate and confirm**

```bash
Rscript tests/testthat/fixtures/make-fixtures.R
ls -la tests/testthat/fixtures/boostmlr_grow.rds
git status --short tests/testthat/fixtures/
```

Expected: roughly 300 KB, and `boost_continuous.rds` unmodified. If the model fixture is modified, STOP and report.

- [ ] **Step 3: Add the helper**

Append to `tests/testthat/helper-fixtures.R`:

```r
# The BoostMLR grow object. Read from disk, never refit. BoostMLR stores the
# same information as boostmtree in a flat layout: mu and y are
# observation-by-response matrices, tm and id flat vectors.
boostmlr_fixture <- function() {
  readRDS(testthat::test_path("fixtures", "boostmlr_grow.rds"))
}
```

- [ ] **Step 4: Assert the fixture shape**

Append to `tests/testthat/test-fixtures.R`:

```r
test_that("the BoostMLR fixture carries the shapes the extractors read", {
  f <- boostmlr_fixture()

  expect_s3_class(f, "BoostMLR")
  expect_identical(class(f)[2], "grow")
  expect_identical(f$y_Names, c("y1", "y2", "y3"))
  expect_true(is.matrix(f$mu))
  expect_true(is.matrix(f$y))
  expect_identical(dim(f$mu), dim(f$y))
  expect_identical(length(f$tm), nrow(f$mu))
  expect_identical(length(f$id), nrow(f$mu))
})

test_that("the BoostMLR path matrices are M by response", {
  f <- boostmlr_fixture()

  for (nm in c("Error_Rate", "Rho", "Phi")) {
    expect_true(is.matrix(f[[nm]]), label = nm)
    expect_identical(colnames(f[[nm]]), f$y_Names, label = nm)
    expect_identical(nrow(f[[nm]]), as.integer(f$M), label = nm)
  }
})

test_that("BoostMLR records no optimal iteration", {
  f <- boostmlr_fixture()

  # This is why gg_boost_error()'s optimal column is all FALSE for BoostMLR.
  expect_length(grep("opt", names(f), ignore.case = TRUE), 0L)
})

test_that("mu carries no column names, so labels must come from y_Names", {
  f <- boostmlr_fixture()

  expect_null(colnames(f$mu))
})
```

- [ ] **Step 5: Run and commit**

```bash
Rscript -e 'devtools::test(filter = "fixtures")'
git add tests/testthat/fixtures/ tests/testthat/helper-fixtures.R tests/testthat/test-fixtures.R
git commit -m "test: add a BoostMLR grow fixture"
```

---

### Task 2: `gg_boost_trajectory.BoostMLR`

**Files:**
- Modify: `R/gg_boost_trajectory.R`
- Modify: `tests/testthat/test-gg_boost_trajectory.R`

**Interfaces:**
- Produces: `gg_boost_trajectory.BoostMLR(object, ...)` returning the existing contract — `id` (factor), `time` (numeric), `fitted` (numeric), `observed` (numeric), `response` (factor) — sorted by `id` then `time`.

This is the signature figure and the sharpest test of the contract: the source layout is entirely different, and the output must be indistinguishable in shape from the boostmtree method's.

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-gg_boost_trajectory.R`:

```r
test_that("a BoostMLR fit yields the same contract as a boostmtree fit", {
  gg <- gg_boost_trajectory(boostmlr_fixture())

  expect_s3_class(gg, "gg_boost_trajectory")
  expect_identical(
    names(gg), c("id", "time", "fitted", "observed", "response")
  )
  expect_s3_class(gg$id, "factor")
  expect_type(gg$time, "double")
  expect_type(gg$fitted, "double")
  expect_type(gg$observed, "double")
  expect_s3_class(gg$response, "factor")
})

test_that("one row per observation per response", {
  f <- boostmlr_fixture()
  gg <- gg_boost_trajectory(f)

  expect_identical(nrow(gg), length(f$tm) * ncol(f$mu))
  expect_identical(levels(gg$response), f$y_Names)
})

test_that("response labels come from y_Names, not mu colnames", {
  f <- boostmlr_fixture()
  gg <- gg_boost_trajectory(f)

  # mu carries no column names at all, so a label taken from there would be NA.
  expect_null(colnames(f$mu))
  expect_identical(levels(gg$response), c("y1", "y2", "y3"))
})

test_that("fitted and observed come from the matching response column", {
  f <- boostmlr_fixture()
  gg <- gg_boost_trajectory(f)

  rows <- gg[gg$response == "y2", ]
  ord <- order(f$id, f$tm)
  expect_equal(rows$fitted, unname(f$mu[ord, 2]))
  expect_equal(rows$observed, unname(f$y[ord, 2]))
})

test_that("rows are sorted by time within subject", {
  gg <- gg_boost_trajectory(boostmlr_fixture())

  by_subject <- split(gg$time, list(gg$id, gg$response), drop = TRUE)
  expect_false(any(vapply(by_subject, is.unsorted, logical(1))))
})

test_that("the BoostMLR trajectory plot draws without touching a renderer", {
  # The whole architectural claim: a new backend is extractor methods only.
  p <- ggplot2::autoplot(gg_boost_trajectory(boostmlr_fixture()))

  expect_s3_class(p, "ggplot")
  built <- ggplot2::ggplot_build(p)
  expect_gt(nrow(built$data[[1]]), 0L)
})
```

- [ ] **Step 2: Run to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "gg_boost_trajectory")'`
Expected: FAIL — no applicable method, since `gg_boost_trajectory.default` raises for a non-boostmtree object.

- [ ] **Step 3: Implement**

Add to `R/gg_boost_trajectory.R`, after the `boostmtree` method:

```r
#' @export
gg_boost_trajectory.BoostMLR <- function(object, ...) {
  mu <- object$mu
  y <- object$y
  tm <- object$tm
  id <- object$id

  if (is.null(mu) || is.null(tm) || is.null(id)) {
    stop(
      "gg_boost_trajectory: this BoostMLR object records no fitted values, ",
      "times or subject identifiers.",
      call. = FALSE
    )
  }

  # BoostMLR stores one row per observation and one column per response, where
  # boostmtree nests per-subject vectors. Same information, different layout --
  # which is the point: only this extractor changes, never a renderer.
  mu <- as.matrix(mu)
  n_obs <- nrow(mu)
  if (length(tm) != n_obs || length(id) != n_obs) {
    stop(
      "gg_boost_trajectory: the fit records ", n_obs, " fitted row(s) but ",
      length(tm), " time(s) and ", length(id), " identifier(s).",
      call. = FALSE
    )
  }

  labels <- object$y_Names %||% paste0("y", seq_len(ncol(mu)))
  if (length(labels) != ncol(mu)) {
    stop(
      "gg_boost_trajectory: the fit names ", length(labels),
      " response(s) but records ", ncol(mu), " fitted column(s).",
      call. = FALSE
    )
  }

  observed <- if (is.null(y)) {
    matrix(NA_real_, nrow = n_obs, ncol = ncol(mu))
  } else {
    as.matrix(y)
  }

  id_levels <- as.character(unique(id))
  ord <- order(match(as.character(id), id_levels), tm)

  blocks <- lapply(seq_len(ncol(mu)), function(q) {
    data.frame(
      id = factor(as.character(id)[ord], levels = id_levels),
      time = as.numeric(tm)[ord],
      fitted = as.numeric(mu[, q])[ord],
      observed = as.numeric(observed[, q])[ord],
      response = factor(labels[q], levels = labels),
      stringsAsFactors = FALSE
    )
  })

  gg_dta <- do.call(rbind, blocks)
  rownames(gg_dta) <- NULL
  class(gg_dta) <- c("gg_boost_trajectory", class(gg_dta))
  gg_dta
}
```

Document the backend in `@details`: this figure accepts a `boostmtree` or a `BoostMLR` fit, and note that `BoostMLR` is natively multi-response.

- [ ] **Step 4: Run, full suite, lint, commit**

```bash
Rscript -e 'roxygen2::roxygenise("."); devtools::test()'
Rscript -e 'pkgload::load_all("."); print(lintr::lint_package())'
git add R/gg_boost_trajectory.R tests/ man/ NAMESPACE
git commit -m "feat: extract trajectories from BoostMLR fits"
```

Expected: 0 failures, 0 skips, 0 lints. **No file under `R/plot.*` may appear in the diff.** If one does, the contract was wrong — STOP and report.

---

### Task 3: `gg_boost_error.BoostMLR` and `gg_boost_path.BoostMLR`

**Files:**
- Modify: `R/gg_boost_error.R`, `R/gg_boost_path.R`
- Modify: `tests/testthat/test-gg_boost_error.R`, `tests/testthat/test-gg_boost_path.R`

**Interfaces:**
- Produces: `gg_boost_error.BoostMLR(object, ...)` and `gg_boost_path.BoostMLR(object, parameters = c("rho", "phi"), ...)`.

Both are the same shape of work: an M-by-response matrix pivoted long. Note `gg_boost_error.BoostMLR` takes no `use.rmse` argument — `Error_Rate` is already on one scale and there is no `y.sd` to unstandardize by.

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-gg_boost_error.R`:

```r
test_that("a BoostMLR fit yields the error contract", {
  f <- boostmlr_fixture()
  gg <- gg_boost_error(f)

  expect_s3_class(gg, "gg_boost_error")
  expect_identical(
    names(gg), c("iteration", "value", "response", "optimal")
  )
  expect_identical(nrow(gg), as.integer(f$M) * length(f$y_Names))
  expect_identical(levels(gg$response), f$y_Names)
})

test_that("BoostMLR error values come from Error_Rate", {
  f <- boostmlr_fixture()
  gg <- gg_boost_error(f)

  expect_equal(gg$value[gg$response == "y2"], unname(f$Error_Rate[, 2]))
})

test_that("optimal is all FALSE because BoostMLR selects no iteration", {
  gg <- gg_boost_error(boostmlr_fixture())

  # Deriving argmin here would label a computation the backend never did as
  # "the optimal iteration".
  expect_false(any(gg$optimal))
})

test_that("the BoostMLR error plot draws with no optimal rule", {
  p <- ggplot2::autoplot(gg_boost_error(boostmlr_fixture()))

  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_true("GeomLine" %in% geoms)
  expect_false("GeomVline" %in% geoms)
})
```

Append to `tests/testthat/test-gg_boost_path.R`:

```r
test_that("a BoostMLR fit yields rho and phi paths", {
  f <- boostmlr_fixture()
  gg <- gg_boost_path(f)

  expect_identical(
    names(gg), c("iteration", "value", "parameter", "response")
  )
  expect_identical(levels(gg$parameter), c("rho", "phi"))
  expect_identical(nrow(gg), as.integer(f$M) * length(f$y_Names) * 2L)
})

test_that("BoostMLR path values come from Rho and Phi", {
  f <- boostmlr_fixture()
  gg <- gg_boost_path(f)

  expect_equal(
    gg$value[gg$parameter == "rho" & gg$response == "y1"],
    unname(f$Rho[, 1])
  )
  expect_equal(
    gg$value[gg$parameter == "phi" & gg$response == "y3"],
    unname(f$Phi[, 3])
  )
})

test_that("requesting lambda from a BoostMLR fit is refused with a reason", {
  # BoostMLR's Lambda_List holds per-iteration basis coefficients, not a
  # scalar smoothing parameter per response, so it is not the same quantity.
  expect_error(
    gg_boost_path(boostmlr_fixture(), parameters = "lambda"),
    "lambda"
  )
})
```

- [ ] **Step 2: Run to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "gg_boost_(error|path)")'`
Expected: FAIL — no applicable method.

- [ ] **Step 3: Implement both**

Add a shared helper to `R/utils.R`:

```r
# Pivot a BoostMLR M-by-response matrix into long form. BoostMLR stores
# Error_Rate, Rho and Phi identically, so the three extractions differ only in
# which matrix they read and what they call the value.
.boost_mlr_long <- function(mat, labels, value_name) {
  mat <- as.matrix(mat)
  if (ncol(mat) != length(labels)) {
    stop(
      value_name, ": the fit names ", length(labels), " response(s) but ",
      "records ", ncol(mat), " column(s).",
      call. = FALSE
    )
  }
  do.call(rbind, lapply(seq_len(ncol(mat)), function(q) {
    data.frame(
      iteration = seq_len(nrow(mat)),
      value = as.numeric(mat[, q]),
      response = factor(labels[q], levels = labels),
      stringsAsFactors = FALSE
    )
  }))
}
```

Add to `R/gg_boost_error.R`:

```r
#' @export
gg_boost_error.BoostMLR <- function(object, ...) {
  if (is.null(object$Error_Rate)) {
    stop("gg_boost_error: this BoostMLR object records no error path.",
         call. = FALSE)
  }
  labels <- object$y_Names %||% colnames(object$Error_Rate)
  gg_dta <- .boost_mlr_long(object$Error_Rate, labels, "gg_boost_error")

  # BoostMLR selects no optimal iteration -- there is no m.opt equivalent
  # anywhere in the object -- so no row is flagged and the renderer draws no
  # rule. Deriving argmin here would report a choice the backend never made.
  gg_dta$optimal <- FALSE
  gg_dta <- gg_dta[, c("iteration", "value", "response", "optimal")]

  rownames(gg_dta) <- NULL
  class(gg_dta) <- c("gg_boost_error", class(gg_dta))
  gg_dta
}
```

Add to `R/gg_boost_path.R`:

```r
#' @export
gg_boost_path.BoostMLR <- function(object, parameters = c("rho", "phi"), ...) {
  known <- c("rho", "phi")
  unknown <- setdiff(parameters, known)
  if (length(unknown) > 0L) {
    stop(
      "gg_boost_path: BoostMLR records no ",
      paste(sQuote(unknown), collapse = ", "), " path. Its Lambda_List holds ",
      "per-iteration basis coefficients rather than a scalar smoothing ",
      "parameter per response, so it is not the same quantity. Expected any ",
      "of ", paste(sQuote(known), collapse = ", "), ".",
      call. = FALSE
    )
  }
  if (length(parameters) == 0L) {
    stop("gg_boost_path: 'parameters' must be a non-empty character vector.",
         call. = FALSE)
  }
  parameters <- unique(parameters)

  fields <- c(rho = "Rho", phi = "Phi")
  labels <- object$y_Names %||% colnames(object$Rho)

  blocks <- lapply(parameters, function(p) {
    mat <- object[[fields[[p]]]]
    if (is.null(mat)) {
      stop("gg_boost_path: this BoostMLR object records no '", p, "' path.",
           call. = FALSE)
    }
    block <- .boost_mlr_long(mat, labels, "gg_boost_path")
    block$parameter <- factor(p, levels = parameters)
    block[, c("iteration", "value", "parameter", "response")]
  })

  gg_dta <- do.call(rbind, blocks)
  rownames(gg_dta) <- NULL
  class(gg_dta) <- c("gg_boost_path", class(gg_dta))
  gg_dta
}
```

Document both backends in the two `@details` blocks, including that BoostMLR selects no optimal iteration and supplies no comparable lambda.

- [ ] **Step 4: Run, full suite, lint, commit**

```bash
Rscript -e 'roxygen2::roxygenise("."); devtools::test()'
Rscript -e 'pkgload::load_all("."); print(lintr::lint_package())'
git add R/ tests/ man/ NAMESPACE
git commit -m "feat: extract error and parameter paths from BoostMLR fits"
```

Expected: 0 failures, 0 skips, 0 lints. **No file under `R/plot.*` may appear in the diff.**

---

### Task 4: Documentation, version, and a clean check

**Files:**
- Modify: `README.md`, `NEWS.md`, `DESCRIPTION`
- Modify: `docs/superpowers/specs/2026-09-03-ggboostedtrees-design.md`

- [ ] **Step 1: Bump the patch version**

`DESCRIPTION` to `Version: 0.0.6`; `NEWS.md` line 2 to `Version: 0.0.6`. Add above the 0.0.5 section:

```markdown
# ggBoostedTrees 0.0.6

* `BoostMLR` fits are now accepted by `gg_boost_trajectory()`,
  `gg_boost_error()` and `gg_boost_path()`. Adding the backend required
  extractor methods only; no renderer changed, which is what the tidy
  intermediate exists to guarantee.
* `BoostMLR` selects no optimal boosting iteration, so `gg_boost_error()`
  flags none for that backend rather than deriving one.
* `BoostMLR`'s `Lambda_List` holds per-iteration basis coefficients rather
  than a scalar smoothing parameter, so `gg_boost_path()` offers `rho` and
  `phi` for that backend and says so if `lambda` is requested.
* `gg_boost_vimp()` and `gg_boost_effect()` remain `boostmtree` only.
```

- [ ] **Step 2: Record the architectural finding in the spec**

The spec's phase list describes Phase 4 as validating the extension mechanism. Add a short subsection under the Architecture section recording what it actually validated:

- Three of five figures took a second backend as **extractor methods only**, with no renderer touched — the claim holds where the source object is classed and carries the same quantities in a different layout.
- Two did not, for reasons that are properties of the source rather than of this design: `partial.BoostMLR()` returns an **unclassed list**, leaving nothing for S3 to dispatch on; and `vimp.BoostMLR()` reports a genuinely different decomposition (one main effect plus 13 time-basis interaction terms) rather than the same one reshaped.
- Note also that extractors read list elements and never call backend functions, so a Suggests-only backend needs no `requireNamespace()` guard in `R/` — only where an object of that class is created.

- [ ] **Step 3: Update the README**

In the Status table, change the `BoostMLR` row from `Not yet` to something accurate — it is now partial, not complete. State which three figures accept it. Check the sentence counting implemented figures; it has gone stale twice.

In "Related packages", update the `BoostMLR` line to say it is a supported backend for three figures.

- [ ] **Step 4: Verify everything**

```bash
Rscript -e 'roxygen2::roxygenise("."); devtools::test()'
Rscript -e 'pkgload::load_all("."); print(lintr::lint_package())'
Rscript -e 'pkgdown::check_pkgdown()'
Rscript -e 'urlchecker::url_check(".")'
```

- [ ] **Step 5: Run R CMD check from a clean export**

Commit first so `git archive HEAD` sees the changes. `BoostMLR` IS installed locally now, so run the check **without** `_R_CHECK_FORCE_SUGGESTS_=false` — the Suggests-gated fixture path should be exercised for the first time.

```bash
TMP=$(mktemp -d) && git archive --format=tar HEAD | tar -x -C "$TMP" && \
  R CMD build "$TMP" && R CMD check --as-cran ggBoostedTrees_0.0.6.tar.gz
```

Expected: 0 errors, 0 warnings, exactly one NOTE — the `Remotes:` field note. Report every note and warning verbatim, and the total check time. The package now carries a second ~300 KB fixture, so report the tarball size too; the CRAN limit is 5 MB.

Confirm no `Rplots.pdf` appeared, and that all `R/*.R` and `man/*.Rd` are pure ASCII.

- [ ] **Step 6: Commit**

```bash
git add README.md NEWS.md DESCRIPTION docs/ man/
git commit -m "docs: document BoostMLR as a second backend, bump to 0.0.6"
```

---

## Definition of done

- `gg_boost_trajectory()`, `gg_boost_error()` and `gg_boost_path()` accept a `BoostMLR` fit and return contracts indistinguishable from the `boostmtree` ones.
- **No renderer file was modified in this phase.** That is the phase's actual deliverable.
- `optimal` is all `FALSE` for BoostMLR, and requesting `lambda` is refused with the reason.
- The spec records what Phase 4 validated and what it did not.
- `R CMD check --as-cran` runs with Suggests available and is clean apart from the expected `Remotes:` note.
