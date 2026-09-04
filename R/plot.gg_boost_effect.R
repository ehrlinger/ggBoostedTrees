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
#' @importFrom ggplot2 autoplot ggplot aes geom_line facet_wrap labs
#' @export
autoplot.gg_boost_effect <- function(object, ...) {
  .boost_check_gg(object, "gg_boost_effect")

  gg_plt <- ggplot2::ggplot(
    object,
    ggplot2::aes(
      x = .data[["x"]],
      y = .data[["estimate"]],
      colour = .data[["time"]],
      group = interaction(.data[["time"]], .data[["variable"]])
    )
  ) +
    ggplot2::geom_line(...) +
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
