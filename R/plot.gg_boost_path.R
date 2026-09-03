#' Plot a \code{\link{gg_boost_path}} object
#'
#' The estimated correlation, variance, and smoothing parameter paths of a
#' boosted multivariate tree fit against the boosting iteration.
#'
#' @details
#' The three parameters live on entirely different scales, so they are always
#' faceted with a free y axis rather than drawn together. With several
#' responses the facet grid is parameter by response.
#'
#' The returned plot carries no theme.
#'
#' @param object A \code{\link{gg_boost_path}} object.
#' @param x A \code{\link{gg_boost_path}} object.
#' @param ... Passed to \code{\link[ggplot2]{geom_line}}.
#'
#' @return A `ggplot` object.
#'
#' @seealso \code{\link{gg_boost_path}}
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
#' @importFrom ggplot2 autoplot ggplot aes geom_line facet_wrap facet_grid labs
#' @export
autoplot.gg_boost_path <- function(object, ...) {
  if (!inherits(object, "gg_boost_path")) {
    stop("Incorrect object type: expected a gg_boost_path object.",
         call. = FALSE)
  }

  gg_plt <- ggplot2::ggplot(
    object,
    ggplot2::aes(x = .data[["iteration"]], y = .data[["value"]])
  ) +
    ggplot2::geom_line(...) +
    ggplot2::labs(x = "Boosting Iteration", y = "Estimate")

  if (nlevels(object$response) > 1L) {
    gg_plt <- gg_plt +
      ggplot2::facet_grid(parameter ~ response, scales = "free_y")
  } else {
    gg_plt <- gg_plt +
      ggplot2::facet_wrap(~ parameter, scales = "free_y", ncol = 1L)
  }

  gg_plt
}

#' @rdname autoplot.gg_boost_path
#' @export
plot.gg_boost_path <- function(x, ...) {
  autoplot.gg_boost_path(x, ...)
}
