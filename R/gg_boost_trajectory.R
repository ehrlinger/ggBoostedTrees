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
#' time order. Rows here are sorted by time within each subject, and the
#' assembled frame is response-major (all subjects for one response, then the
#' next), so a line drawn through one subject's rows follows the trajectory
#' instead of zigzagging. Subject identifiers come from the fit's own
#' `id.unique`, not from a positional index.
#'
#' `observed` is `NA` throughout when the fit carries no observed response,
#' which happens for a prediction on new data.
#'
#' What `fitted` holds depends on how the model was grown. With
#' `cv.flag = FALSE` it is the in-sample fit. With `cv.flag = TRUE`,
#' `boostmtree` replaces `mu` with the out-of-bag prediction at `m.opt`, the
#' same values that produce the cross-validated error, so it sits further from
#' `observed` than an in-sample fit would. A subject's out-of-bag prediction
#' moves only at iterations where that subject is out of bag. A subject never
#' out of bag by `m.opt` keeps the starting value, a constant equal to the
#' mean response of the other subjects, and the extractor warns when it finds
#' one. Before `boostmtree` 2.0.13, a fixed `control$seed` drew the same
#' subsample for every tree, which left roughly 60 percent of subjects flat.
#' Refit with 2.0.13 or later, or grow with `control$seed = NULL` after
#' `set.seed()`, which is still reproducible.
#'
#' This figure accepts either a \code{boostmtree} or a \code{BoostMLR} fit.
#' `BoostMLR` stores `mu` and `y` as flat observation-by-response matrices,
#' with `tm` and `id` as parallel flat vectors, rather than boostmtree's
#' nested per-subject lists -- entirely different layout for the same
#' information. Response labels come from `y_Names`, since `mu` carries no
#' column names. `BoostMLR` is natively multi-response, so a fit typically
#' yields several response blocks even for a "single" model.
#'
#' @param object A fitted \code{\link[boostmtree]{boostmtree}} object, or a
#'   fitted \code{BoostMLR} object.
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
#'   M = 50, verbose = FALSE
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
  if (n_subject == 0L) {
    stop(
      "gg_boost_trajectory: this fit records no subjects (time is empty).",
      call. = FALSE
    )
  }
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

  if (length(mu) != n_q) {
    stop(
      "gg_boost_trajectory: mu has ", length(mu),
      " element(s) but the fit records n.q = ", n_q, " response(s).",
      call. = FALSE
    )
  }
  if (!is.null(y_org) && length(y_org) != n_q) {
    stop(
      "gg_boost_trajectory: y.org has ", length(y_org),
      " element(s) but the fit records n.q = ", n_q, " response(s).",
      call. = FALSE
    )
  }

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
      if (!is.null(y_q) && length(observed) != length(tm)) {
        stop(
          "gg_boost_trajectory: subject ", id_levels[i], " has ", length(tm),
          " time(s) but ", length(observed), " observed value(s).",
          call. = FALSE
        )
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

  if (isTRUE(object$cv.flag)) {
    .boost_warn_flat_oob(gg_dta)
  }

  class(gg_dta) <- c("gg_boost_trajectory", class(gg_dta))
  gg_dta
}

# With cv.flag = TRUE, boostmtree stores out-of-bag predictions in mu, and a
# subject never out of bag by m.opt keeps its starting value exactly. A
# subject seen at two or more times with one fitted value throughout is that
# case. Before boostmtree 2.0.13 a fixed control$seed made it most subjects.
.boost_warn_flat_oob <- function(gg_dta) {
  key <- paste(gg_dta$response, gg_dta$id, sep = "\r")
  flat <- tapply(seq_len(nrow(gg_dta)), key, function(rows) {
    fitted <- gg_dta$fitted[rows]
    length(unique(gg_dta$time[rows])) > 1L && !anyNA(fitted) &&
      length(unique(fitted)) == 1L
  })
  flat_ids <- unique(as.character(gg_dta$id[key %in% names(flat)[flat]]))
  if (length(flat_ids) == 0L) {
    return(invisible(NULL))
  }
  warning(
    "gg_boost_trajectory: ", length(flat_ids), " of ",
    nlevels(gg_dta$id), " subject(s) have a constant fitted trajectory. ",
    "With cv.flag = TRUE, fitted values are out-of-bag predictions, and a ",
    "subject never out of bag by m.opt keeps its starting value. ",
    "boostmtree before 2.0.13 reused control$seed for every tree, which ",
    "leaves most subjects that way; refit with boostmtree 2.0.13 or later, ",
    "or with control$seed = NULL after set.seed().",
    call. = FALSE
  )
  invisible(NULL)
}

#' @export
gg_boost_trajectory.BoostMLR <- function(object, ...) {
  .boost_check_mlr_grow(object, "gg_boost_trajectory")

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
  if (!is.null(y) && !identical(dim(observed), dim(mu))) {
    stop(
      "gg_boost_trajectory: y has dimensions ",
      paste(dim(observed), collapse = " x "), " but mu has dimensions ",
      paste(dim(mu), collapse = " x "), ".",
      call. = FALSE
    )
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
