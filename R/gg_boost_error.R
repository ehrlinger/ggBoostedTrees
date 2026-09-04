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
#' This figure also accepts a \code{BoostMLR} \emph{grow} fit (predict
#' objects are not supported -- see below). `BoostMLR` records `Error_Rate`
#' as an M-by-response matrix already on a single scale, so there is no
#' `use.rmse` argument for that backend; passing one is refused. `BoostMLR`
#' grow objects also select no optimal iteration anywhere in the object --
#' `partial.BoostMLR()` takes `Mopt` as a user-supplied argument instead --
#' so `optimal` is `FALSE` for every row; deriving an argmin here would
#' report a choice the backend never made.
#'
#' A `BoostMLR` \strong{predict} object is refused outright, even though it
#' shares the `"BoostMLR"` class and also carries an `Error_Rate`. Its
#' `Error_Rate` is test error rather than the training path documented above,
#' and it records a real `Mopt` that this extractor would otherwise silently
#' discard and overwrite with `optimal = FALSE`.
#'
#' @param object A fitted \code{\link[boostmtree]{boostmtree}} object, or a
#'   fitted \code{BoostMLR} object.
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
  if (length(err) != n_q) {
    stop(
      "gg_boost_error: err.rate has ", length(err),
      " element(s) but the fit records n.q = ", n_q, " response(s).",
      call. = FALSE
    )
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

#' @export
gg_boost_error.BoostMLR <- function(object, ...) {
  .boost_check_mlr_grow(object, "gg_boost_error")

  dots <- list(...)
  if ("use.rmse" %in% names(dots)) {
    stop(
      "gg_boost_error: a BoostMLR fit records no response scale (y.sd), ",
      "so its Error_Rate cannot be unstandardized; 'use.rmse' is not ",
      "supported for BoostMLR fits.",
      call. = FALSE
    )
  }

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
