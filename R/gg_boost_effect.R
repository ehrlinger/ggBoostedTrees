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
#' `marginal.plot()` returns a raw scatter alongside its smoothed curve.
#' That scatter is not the raw observations: it holds one unsmoothed fitted
#' prediction per subject at the subject's own observed covariate value,
#' not the observed response and not the stored fitted values. It is also
#' not reconstructable from \code{\link{gg_boost_trajectory}}, which carries
#' no covariate column. `gg_boost_effect` extracts the smoothed curve instead,
#' so that both levels of `kind` mean the same thing: the fitted effect.
#'
#' Neither source computes a confidence interval, so none is reported here.
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
#' `gg_boost_effect` is currently single-response only. `boostmtree` nests
#' `$curves` / `$smooth` as `[[response]][[variable]]` and flattens the outer
#' level only when the fit has a single response; a multi-response object is
#' rejected with an informative error rather than mishandled. This is also
#' why `gg_boost_effect` is the one class of the five without a `response`
#' column.
#'
#' @param object A `partial.plot.boostmtree` or `marginal.plot.boostmtree`
#'   object, as returned by `boostmtree::partial.plot()` or
#'   `boostmtree::marginal.plot()` with `output = "data", verbose = FALSE`.
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
  if (!is.data.frame(curves[[1L]])) {
    stop(
      "gg_boost_effect: this partial.plot object is nested by response ",
      "(multi-response fit); gg_boost_effect() supports single-response ",
      "'partial.plot.boostmtree' objects only.",
      call. = FALSE
    )
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

  .gg_boost_effect_frame(blocks)
}

#' @export
gg_boost_effect.marginal.plot.boostmtree <- function(object, ...) {
  smooth <- object$smooth
  if (is.null(smooth) || length(smooth) == 0L) {
    stop("gg_boost_effect: this object records no smoothed effect curves.",
         call. = FALSE)
  }
  if (!is.data.frame(smooth[[1L]][[1L]])) {
    stop(
      "gg_boost_effect: this marginal.plot object is nested by response ",
      "(multi-response fit); gg_boost_effect() supports single-response ",
      "'marginal.plot.boostmtree' objects only.",
      call. = FALSE
    )
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

  .gg_boost_effect_frame(blocks)
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

# Shared tail of both methods: bind the per-variable blocks and class the
# result. The two methods differ only in how they reach a list of blocks.
.gg_boost_effect_frame <- function(blocks) {
  gg_dta <- do.call(rbind, blocks)
  rownames(gg_dta) <- NULL
  class(gg_dta) <- c("gg_boost_effect", class(gg_dta))
  gg_dta
}
