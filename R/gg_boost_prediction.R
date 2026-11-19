#' Fixed-time prediction data object
#'
#' Predict each subject's response at one time point from a fitted
#' \code{\link[boostmtree]{boostmtree}} model, alongside that subject's
#' covariates, so the prediction can be plotted against any one of them.
#'
#' @details
#' This answers a question the other figures do not: "what does the model
#' predict for these patients at ten years, and how does that vary with age?"
#' A partial effect (\code{\link{gg_boost_effect}}) holds every other covariate
#' at a reference and varies one; this figure keeps each subject's own
#' covariates, so the scatter shows the spread the other covariates produce
#' around the trend in the one being plotted.
#'
#' Predictions come from \code{\link[boostmtree]{predict.boostmtree}} at the
#' cross-validated number of iterations `m.opt` (or the fitted `M` when the fit
#' records none). They are in-sample predictions: each subject's own data
#' helped fit the trees. That is not the same quantity as the `mu` stored on
#' the fit, which \code{\link{gg_boost_trajectory}} plots and which is
#' out-of-bag. A subject's dot here will generally sit closer to its observed
#' trajectory than the fitted curve in that figure.
#'
#' `time` must lie within the observed follow-up. `boostmtree` builds its
#' time effect from a B-spline basis, and a prediction beyond the last
#' observation is an extrapolation of that basis rather than a model
#' estimate, so it is refused rather than returned.
#'
#' Only single-response fits are supported. `BoostMLR` fits are refused: this
#' figure has not been implemented for that backend.
#'
#' @param object A fitted \code{\link[boostmtree]{boostmtree}} object.
#' @param time A single time, on the scale of the fitted `tm`, at which to
#'   predict every subject.
#' @param ... Not used; present for S3 consistency.
#'
#' @return A `gg_boost_prediction` `data.frame` with one row per subject and
#'   columns:
#'   \describe{
#'     \item{id}{Factor subject index.}
#'     \item{predicted}{Numeric predicted response at `time`.}
#'   }
#'   followed by one column per covariate, as stored on the fit. Attributes:
#'   `time` (the prediction time) and `m` (the iterations used).
#'
#' @seealso \code{\link{plot.gg_boost_prediction}},
#'   \code{\link{gg_boost_effect}}, \code{\link{gg_boost_trajectory}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' fit <- boostmtree::boostmtree(
#'   x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, cv.flag = TRUE, verbose = FALSE
#' )
#' gg <- gg_boost_prediction(fit, time = 1)
#' plot(gg, covariate = "x1")
#' }
#'
#' @export
gg_boost_prediction <- function(object, time, ...) {
  UseMethod("gg_boost_prediction", object)
}

# Only reached for objects that are not boostmtree fits; see gg_boost_error.
#' @export
gg_boost_prediction.default <- function(object, time, ...) {
  .boost_check_grow(object, "gg_boost_prediction")
}

#' @export
gg_boost_prediction.BoostMLR <- function(object, time, ...) {
  stop(
    "gg_boost_prediction: BoostMLR fits are not supported; this figure is ",
    "implemented for boostmtree only.",
    call. = FALSE
  )
}

#' @export
gg_boost_prediction.boostmtree <- function(object, time, ...) {
  .boost_check_grow(object, "gg_boost_prediction")

  if (!is.numeric(time) || length(time) != 1L || !is.finite(time)) {
    stop("gg_boost_prediction: 'time' must be a single finite number.",
         call. = FALSE)
  }
  if ((object$n.q %||% 1L) > 1L) {
    stop(
      "gg_boost_prediction: multi-response fits (family = '",
      object$family, "') are not supported.",
      call. = FALSE
    )
  }
  x <- object$x
  observed <- unlist(object$time)
  if (is.null(x) || length(observed) == 0L) {
    stop(
      "gg_boost_prediction: this fit records no covariates or no times.",
      call. = FALSE
    )
  }
  follow_up <- range(observed)
  if (time < follow_up[1] || time > follow_up[2]) {
    stop(
      "gg_boost_prediction: 'time' = ", time, " lies outside the observed ",
      "follow-up [", follow_up[1], ", ", follow_up[2], "]; ",
      "boostmtree would be extrapolating its time basis.",
      call. = FALSE
    )
  }

  clash <- intersect(names(x), c("id", "predicted"))
  if (length(clash) > 0L) {
    stop(
      "gg_boost_prediction: covariate name(s) ",
      paste(sQuote(clash), collapse = ", "), " collide with the columns ",
      "this object adds.",
      call. = FALSE
    )
  }

  m <- object$m.opt
  if (length(m) != 1L || is.na(m)) m <- object$M

  n <- nrow(x)
  # .extrapolate = FALSE: by default boostmtree also predicts every subject at
  # every distinct training time (muhat), which this extractor never reads.
  # partial.plot() turns it off for the same reason.
  pred <- stats::predict(
    object, x = x, tm = rep(time, n), id = seq_len(n), M = m,
    .extrapolate = FALSE
  )
  mu <- pred$mu
  # A two-level nominal or ordinal fit has n.q = 1 but keeps a response-level
  # wrapper around mu: one element holding every subject. Unwrap it, or the
  # first subject's prediction would be recycled into every row.
  if (length(mu) == 1L && n > 1L && is.list(mu[[1L]])) {
    mu <- mu[[1L]]
  }
  if (length(mu) != n) {
    stop(
      "gg_boost_prediction: boostmtree returned ", length(mu),
      " prediction(s) for ", n, " subject(s).",
      call. = FALSE
    )
  }
  predicted <- vapply(mu, function(v) as.numeric(v)[1L], numeric(1))

  gg_dta <- data.frame(
    id = factor(seq_len(n)),
    predicted = predicted,
    x,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  rownames(gg_dta) <- NULL
  class(gg_dta) <- c("gg_boost_prediction", class(gg_dta))
  attr(gg_dta, "time") <- time
  attr(gg_dta, "m") <- m
  gg_dta
}
