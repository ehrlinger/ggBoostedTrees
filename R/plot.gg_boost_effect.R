#' Plot a \code{\link{gg_boost_effect}} object
#'
#' Covariate effect curves, one line per time point, faceted by variable.
#'
#' @details
#' Time is mapped to colour rather than to a facet because the question this
#' figure answers is how a covariate's effect *changes* across follow-up, and
#' that change is legible only when the curves share one panel. Variables get
#' the facets instead, since their x scales are unrelated.
#'
#' A continuous covariate is drawn as a line per time point across the
#' covariate grid. A discrete (factor) covariate has one row per level, so
#' a "curve" would connect points along an axis with no ordering; it is
#' drawn instead as a point per level per time point, on an axis labelled
#' with the level names. Because `ggplot2` permits only one scale type per
#' aesthetic across all facets, an object mixing continuous and discrete
#' covariates cannot be drawn as a single figure and is refused with an
#' error asking the caller to plot them one at a time.
#'
#' The returned plot carries no theme.
#'
#' @param object A \code{\link{gg_boost_effect}} object.
#' @param x A \code{\link{gg_boost_effect}} object.
#' @param ... Passed to \code{\link[ggplot2]{geom_line}}.
#'
#' @return A `ggplot` object.
#'
#' @seealso \code{\link{gg_boost_effect}}
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
#' @importFrom ggplot2 autoplot ggplot aes geom_line geom_point facet_wrap labs
#' @export
autoplot.gg_boost_effect <- function(object, ...) {
  .boost_check_gg(object, "gg_boost_effect")

  # x_label is NA exactly for continuous covariates, so its pattern says which
  # geometry applies. ggplot2 permits one scale type per aesthetic across all
  # facets, so an object mixing the two cannot be drawn as one figure.
  discrete_by_variable <- tapply(
    !is.na(object$x_label), object$variable, any
  )
  discrete_by_variable <- discrete_by_variable[!is.na(discrete_by_variable)]

  if (length(unique(discrete_by_variable)) > 1L) {
    stop(
      "autoplot.gg_boost_effect: this object mixes continuous and discrete ",
      "covariates, which cannot share one figure. Extract and plot them one ",
      "at a time.",
      call. = FALSE
    )
  }
  discrete <- isTRUE(all(discrete_by_variable))

  if (discrete) {
    gg_plt <- ggplot2::ggplot(
      object,
      ggplot2::aes(
        x = .data[["x_label"]],
        y = .data[["estimate"]],
        colour = .data[["time"]]
      )
    ) +
      ggplot2::geom_point(...)
  } else {
    gg_plt <- ggplot2::ggplot(
      object,
      ggplot2::aes(
        x = .data[["x"]],
        y = .data[["estimate"]],
        colour = .data[["time"]],
        group = interaction(.data[["time"]], .data[["variable"]])
      )
    ) +
      ggplot2::geom_line(...)
  }

  gg_plt <- gg_plt +
    ggplot2::labs(x = "Covariate value", y = "Effect", colour = "Time")

  if (nlevels(object$variable) > 1L) {
    gg_plt <- gg_plt +
      ggplot2::facet_wrap(~ variable, scales = "free_x")
  }

  gg_plt
}

#' @rdname autoplot.gg_boost_effect
#' @export
plot.gg_boost_effect <- function(x, ...) {
  autoplot.gg_boost_effect(x, ...)
}
