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
