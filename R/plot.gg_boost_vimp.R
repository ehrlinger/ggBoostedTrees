#' Plot a \code{\link{gg_boost_vimp}} object
#'
#' Variable importance as a horizontal bar chart, ordered by importance and
#' faceted by component.
#'
#' @details
#' Bars run horizontally because variable names are text and read better along
#' the y axis than rotated beneath it, and variables are ordered by importance
#' because an importance chart in arbitrary order is close to unreadable.
#'
#' The x axis is labelled with the `metric` attribute carried by the extracted
#' object. That metric is a property of how importance was computed rather than
#' a fixed quantity, so a hard-coded label would misdescribe some objects.
#'
#' A negative importance is not an error: with a permutation-style metric a
#' variable that contributes nothing can score slightly below zero by chance.
#'
#' The returned plot carries no theme.
#'
#' @param object A \code{\link{gg_boost_vimp}} object.
#' @param x A \code{\link{gg_boost_vimp}} object.
#' @param ... Passed to \code{\link[ggplot2]{geom_col}}.
#'
#' @return A `ggplot` object.
#'
#' @seealso \code{\link{gg_boost_vimp}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' fit <- boostmtree::boostmtree(
#'   x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, cv.flag = TRUE, verbose = FALSE
#' )
#' plot(gg_boost_vimp(boostmtree::vimp.boostmtree(fit)))
#' }
#'
#' @importFrom ggplot2 autoplot ggplot aes geom_col coord_flip facet_wrap labs
#' @export
autoplot.gg_boost_vimp <- function(object, ...) {
  .boost_check_gg(object, "gg_boost_vimp")

  # Order by the largest importance a variable reaches in any component, so
  # both facets share one ordering and a variable sits on the same row in each.
  by_variable <- tapply(object$importance, object$variable, max, na.rm = TRUE)
  ordered_levels <- names(sort(by_variable))
  object$variable <- factor(as.character(object$variable),
                            levels = ordered_levels)

  metric <- attr(object, "metric") %||% "Importance"

  gg_plt <- ggplot2::ggplot(
    object,
    ggplot2::aes(x = .data[["variable"]], y = .data[["importance"]])
  ) +
    ggplot2::geom_col(...) +
    ggplot2::coord_flip() +
    ggplot2::labs(x = "Variable", y = metric)

  if (nlevels(object$response) > 1L) {
    gg_plt <- gg_plt +
      ggplot2::facet_wrap(~ component + response)
  } else if (nlevels(object$component) > 1L) {
    gg_plt <- gg_plt + ggplot2::facet_wrap(~ component)
  }

  gg_plt
}

#' @rdname autoplot.gg_boost_vimp
#' @export
plot.gg_boost_vimp <- function(x, ...) {
  autoplot.gg_boost_vimp(x, ...)
}
