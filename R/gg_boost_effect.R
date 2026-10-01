#' Partial and marginal effect data object
#'
#' Extract covariate effect curves over time from a
#' \code{\link[boostmtree]{partial.plot}} or
#' \code{\link[boostmtree]{marginal.plot}} object, or from the
#' \code{\link{boostmlr_partial}} result for a `BoostMLR` fit.
#'
#' @details
#' The two differ in what they hold constant. A partial effect varies one
#' covariate while averaging over the others; a marginal effect reads the fitted
#' surface as the data actually distribute it. Both are covariate-by-time
#' surfaces, so both land in this one class, distinguished by `kind`.
#'
#' `marginal.plot()` returns a raw scatter alongside its smoothed curve.
#' That scatter is not the raw observations: it holds one unsmoothed fitted
#' prediction per subject at the subject's own observed covariate value,
#' not the observed response and not the stored fitted values. It is also
#' not reconstructable from \code{\link{gg_boost_trajectory}}, which carries
#' no covariate column. `gg_boost_effect` extracts the smoothed curve instead,
#' so that both levels of `kind` mean the same thing: the fitted effect.
#'
#' For `BoostMLR`, \code{\link{boostmlr_partial}} returns both the raw
#' partial effect and a lowess smooth of it over time; the smooth is
#' extracted, matching the `marginal` choice above. The result has `kind`
#' `partial` and one block per response, labelled from the fit's `y_Names`.
#'
#' No source computes a confidence interval, so none is reported here.
#'
#' `boostmtree` accepts factor covariates. For those, `partial.plot()` and
#' `marginal.plot()` return a character (or, for `marginal.plot()$data`,
#' factor) `x` column with one row per level rather than a numeric grid.
#' `gg_boost_effect` detects this and maps each level to an integer position
#' in `x`, carrying the level itself in `x_label`; a continuous covariate
#' keeps its numeric value in `x` and leaves `x_label` `NA`. The grid is
#' resolved once per variable so every time point shares the same level
#' ordering.
#'
#' A multi-response fit (`family = "ordinal"` or `"nominal"`) nests
#' `$curves` / `$smooth` as `[[response]][[variable]]`; a single-response fit
#' flattens the outer level. `gg_boost_effect` accepts both and records the
#' response in a `response` column, labelled from the object's
#' `$response.labels` (`"response"` for a single-response fit). Each response
#' of an ordinal or nominal fit is one model component, so its curves are on
#' that component's scale.
#'
#' @param object A `partial.plot.boostmtree` or `marginal.plot.boostmtree`
#'   object, as returned by `boostmtree::partial.plot()` or
#'   `boostmtree::marginal.plot()` with `output = "data", verbose = FALSE`,
#'   or a \code{\link{boostmlr_partial}} object.
#' @param ... Not used; present for S3 consistency.
#'
#' @return A `gg_boost_effect` `data.frame` with columns:
#'   \describe{
#'     \item{variable}{Factor covariate name.}
#'     \item{x}{Numeric covariate value. For a continuous covariate this is
#'       the covariate itself; for a discrete (factor) covariate this is an
#'       integer position, one per level.}
#'     \item{x_label}{Character level label for a discrete covariate, `NA`
#'       for a continuous one.}
#'     \item{time}{Numeric time point.}
#'     \item{estimate}{Numeric fitted effect.}
#'     \item{kind}{Factor, `partial` or `marginal`.}
#'     \item{response}{Factor naming the response.}
#'   }
#'
#' @seealso \code{\link{plot.gg_boost_effect}}, \code{\link{gg_boost_vimp}},
#'   \code{\link{boostmlr_partial}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' fit <- boostmtree::boostmtree(
#'   x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, verbose = FALSE
#' )
#' pp <- boostmtree::partial.plot(
#'   fit, x.var.names = "x1", output = "data", verbose = FALSE
#' )
#' plot(gg_boost_effect(pp))
#' }
#'
#' @export
gg_boost_effect <- function(object, ...) {
  UseMethod("gg_boost_effect", object)
}

# Only reached for objects that are neither effect type; see gg_boost_error.
#' @export
gg_boost_effect.default <- function(object, ...) {
  stop(
    "gg_boost_effect: expected a 'partial.plot.boostmtree' or ",
    "'marginal.plot.boostmtree' object, or a 'boostmlr_partial' object; ",
    "got an object of class ",
    paste(class(object), collapse = "/"),
    ". Produce one with boostmtree::partial.plot(",
    "fit, output = \"data\", verbose = FALSE).",
    call. = FALSE
  )
}

#' @export
gg_boost_effect.partial.plot.boostmtree <- function(object, ...) {
  curves <- object$curves
  if (is.null(curves) || length(curves) == 0L) {
    stop("gg_boost_effect: this object records no effect curves.",
         call. = FALSE)
  }
  by_response <- .boost_effect_responses(
    curves, object$response.labels, flat = is.data.frame(curves[[1L]])
  )
  time_points <- object$time.points

  .gg_boost_effect_frame(by_response, function(curves) {
    var_levels <- names(curves)
    lapply(var_levels, function(nm) {
      wide <- curves[[nm]]
      # Column 1 is the covariate grid; the rest are one column per time
      # point, named time.0.50 and so on. Take the times from $time.points
      # rather than parsing those labels, so precision is not lost to the
      # label's rounding.
      value_cols <- seq_len(ncol(wide))[-1]
      if (length(value_cols) != length(time_points)) {
        stop(
          "gg_boost_effect: variable '", nm, "' has ", length(value_cols),
          " curve column(s) but the object records ", length(time_points),
          " time point(s).",
          call. = FALSE
        )
      }
      grid <- .boost_effect_grid(wide[[1]])
      do.call(rbind, lapply(seq_along(value_cols), function(k) {
        data.frame(
          variable = factor(nm, levels = var_levels),
          x = grid$x,
          x_label = grid$x_label,
          time = as.numeric(time_points[k]),
          estimate = as.numeric(wide[[value_cols[k]]]),
          kind = factor("partial", levels = "partial"),
          stringsAsFactors = FALSE
        )
      }))
    })
  })
}

#' @export
gg_boost_effect.marginal.plot.boostmtree <- function(object, ...) {
  smooth <- object$smooth
  if (is.null(smooth) || length(smooth) == 0L) {
    stop("gg_boost_effect: this object records no smoothed effect curves.",
         call. = FALSE)
  }
  by_response <- .boost_effect_responses(
    smooth, object$response.labels, flat = is.data.frame(smooth[[1L]][[1L]])
  )
  time_points <- object$time.points

  .gg_boost_effect_frame(by_response, function(smooth) {
    var_levels <- names(smooth)
    lapply(var_levels, function(nm) {
      per_time <- smooth[[nm]]
      if (length(per_time) != length(time_points)) {
        stop(
          "gg_boost_effect: variable '", nm, "' has ", length(per_time),
          " smoothed curve(s) but the object records ", length(time_points),
          " time point(s).",
          call. = FALSE
        )
      }
      grid <- .boost_effect_grid(per_time[[1L]]$x)
      do.call(rbind, lapply(seq_along(per_time), function(k) {
        curve <- per_time[[k]]
        data.frame(
          variable = factor(nm, levels = var_levels),
          x = grid$x,
          x_label = grid$x_label,
          time = as.numeric(time_points[k]),
          estimate = as.numeric(curve$y),
          kind = factor("marginal", levels = "marginal"),
          stringsAsFactors = FALSE
        )
      }))
    })
  })
}

#' @export
gg_boost_effect.boostmlr_partial <- function(object, ...) {
  curves <- object$curves
  if (is.null(curves) || length(curves) == 0L) {
    stop("gg_boost_effect: this object records no effect curves.",
         call. = FALSE)
  }
  labels <- as.character(object$response.labels)
  var_levels <- names(curves)
  # partial.BoostMLR() returns one smoothed covariate-by-time matrix per
  # response; regroup them response-first to match the boostmtree methods.
  by_response <- stats::setNames(lapply(seq_along(labels), function(q) {
    lapply(curves, function(cv) {
      if (length(cv$sList) != length(labels)) {
        stop(
          "gg_boost_effect: the object names ", length(labels),
          " response(s) but records curves for ", length(cv$sList), ".",
          call. = FALSE
        )
      }
      cv$sList[[q]]
    })
  }), labels)

  .gg_boost_effect_frame(by_response, function(mats) {
    lapply(var_levels, function(nm) {
      cv <- curves[[nm]]
      mat <- mats[[nm]]
      grid <- .boost_effect_grid(cv$x.unq)
      do.call(rbind, lapply(seq_along(cv$tm.unq), function(k) {
        data.frame(
          variable = factor(nm, levels = var_levels),
          x = grid$x,
          x_label = grid$x_label,
          time = as.numeric(cv$tm.unq[k]),
          estimate = as.numeric(mat[, k]),
          kind = factor("partial", levels = "partial"),
          stringsAsFactors = FALSE
        )
      }))
    })
  })
}

# Normalise $curves / $smooth to one named list per response.
#
# boostmtree nests these as [[response]][[variable]] for a multi-response fit
# and drops the outer level for a single response. Wrapping the flat case
# gives both one shape. Labels come from $response.labels, which boostmtree
# records for both ("response" when single); the list names and then y1, y2,
# ... are fallbacks for an object that lacks it.
.boost_effect_responses <- function(nested, labels, flat) {
  if (flat) {
    nested <- list(nested)
  }
  if (is.null(labels)) {
    labels <- names(nested) %||% paste0("y", seq_along(nested))
    if (flat) labels <- "response"
  }
  labels <- as.character(labels)
  if (length(labels) != length(nested)) {
    stop(
      "gg_boost_effect: the object names ", length(labels),
      " response(s) but records curves for ", length(nested), ".",
      call. = FALSE
    )
  }
  stats::setNames(nested, labels)
}

# Resolve a covariate grid into a numeric position and an optional label.
#
# boostmtree returns a character (partial, marginal $smooth) or factor
# (marginal $data) x column for a factor predictor, with one row per level
# rather than a grid. Coercing that with as.numeric() silently produced an
# all-NA column and a blank figure, which is the defect this exists to prevent.
#
# A continuous covariate keeps its value in `x` and gets no label. A discrete
# one gets an integer position in `x` -- so the column keeps one type -- and
# its level in `x_label`, which is what the renderer puts on the axis.
.boost_effect_grid <- function(x) {
  if (is.numeric(x)) {
    return(list(x = as.numeric(x), x_label = NA_character_))
  }
  labels <- as.character(x)
  levels_seen <- unique(labels)
  list(
    x = as.numeric(match(labels, levels_seen)),
    x_label = labels
  )
}

# Shared tail of both methods: build each response's per-variable blocks,
# tag them with the response, bind, and class the result. The two methods
# differ only in how they reach a list of blocks for one response.
.gg_boost_effect_frame <- function(by_response, blocks_for) {
  labels <- names(by_response)
  gg_dta <- do.call(rbind, lapply(seq_along(by_response), function(q) {
    block <- do.call(rbind, blocks_for(by_response[[q]]))
    block$response <- factor(labels[q], levels = labels)
    block
  }))
  rownames(gg_dta) <- NULL
  class(gg_dta) <- c("gg_boost_effect", class(gg_dta))
  gg_dta
}
