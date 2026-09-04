# ggBoostedTrees Phase 2: Longitudinal Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `gg_boost_trajectory` — observed and fitted subject trajectories over time — the figure that distinguishes this package from every other boosting-diagnostics tool.

**Architecture:** Unchanged from Phase 1. An S3 extractor dispatching on the model object returns a tidy `data.frame` with a documented column contract and a `gg_boost_trajectory` class; `autoplot.gg_boost_trajectory()` renders it and `plot()` aliases it. The renderer knows only the data frame.

**Tech Stack:** R (>= 4.4.0), `boostmtree` (>= 2.0.1, the CCF fork), `ggplot2`, `rlang`, `testthat` 3e, `vdiffr`, `roxygen2`.

## Global Constraints

- Backend is the fork, declared as `Remotes: boostmtree=ehrlinger/boostmtree_src/boostmtree@v2.0.2-ccf`. The `boostmtree=` prefix and the `/boostmtree` subdir are both load-bearing — do not touch that line.
- `DESCRIPTION` declares `Depends: R (>= 4.4.0)`. Do not raise it.
- `DESCRIPTION` must not `Imports:` any hvtiR family member (that includes `ggRandomForests`).
- Fixture models are read from the committed `.rds` and never refit during `R CMD check`.
- Renderers return a bare `ggplot` with NO theme applied.
- Package version is three-digit semantic (currently 0.0.2). Bump the PATCH digit only. Never `.9000` or four digits.
- Examples that fit a model use `\donttest`, never `\dontrun`.
- `NAMESPACE` and `man/` are roxygen2-generated. Run `roxygen2::roxygenise(".")`; never hand-edit.
- Run the suite with `Rscript -e 'devtools::test()'`. `pkgload::load_all()` + `testthat::test_file()` leaves `NOT_CRAN` unset and silently skips the vdiffr snapshots.
- Lint with the committed `.lintr` against lintr 3.4.0. `dotted.case` is accepted deliberately.

## Verified backend facts

Confirmed against the committed fixture and `boostmtree` 2.0.2. Do not re-derive.

- `time`, `mu` and `y.org` are **parallel lists of per-subject numeric vectors**, one element per subject, with matching lengths. The fixture has 25 subjects, 3–12 observations each, 189 total.
- **Times are stored in input order, not time order.** All 25 fixture subjects have unsorted times and 20 have duplicate times. A line drawn from stored order zigzags. Sorting within subject is a correctness requirement.
- `id.unique` holds the real subject identifiers in the **same order as those per-subject lists**, and per-subject observation counts align with runs of `id`. Use it; do not synthesise an index.
- For `n.q > 1`, `mu` and `y.org` are lists indexed by response, each element a list of per-subject vectors — the same nesting `err.rate` uses. `boostmtree.as.q.list()` upstream wraps the univariate case to match.
- `y.org` can be absent (a predict object built without observed values). The extractor must tolerate that.
- On the committed fixture only 9 of 25 subjects have a fitted trajectory that varies with time; the rest are flat. That is honest output at `M = 50`. It is sufficient for testing — the 9 varying subjects exercise ordering — but do not be alarmed by flat lines in a snapshot.

---

### Task 1: `gg_boost_trajectory` extractor

**Files:**
- Create: `R/gg_boost_trajectory.R`
- Create: `tests/testthat/test-gg_boost_trajectory.R`
- Modify: `tests/testthat/helper-fixtures.R`
- Modify: `tests/testthat/test-fixtures.R`

**Interfaces:**
- Consumes: `.boost_check_grow()`, `.boost_response_labels()`, `%||%` from `R/utils.R`; `boost_fixture()`, `boost_multi_fixture()`.
- Produces: `gg_boost_trajectory(object, ...)` returning a `data.frame` of class `c("gg_boost_trajectory", "data.frame")` with columns `id` (factor), `time` (numeric), `fitted` (numeric), `observed` (numeric), `response` (factor), sorted by `id` then `time`.

- [ ] **Step 1: Extend the multi-response fixture**

`boost_multi_fixture()` currently carries only the fields the error and path extractors read. Add the trajectory fields, keeping the existing ones untouched. In `tests/testthat/helper-fixtures.R`, add these three elements to the `list(...)` inside `structure()`:

```r
    # Trajectory fields. Per-subject vectors, nested by response exactly as
    # boostmtree nests mu and y.org when n.q > 1. Times are deliberately
    # out of order and contain a duplicate, mirroring what boostmtree
    # actually stores -- the extractor must sort them.
    id.unique = c(101, 102),
    time = list(c(2, 1, 1), c(3, 1)),
    mu = list(
      list(c(0.2, 0.1, 0.1), c(0.3, 0.1)),
      list(c(1.2, 1.1, 1.1), c(1.3, 1.1))
    ),
    y.org = list(
      list(c(0.25, 0.15, 0.05), c(0.35, 0.15)),
      list(c(1.25, 1.15, 1.05), c(1.35, 1.15))
    ),
```

- [ ] **Step 2: Assert the extended fixture in `test-fixtures.R`**

Append:

```r
test_that("the multi-response helper carries nested trajectory fields", {
  obj <- boost_multi_fixture()

  expect_length(obj$time, 2L)
  expect_length(obj$mu, 2L)
  expect_true(is.list(obj$mu[[1]]))
  expect_identical(lengths(obj$time), lengths(obj$mu[[1]]))
  expect_true(is.unsorted(obj$time[[1]]))
})
```

- [ ] **Step 3: Run it to confirm the fixture is well formed**

Run: `Rscript -e 'devtools::test(filter = "fixtures")'`
Expected: PASS, 0 failures

- [ ] **Step 4: Write the failing extractor tests**

Create `tests/testthat/test-gg_boost_trajectory.R`:

```r
test_that("gg_boost_trajectory returns the documented column contract", {
  gg <- gg_boost_trajectory(boost_fixture())

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

test_that("one row per observation, not per subject", {
  fit <- boost_fixture()
  gg <- gg_boost_trajectory(fit)

  expect_identical(nrow(gg), sum(lengths(fit$time)))
  expect_identical(nlevels(gg$id), length(fit$id.unique))
})

test_that("rows are sorted by time within each subject", {
  gg <- gg_boost_trajectory(boost_fixture())

  by_subject <- split(gg$time, gg$id)
  expect_false(any(vapply(by_subject, is.unsorted, logical(1))))
})

test_that("subject identifiers come from id.unique", {
  fit <- boost_fixture()
  gg <- gg_boost_trajectory(fit)

  expect_identical(levels(gg$id), as.character(fit$id.unique))
})

test_that("fitted and observed keep their pairing through the sort", {
  fit <- boost_fixture()
  gg <- gg_boost_trajectory(fit)

  # Subject 1 in the fixture has unsorted times, so a sort that moved one
  # column without the others would break this.
  first <- fit$id.unique[1]
  ord <- order(fit$time[[1]])
  rows <- gg[gg$id == as.character(first), ]

  expect_equal(rows$time, fit$time[[1]][ord])
  expect_equal(rows$fitted, fit$mu[[1]][ord])
  expect_equal(rows$observed, fit$y.org[[1]][ord])
})

test_that("a univariate fit is labelled y", {
  gg <- gg_boost_trajectory(boost_fixture())

  expect_identical(levels(gg$response), "y")
})

test_that("a multi-response object yields one block per response", {
  gg <- gg_boost_trajectory(boost_multi_fixture())

  expect_identical(levels(gg$response), c("lo", "hi"))
  expect_identical(nrow(gg), 10L)
  expect_identical(as.integer(table(gg$response)), c(5L, 5L))
})

test_that("observed is NA when the fit records no observed values", {
  fit <- boost_fixture()
  fit$y.org <- NULL
  gg <- gg_boost_trajectory(fit)

  expect_true(all(is.na(gg$observed)))
  expect_false(any(is.na(gg$fitted)))
})

test_that("gg_boost_trajectory errors when the fit records no fitted values", {
  fit <- boost_fixture()
  fit$mu <- NULL

  expect_error(gg_boost_trajectory(fit), "fitted values")
})

test_that("gg_boost_trajectory fails loud on a subject-count mismatch", {
  fit <- boost_fixture()
  fit$time <- fit$time[1:5]

  expect_error(gg_boost_trajectory(fit), "5")
})

test_that("gg_boost_trajectory rejects a non-boostmtree object", {
  expect_error(gg_boost_trajectory(data.frame(x = 1)), "gg_boost_trajectory")
})
```

- [ ] **Step 5: Run to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "gg_boost_trajectory")'`
Expected: FAIL — `could not find function "gg_boost_trajectory"`

- [ ] **Step 6: Write the extractor**

Create `R/gg_boost_trajectory.R`:

```r
#' Subject trajectory data object
#'
#' Extract observed and fitted longitudinal trajectories from a boosted
#' multivariate tree fit, one row per observation.
#'
#' @details
#' This is the figure longitudinal boosting exists for: whether the model
#' tracks individual subjects over time, rather than only fitting the
#' population mean.
#'
#' `boostmtree` stores `time`, `mu` and `y.org` as parallel lists of
#' per-subject vectors, in the order observations were supplied rather than in
#' time order. Rows here are sorted by subject and then by time, so a line
#' drawn through them follows the trajectory instead of zigzagging. Subject
#' identifiers come from the fit's own `id.unique`, not from a positional
#' index.
#'
#' `observed` is `NA` throughout when the fit carries no observed response,
#' which happens for a prediction on new data.
#'
#' @param object A fitted \code{\link[boostmtree]{boostmtree}} object.
#' @param ... Not used; present for S3 consistency.
#'
#' @return A `gg_boost_trajectory` `data.frame` with columns:
#'   \describe{
#'     \item{id}{Factor subject identifier, taken from `id.unique`.}
#'     \item{time}{Numeric observation time, ascending within subject.}
#'     \item{fitted}{Numeric fitted value.}
#'     \item{observed}{Numeric observed value, or `NA`.}
#'     \item{response}{Factor naming the response.}
#'   }
#'
#' @seealso \code{\link{plot.gg_boost_trajectory}}, \code{\link{gg_boost_error}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' fit <- boostmtree::boostmtree(
#'   x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, cv.flag = TRUE, verbose = FALSE
#' )
#' plot(gg_boost_trajectory(fit))
#' }
#'
#' @export
gg_boost_trajectory <- function(object, ...) {
  UseMethod("gg_boost_trajectory", object)
}

# Only reached for objects that are not boostmtree fits; see gg_boost_error.
#' @export
gg_boost_trajectory.default <- function(object, ...) {
  .boost_check_grow(object, "gg_boost_trajectory")
}

#' @export
gg_boost_trajectory.boostmtree <- function(object, ...) {
  .boost_check_grow(object, "gg_boost_trajectory")

  if (is.null(object$mu)) {
    stop(
      "gg_boost_trajectory: this fit records no fitted values (mu).",
      call. = FALSE
    )
  }
  if (is.null(object$time)) {
    stop(
      "gg_boost_trajectory: this fit records no observation times.",
      call. = FALSE
    )
  }

  n_q <- object$n.q %||% 1L
  labels <- .boost_response_labels(object)

  ids <- object$id.unique
  if (is.null(ids)) {
    stop(
      "gg_boost_trajectory: this fit records no subject identifiers ",
      "(id.unique).",
      call. = FALSE
    )
  }
  n_subject <- length(object$time)
  if (length(ids) != n_subject) {
    stop(
      "gg_boost_trajectory: the fit records ", length(ids),
      " subject identifier(s) but ", n_subject, " time vector(s).",
      call. = FALSE
    )
  }

  # A single response stores mu as a flat list of per-subject vectors;
  # several responses nest that list one level deeper, per response.
  as_q_list <- function(x) {
    if (is.null(x)) {
      return(NULL)
    }
    if (n_q == 1L && length(x) > 0L && !is.list(x[[1]])) {
      return(list(x))
    }
    x
  }
  mu <- as_q_list(object$mu)
  y_org <- as_q_list(object$y.org)

  id_levels <- as.character(ids)

  blocks <- lapply(seq_len(n_q), function(q) {
    mu_q <- mu[[q]]
    y_q <- if (is.null(y_org)) NULL else y_org[[q]]

    per_subject <- lapply(seq_len(n_subject), function(i) {
      tm <- as.numeric(object$time[[i]])
      fitted <- as.numeric(mu_q[[i]])
      if (length(fitted) != length(tm)) {
        stop(
          "gg_boost_trajectory: subject ", id_levels[i], " has ", length(tm),
          " time(s) but ", length(fitted), " fitted value(s).",
          call. = FALSE
        )
      }
      observed <- if (is.null(y_q)) {
        rep(NA_real_, length(tm))
      } else {
        as.numeric(y_q[[i]])
      }

      # Sorting is not cosmetic: boostmtree stores observations in input
      # order, and every subject in the reference fixture is out of order.
      ord <- order(tm)
      data.frame(
        id = factor(id_levels[i], levels = id_levels),
        time = tm[ord],
        fitted = fitted[ord],
        observed = observed[ord],
        response = factor(labels[q], levels = labels),
        stringsAsFactors = FALSE
      )
    })

    do.call(rbind, per_subject)
  })

  gg_dta <- do.call(rbind, blocks)
  rownames(gg_dta) <- NULL
  class(gg_dta) <- c("gg_boost_trajectory", class(gg_dta))
  gg_dta
}
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `Rscript -e 'devtools::test(filter = "gg_boost_trajectory")'`
Expected: PASS, 0 failures

- [ ] **Step 8: Run the full suite and lint**

```bash
Rscript -e 'devtools::test()'
Rscript -e 'roxygen2::roxygenise("."); pkgload::load_all("."); print(lintr::lint_package())'
```

Expected: 0 failures, 0 skips; no lints.

- [ ] **Step 9: Commit**

```bash
git add R/gg_boost_trajectory.R tests/ NAMESPACE man/
git commit -m "feat: add gg_boost_trajectory extractor"
```

---

### Task 2: `gg_boost_trajectory` renderer

**Files:**
- Create: `R/plot.gg_boost_trajectory.R`
- Create: `tests/testthat/test-plot-gg_boost_trajectory.R`

**Interfaces:**
- Consumes: `gg_boost_trajectory()`.
- Produces: `autoplot.gg_boost_trajectory(object, subset = NULL, n_max = 100, observed = TRUE, alpha = NULL, ...)` returning a `ggplot`; `plot.gg_boost_trajectory(x, ...)` aliasing it.

Design decisions already settled — implement them, do not revisit:

- The extractor returns **every** subject. Thinning happens here, so the tidy frame always represents the whole fit.
- Both fitted and observed show by default: fitted as lines, observed as points. That is the figure that answers "does the model track these subjects".
- **Alpha carries the distributional feel.** With many overlapping subjects, partial transparency turns a spaghetti tangle into a density. `alpha = NULL` computes one from the number of subjects drawn.

- [ ] **Step 1: Write the failing tests**

Create `tests/testthat/test-plot-gg_boost_trajectory.R`:

```r
test_that("autoplot returns a ggplot", {
  p <- ggplot2::autoplot(gg_boost_trajectory(boost_fixture()))

  expect_s3_class(p, "ggplot")
})

test_that("plot is an alias for autoplot", {
  gg <- gg_boost_trajectory(boost_fixture())

  b1 <- ggplot2::ggplot_build(plot(gg))
  b2 <- ggplot2::ggplot_build(ggplot2::autoplot(gg))

  # Compare BUILT plots, not the ggplot objects. aes() quosures capture
  # S3-dispatch bookkeeping (.Generic, .Method, ...) from the calling frame,
  # so two identical plots differ as objects when one reaches the renderer
  # through dispatch and the other does not.
  expect_equal(b1$data, b2$data)
  expect_equal(b1$layout$layout, b2$layout$layout)
})

test_that("the renderer rejects a foreign object", {
  expect_error(plot.gg_boost_trajectory(data.frame(x = 1)), "gg_boost_trajectory")
})

test_that("axis labels name time and the response", {
  p <- ggplot2::autoplot(gg_boost_trajectory(boost_fixture()))

  expect_identical(p$labels$x, "Time")
  expect_identical(p$labels$y, "Response")
})

test_that("fitted lines and observed points are both drawn by default", {
  p <- ggplot2::autoplot(gg_boost_trajectory(boost_fixture()))

  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_true("GeomLine" %in% geoms)
  expect_true("GeomPoint" %in% geoms)
})

test_that("observed = FALSE drops the point layer", {
  p <- ggplot2::autoplot(
    gg_boost_trajectory(boost_fixture()), observed = FALSE
  )

  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_false("GeomPoint" %in% geoms)
})

test_that("subset keeps only the named subjects", {
  gg <- gg_boost_trajectory(boost_fixture())
  keep <- levels(gg$id)[1:3]
  p <- ggplot2::autoplot(gg, subset = keep)

  expect_setequal(as.character(unique(p$data$id)), keep)
})

test_that("subset errors on an identifier the data does not contain", {
  gg <- gg_boost_trajectory(boost_fixture())

  expect_error(ggplot2::autoplot(gg, subset = "not-a-subject"), "not-a-subject")
})

test_that("n_max thins the cohort and says so", {
  gg <- gg_boost_trajectory(boost_fixture())

  expect_message(
    p <- ggplot2::autoplot(gg, n_max = 5),
    "5 of 25"
  )
  expect_length(unique(as.character(p$data$id)), 5L)
})

test_that("n_max = Inf draws every subject without a message", {
  gg <- gg_boost_trajectory(boost_fixture())

  expect_no_message(p <- ggplot2::autoplot(gg, n_max = Inf))
  expect_length(unique(as.character(p$data$id)), 25L)
})

test_that("alpha falls as the cohort grows", {
  # The default alpha exists to turn overplotting into a density read, so it
  # must actually respond to how many subjects are drawn.
  few <- .boost_trajectory_alpha(5L)
  many <- .boost_trajectory_alpha(500L)

  expect_gt(few, many)
  expect_lte(few, 1)
  expect_gt(many, 0)
})

test_that("an explicit alpha overrides the computed one", {
  gg <- gg_boost_trajectory(boost_fixture())
  p <- ggplot2::autoplot(gg, alpha = 0.42)

  line <- p$layers[[which(vapply(
    p$layers, function(l) class(l$geom)[1], character(1)
  ) == "GeomLine")[1]]]
  expect_equal(line$aes_params$alpha, 0.42)
})

test_that("the trajectory plot is stable", {
  skip_on_cran()
  # Text rendering is not byte-identical across platforms, and the committed
  # reference SVGs were generated on macOS.
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "trajectory univariate",
    ggplot2::autoplot(gg_boost_trajectory(boost_fixture()), n_max = Inf)
  )
})

test_that("the multi-response trajectory plot is stable", {
  skip_on_cran()
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "trajectory multi response",
    ggplot2::autoplot(gg_boost_trajectory(boost_multi_fixture()))
  )
})
```

- [ ] **Step 2: Run to verify they fail**

Run: `Rscript -e 'devtools::test(filter = "plot-gg_boost_trajectory")'`
Expected: FAIL — no applicable method for `autoplot`

- [ ] **Step 3: Write the renderer**

Create `R/plot.gg_boost_trajectory.R`:

```r
#' Plot a \code{\link{gg_boost_trajectory}} object
#'
#' Observed and fitted subject trajectories over time: one line per subject
#' through the fitted values, with the observed values as points.
#'
#' @details
#' The extractor returns every subject, so thinning happens here and the tidy
#' data frame always represents the whole fit. `subset` names the subjects to
#' keep; `n_max` caps how many are drawn, sampling at random and saying so.
#' Set `n_max = Inf` to draw all of them. Random sampling is not seeded — call
#' `set.seed()` first for a reproducible figure.
#'
#' Transparency is doing real work in this figure rather than decorating it.
#' A cohort of any size overplots, and partial transparency turns the tangle
#' into something you can read densities off: where many subjects follow the
#' same path the ink accumulates. The default `alpha` therefore falls as the
#' number of subjects drawn rises. Pass `alpha` explicitly to override.
#'
#' The returned plot carries no theme.
#'
#' @param object A \code{\link{gg_boost_trajectory}} object.
#' @param x A \code{\link{gg_boost_trajectory}} object.
#' @param subset Character or numeric vector of subject identifiers to keep.
#'   `NULL` (default) keeps all of them.
#' @param n_max Maximum number of subjects to draw. Defaults to 100; `Inf`
#'   draws every subject.
#' @param observed Logical. Draw the observed values as points. Defaults to
#'   `TRUE`, and is ignored when the fit records no observed values.
#' @param alpha Numeric transparency for both layers. `NULL` (default)
#'   computes one from the number of subjects drawn.
#' @param ... Passed to \code{\link[ggplot2]{geom_line}}.
#'
#' @return A `ggplot` object.
#'
#' @seealso \code{\link{gg_boost_trajectory}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' fit <- boostmtree::boostmtree(
#'   x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, cv.flag = TRUE, verbose = FALSE
#' )
#' plot(gg_boost_trajectory(fit))
#' }
#'
#' @importFrom ggplot2 autoplot ggplot aes geom_line geom_point facet_wrap labs
#' @export
autoplot.gg_boost_trajectory <- function(object,
                                         subset = NULL,
                                         n_max = 100,
                                         observed = TRUE,
                                         alpha = NULL,
                                         ...) {
  if (!inherits(object, "gg_boost_trajectory")) {
    stop("Incorrect object type: expected a gg_boost_trajectory object.",
         call. = FALSE)
  }

  if (!is.null(subset)) {
    wanted <- as.character(subset)
    missing_ids <- setdiff(wanted, levels(object$id))
    if (length(missing_ids) > 0L) {
      stop(
        "autoplot.gg_boost_trajectory: no such subject(s): ",
        paste(missing_ids, collapse = ", "), ".",
        call. = FALSE
      )
    }
    object <- object[as.character(object$id) %in% wanted, , drop = FALSE]
    object$id <- factor(as.character(object$id), levels = wanted)
  }

  drawn <- levels(droplevels(object$id))
  if (is.finite(n_max) && length(drawn) > n_max) {
    message(
      "Drawing ", n_max, " of ", length(drawn),
      " subjects. Pass n_max = Inf to draw all, or subset to choose."
    )
    keep <- sample(drawn, n_max)
    object <- object[as.character(object$id) %in% keep, , drop = FALSE]
    object$id <- factor(as.character(object$id), levels = keep)
    drawn <- keep
  }

  if (is.null(alpha)) {
    alpha <- .boost_trajectory_alpha(length(drawn))
  }

  gg_plt <- ggplot2::ggplot(
    object,
    ggplot2::aes(x = .data[["time"]], y = .data[["fitted"]])
  ) +
    ggplot2::geom_line(
      ggplot2::aes(group = .data[["id"]]),
      alpha = alpha,
      ...
    ) +
    ggplot2::labs(x = "Time", y = "Response")

  # A predict object carries no observed values; drawing an all-NA point
  # layer would emit a removed-rows warning and show nothing.
  if (isTRUE(observed) && any(!is.na(object$observed))) {
    gg_plt <- gg_plt +
      ggplot2::geom_point(
        ggplot2::aes(y = .data[["observed"]]),
        alpha = alpha,
        na.rm = TRUE
      )
  }

  if (nlevels(object$response) > 1L) {
    gg_plt <- gg_plt +
      ggplot2::facet_wrap(~ response, scales = "free_y")
  }

  gg_plt
}

#' @rdname autoplot.gg_boost_trajectory
#' @export
plot.gg_boost_trajectory <- function(x,
                                     subset = NULL,
                                     n_max = 100,
                                     observed = TRUE,
                                     alpha = NULL,
                                     ...) {
  autoplot.gg_boost_trajectory(
    x, subset = subset, n_max = n_max, observed = observed, alpha = alpha, ...
  )
}

# Transparency as a density read: with many subjects on one panel the lines
# overlap, and the accumulated ink is the signal. Falls from 0.9 for a handful
# of subjects toward a floor of 0.1 for a large cohort, so a spaghetti plot
# stays legible without the caller tuning it.
.boost_trajectory_alpha <- function(n) {
  if (n <= 0L) {
    return(0.9)
  }
  max(0.1, min(0.9, 12 / n))
}
```

- [ ] **Step 4: Run the tests**

Run: `Rscript -e 'devtools::test(filter = "plot-gg_boost_trajectory")'`
Expected: the non-snapshot assertions pass; the two `vdiffr` cases report new snapshots.

- [ ] **Step 5: Inspect the snapshots before accepting**

You cannot view images. Read the generated SVGs under `tests/testthat/_snaps/` and confirm structurally: the univariate figure has 25 separate polylines plus a scatter of points, with stroke-opacity below 1; the multi-response figure has two facet panels with strip labels `lo` and `hi`. Report what you checked. If a snapshot is empty or wrong, STOP and report rather than accepting it.

```bash
Rscript -e 'testthat::snapshot_accept()'
```

- [ ] **Step 6: Re-run, run the full suite, and lint**

```bash
Rscript -e 'devtools::test()'
Rscript -e 'roxygen2::roxygenise("."); pkgload::load_all("."); print(lintr::lint_package())'
```

Expected: 0 failures, 0 skips; no lints.

- [ ] **Step 7: Commit**

```bash
git add R/ tests/ NAMESPACE man/
git commit -m "feat: add gg_boost_trajectory renderer"
```

---

### Task 3: Documentation, version, and a clean check

**Files:**
- Modify: `README.md`
- Modify: `NEWS.md`
- Modify: `DESCRIPTION`
- Modify: `_pkgdown.yml`

- [ ] **Step 1: Bump the patch version**

`DESCRIPTION` to `Version: 0.0.3`; `NEWS.md` line 2 to `Version: 0.0.3`. Add above the 0.0.2 section:

```markdown
# ggBoostedTrees 0.0.3

* `gg_boost_trajectory()` and `plot()`/`autoplot()` for observed and fitted
  subject trajectories over time. Rows are sorted within subject, because
  `boostmtree` stores observations in input order and a line drawn from that
  order zigzags.
* The trajectory renderer thins large cohorts with `subset` and `n_max`, and
  scales transparency to the number of subjects drawn so that an overplotted
  cohort reads as a density.
```

- [ ] **Step 2: Add the figure to the README**

In the "Status" table, change the trajectory row from `Not yet` to `Implemented`.

In the "Figure data" table add:

```markdown
| `gg_boost_trajectory()` | Observed and fitted subject trajectories over time, sorted within subject. |
```

In the "Rendering" table add:

```markdown
| `autoplot.gg_boost_trajectory()` | Fitted trajectories as lines and observed values as points, thinned by `subset`/`n_max` with transparency scaled to cohort size. |
```

After the parameter-path example in Quick Start, add:

```markdown
The trajectory plot is the one longitudinal boosting exists for — whether the
model tracks individual subjects, not just the population mean:

```r
autoplot(gg_boost_trajectory(fit))
```
```

- [ ] **Step 3: Add the new topics to `_pkgdown.yml`**

The reference index has two sections. Add one line to each `contents:` list,
after the existing entries:

Under `- title: "1. Extract — pull a data frame out of a fit"`:

```yaml
  - gg_boost_trajectory
```

Under `- title: "2. Render — draw the extracted object"`:

```yaml
  - autoplot.gg_boost_trajectory
```

- [ ] **Step 4: Verify pkgdown covers every topic**

```bash
Rscript -e 'roxygen2::roxygenise("."); pkgdown::check_pkgdown()'
```

Expected: no error. `check_pkgdown()` fails when a documented topic is missing from the reference index, which is exactly the drift this step exists to catch.

- [ ] **Step 5: Run the full suite and lint**

```bash
Rscript -e 'devtools::test()'
Rscript -e 'pkgload::load_all("."); print(lintr::lint_package())'
```

Expected: 0 failures, 0 skips; no lints.

- [ ] **Step 6: Run R CMD check from a clean export**

Commit first so `git archive HEAD` sees the changes.

```bash
TMP=$(mktemp -d) && git archive --format=tar HEAD | tar -x -C "$TMP" && \
  R CMD build "$TMP" && \
  _R_CHECK_FORCE_SUGGESTS_=false R CMD check --as-cran ggBoostedTrees_0.0.3.tar.gz
```

Expected: 0 errors, 0 warnings, exactly one NOTE — the `Remotes:` field note, which is removed at the phase-5 release gate. Report every note and warning verbatim. Any other note fails this step.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "docs: document gg_boost_trajectory, bump to 0.0.3"
```

---

## Definition of done

- `gg_boost_trajectory()` returns the documented contract for single- and multi-response fits, sorted within subject, with identifiers from `id.unique`.
- It tolerates an absent `y.org` and fails loudly on a subject-count or length mismatch.
- `autoplot()`/`plot()` draw fitted lines and observed points, honour `subset`, `n_max`, `observed` and `alpha`, and scale transparency to cohort size.
- README, NEWS, and the pkgdown reference index all list the new figure.
- `R CMD check --as-cran` is clean apart from the expected `Remotes:` note.
