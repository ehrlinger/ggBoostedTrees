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
#' This figure also accepts a \code{BoostMLR} fit, which records only `Rho`
#' and `Phi` as M-by-response matrices -- the method's default `parameters` is
#' `c("rho", "phi")` rather than all three. `BoostMLR` has no comparable
#' `lambda`: its `Lambda_List` holds per-iteration basis coefficients rather
#' than a scalar smoothing parameter per response, a different quantity, so
#' requesting `"lambda"` from a `BoostMLR` fit is refused with that reason
#' instead of silently dropped.
#'
#' @param object A fitted \code{\link[boostmtree]{boostmtree}} object, or a
#'   fitted \code{BoostMLR} object.
#' @param parameters Character vector naming the paths to extract. For a
#'   \code{boostmtree} fit, any of `"rho"`, `"phi"`, and `"lambda"`, defaulting
#'   to all three. For a \code{BoostMLR} fit, `"rho"` and/or `"phi"` only,
#'   defaulting to both.
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
    # it as an iteration-by-response matrix. as.matrix() normalizes both, so
    # ncol(path) must equal n_q; a mismatch means the fit object is malformed.
    path <- as.matrix(object[[p]])
    if (ncol(path) != n_q) {
      stop(
        "gg_boost_path: the '", p, "' path has ", ncol(path),
        " column(s) but the fit records n.q = ", n_q, " response(s).",
        call. = FALSE
      )
    }
    do.call(rbind, lapply(seq_len(n_q), function(q) {
      value <- as.numeric(path[, q])
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
