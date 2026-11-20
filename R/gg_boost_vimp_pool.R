#' Pooled variable importance over several runs
#'
#' Pool several \code{\link[boostmtree]{vimp.boostmtree}} runs and report, for
#' each covariate and panel, the share of runs in which it cleared that run's
#' shadow band.
#'
#' @details
#' One importance object is one run, and a covariate close to the shadow band
#' can land on either side of it from one run to the next. Pass a list of runs
#' to see how often it clears the band. The runs can be repeated calls to
#' \code{\link[boostmtree]{vimp.boostmtree}} on one fit, one call on each of
#' several refits, or a mix. Refitting moves a borderline verdict as much as
#' rerunning the importance does, so refits are the stronger check.
#'
#' Every run is judged against its own band, never against a pooled one. In
#' each run and panel, the band is the largest importance any shadow covariate
#' reached, floored at zero, as in the single-run figure. The `margin` is a
#' covariate's importance minus that band, and the covariate cleared the band
#' in that run when its margin is above zero. The `share` is the fraction of
#' runs in which it did. No verdict is drawn from the share: it measures how
#' stable a single-run verdict is, not a test with a known error rate.
#'
#' Every run must carry shadow covariates (see \code{\link{boost_shadow}}),
#' since a run without them has no band, and every run must name the same
#' covariates, components, responses and metric as the first. Either problem
#' stops with an error naming the run. Only `boostmtree` runs can be pooled.
#'
#' Runs are labelled by the names of the list, or numbered when it has none.
#'
#' @param object A list of \code{\link[boostmtree]{vimp.boostmtree}} objects,
#'   each from a fit with shadow covariates.
#' @param components Character vector naming the components to extract, any of
#'   `"main"` and `"interaction"`. Defaults to both.
#' @param ... Not used; present for S3 consistency.
#'
#' @return A `gg_boost_vimp_pool` `data.frame` with one row per covariate,
#'   component and response (shadows excluded) and columns:
#'   \describe{
#'     \item{variable}{Factor covariate name.}
#'     \item{component}{Factor, `main` or `interaction`.}
#'     \item{response}{Factor naming the response.}
#'     \item{n_runs}{Integer number of runs pooled.}
#'     \item{n_detected}{Integer number of runs in which the covariate
#'       cleared that run's shadow band.}
#'     \item{share}{`n_detected / n_runs`.}
#'     \item{median_importance}{Median importance over runs.}
#'     \item{q15, q25, q50, q75, q85}{Percentiles of the margin over the band
#'       across runs.}
#'   }
#'   with attributes `runs` (a `data.frame` with one row per run and covariate:
#'   `variable`, `component`, `response`, `run`, `importance`, `band`,
#'   `margin` and `detected`), `metric`, `n_runs`, and `time.effect` (the
#'   median overall time effect over runs, when every run records one).
#'
#' @seealso \code{\link{gg_boost_vimp}}, \code{\link{plot.gg_boost_vimp_pool}},
#'   \code{\link{boost_shadow}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' x <- boost_shadow(sim$features, sim$id, k = 2)
#' fit <- boostmtree::boostmtree(
#'   x = x, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, cv.flag = TRUE, verbose = FALSE
#' )
#' runs <- lapply(1:3, function(i) boostmtree::vimp.boostmtree(fit))
#' pooled <- gg_boost_vimp(runs)
#' pooled[, c("variable", "component", "share")]
#' plot(pooled)
#' }
#'
#' @name gg_boost_vimp_pool
#' @export
gg_boost_vimp.list <- function(object,
                               components = c("main", "interaction"),
                               ...) {
  labels <- .vimp_pool_labels(object)

  extracts <- lapply(seq_along(object), function(i) {
    v <- object[[i]]
    if (!inherits(v, "vimp.boostmtree")) {
      stop(
        "gg_boost_vimp: run ", sQuote(labels[i]), " is an object of class ",
        paste(class(v), collapse = "/"), "; only 'vimp.boostmtree' runs ",
        "can be pooled.",
        call. = FALSE
      )
    }
    gg <- gg_boost_vimp(v, components = components)
    if (!any(gg$shadow)) {
      stop(
        "gg_boost_vimp: run ", sQuote(labels[i]), " has no shadow ",
        "covariates, so it has no band to be judged against. Fit with ",
        "boost_shadow() covariates.",
        call. = FALSE
      )
    }
    gg
  })
  .vimp_pool_check_alike(extracts, labels)

  runs <- do.call(rbind, lapply(seq_along(extracts), function(i) {
    gg <- extracts[[i]]
    # The single-run band rule, from plot.gg_boost_vimp.R; lintr checks one
    # file at a time and cannot see it.
    bands <- .vimp_shadow_thresholds( # nolint: object_usage_linter.
      gg[gg$shadow, , drop = FALSE]
    )
    real <- gg[!gg$shadow, , drop = FALSE]
    band <- bands$band[match(paste(real$component, real$response),
                             paste(bands$component, bands$response))]
    margin <- real$importance - band
    data.frame(
      variable = droplevels(real$variable),
      component = real$component,
      response = real$response,
      run = factor(labels[i], levels = labels),
      importance = real$importance,
      band = band,
      margin = margin,
      detected = !is.na(margin) & margin > 0,
      stringsAsFactors = FALSE
    )
  }))
  rownames(runs) <- NULL

  key <- paste(runs$variable, runs$component, runs$response, sep = "\r")
  cells <- unique(runs[c("variable", "component", "response")])
  probs <- c(q15 = 0.15, q25 = 0.25, q50 = 0.50, q75 = 0.75, q85 = 0.85)
  stats <- do.call(rbind, lapply(
    paste(cells$variable, cells$component, cells$response, sep = "\r"),
    function(k) {
      cell <- runs[key == k, , drop = FALSE]
      q <- stats::quantile(cell$margin, probs, names = FALSE, na.rm = TRUE)
      out <- data.frame(
        n_runs = nrow(cell),
        n_detected = sum(cell$detected),
        share = sum(cell$detected) / nrow(cell),
        median_importance = stats::median(cell$importance, na.rm = TRUE)
      )
      out[names(probs)] <- as.list(q)
      out
    }
  ))

  gg_dta <- cbind(cells, stats)
  rownames(gg_dta) <- NULL
  class(gg_dta) <- c("gg_boost_vimp_pool", "data.frame")
  attr(gg_dta, "runs") <- runs
  attr(gg_dta, "metric") <- attr(extracts[[1L]], "metric")
  attr(gg_dta, "n_runs") <- length(extracts)
  attr(gg_dta, "time.effect") <- .vimp_pool_time_effect(extracts)
  gg_dta
}

# Run labels: the list's names, or 1..N when it has none. Partial, empty or
# repeated names would make two runs indistinguishable, so they stop.
.vimp_pool_labels <- function(object) {
  if (length(object) == 0L) {
    stop("gg_boost_vimp: the list of runs is empty.", call. = FALSE)
  }
  labels <- names(object)
  if (is.null(labels)) {
    return(as.character(seq_along(object)))
  }
  if (anyNA(labels) || any(!nzchar(labels)) || anyDuplicated(labels)) {
    stop(
      "gg_boost_vimp: name every run in the list, uniquely, or none of them.",
      call. = FALSE
    )
  }
  labels
}

# Pooling compares a covariate with itself across runs, so every run must
# describe the same panels with the same covariates as the first.
.vimp_pool_check_alike <- function(extracts, labels) {
  ref <- extracts[[1L]]
  describe <- function(gg) {
    list(
      covariates = levels(gg$variable),
      components = levels(gg$component),
      responses = levels(gg$response),
      metric = attr(gg, "metric") %||% NA_character_
    )
  }
  want <- describe(ref)
  for (i in seq_along(extracts)[-1L]) {
    got <- describe(extracts[[i]])
    differs <- names(want)[!mapply(identical, want, got)]
    if (length(differs) > 0L) {
      stop(
        "gg_boost_vimp: run ", sQuote(labels[i]), " differs from run ",
        sQuote(labels[1L]), " in its ", paste(differs, collapse = ", "),
        "; pooled runs must come from fits on the same covariates.",
        call. = FALSE
      )
    }
  }
  invisible(TRUE)
}

# The overall time effect, as the median over runs for each response, when
# every run records one of the same length.
.vimp_pool_time_effect <- function(extracts) {
  te <- lapply(extracts, attr, "time.effect")
  lens <- lengths(te)
  if (any(lens == 0L) || length(unique(lens)) != 1L) {
    return(NULL)
  }
  stats::setNames(
    apply(matrix(unlist(te), nrow = lens[1L]), 1L, stats::median),
    names(te[[1L]])
  )
}
