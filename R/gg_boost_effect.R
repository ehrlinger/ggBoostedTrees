#' Partial and marginal effect data object
#'
#' Extract covariate effect curves over time from a
#' \code{\link[boostmtree]{partial.plot}} or
#' \code{\link[boostmtree]{marginal.plot}} object.
#'
#' @details
#' The two differ in what they hold constant. A partial effect varies one
#' covariate while averaging over the others; a marginal effect reads the fitted
#' surface as the data actually distribute it. Both are covariate-by-time
#' surfaces, so both land in this one class, distinguished by `kind`.
#'
#' `marginal.plot()` returns a raw scatter alongside its smoothed curve. The
#' smoothed curve is what is extracted, so that both levels of `kind` mean the
#' same thing: the fitted effect. The raw observations are available through
#' \code{\link{gg_boost_trajectory}}.
#'
#' Neither source computes a confidence interval, so none is reported here.
#'
#' @param object A `partial.plot.boostmtree` or `marginal.plot.boostmtree`
#'   object, as returned by `boostmtree::partial.plot()` or
#'   `boostmtree::marginal.plot()` with `output = "data", verbose = FALSE`.
#' @param ... Not used; present for S3 consistency.
#'
#' @return A `gg_boost_effect` `data.frame` with columns:
#'   \describe{
#'     \item{variable}{Factor covariate name.}
#'     \item{x}{Numeric covariate value.}
#'     \item{time}{Numeric time point.}
#'     \item{estimate}{Numeric fitted effect.}
#'     \item{kind}{Factor, `partial` or `marginal`.}
#'   }
#'
#' @seealso \code{\link{plot.gg_boost_effect}}, \code{\link{gg_boost_vimp}}
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
    "'marginal.plot.boostmtree' object; got an object of class ",
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
  time_points <- object$time.points
  var_levels <- names(curves)

  blocks <- lapply(var_levels, function(nm) {
    wide <- curves[[nm]]
    # Column 1 is the covariate grid; the rest are one column per time point,
    # named time.0.50 and so on. Take the times from $time.points rather than
    # parsing those labels, so precision is not lost to the label's rounding.
    value_cols <- seq_len(ncol(wide))[-1]
    if (length(value_cols) != length(time_points)) {
      stop(
        "gg_boost_effect: variable '", nm, "' has ", length(value_cols),
        " curve column(s) but the object records ", length(time_points),
        " time point(s).",
        call. = FALSE
      )
    }
    do.call(rbind, lapply(seq_along(value_cols), function(k) {
      data.frame(
        variable = factor(nm, levels = var_levels),
        x = as.numeric(wide[[1]]),
        time = as.numeric(time_points[k]),
        estimate = as.numeric(wide[[value_cols[k]]]),
        kind = factor("partial", levels = "partial"),
        stringsAsFactors = FALSE
      )
    }))
  })

  .gg_boost_effect_frame(blocks)
}

#' @export
gg_boost_effect.marginal.plot.boostmtree <- function(object, ...) {
  smooth <- object$smooth
  if (is.null(smooth) || length(smooth) == 0L) {
    stop("gg_boost_effect: this object records no smoothed effect curves.",
         call. = FALSE)
  }
  time_points <- object$time.points
  var_levels <- names(smooth)

  blocks <- lapply(var_levels, function(nm) {
    per_time <- smooth[[nm]]
    if (length(per_time) != length(time_points)) {
      stop(
        "gg_boost_effect: variable '", nm, "' has ", length(per_time),
        " smoothed curve(s) but the object records ", length(time_points),
        " time point(s).",
        call. = FALSE
      )
    }
    do.call(rbind, lapply(seq_along(per_time), function(k) {
      curve <- per_time[[k]]
      data.frame(
        variable = factor(nm, levels = var_levels),
        x = as.numeric(curve$x),
        time = as.numeric(time_points[k]),
        estimate = as.numeric(curve$y),
        kind = factor("marginal", levels = "marginal"),
        stringsAsFactors = FALSE
      )
    }))
  })

  .gg_boost_effect_frame(blocks)
}

# Shared tail of both methods: bind the per-variable blocks and class the
# result. The two methods differ only in how they reach a list of blocks.
.gg_boost_effect_frame <- function(blocks) {
  gg_dta <- do.call(rbind, blocks)
  rownames(gg_dta) <- NULL
  class(gg_dta) <- c("gg_boost_effect", class(gg_dta))
  gg_dta
}
