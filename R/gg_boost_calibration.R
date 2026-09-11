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
