#' Plot a boostmtree fit
#'
#' A shortcut to the error trajectory, which is the first thing worth looking
#' at after a fit. Every other figure is reached through its own
#' `gg_boost_*()` extractor.
#'
#' @param object A fitted \code{\link[boostmtree]{boostmtree}} object grown
#'   with `cv.flag = TRUE`.
#' @param ... Passed to \code{\link{autoplot.gg_boost_error}}.
#'
#' @return A `ggplot` object, as produced by
#'   \code{\link{autoplot.gg_boost_error}}.
#'
#' @seealso \code{\link{gg_boost_error}}, \code{\link{gg_boost_path}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' fit <- boostmtree::boostmtree(
#'   x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, cv.flag = TRUE, verbose = FALSE
#' )
#' ggplot2::autoplot(fit)
#' }
#'
#' @importFrom ggplot2 autoplot
#' @export
autoplot.boostmtree <- function(object, ...) {
  autoplot.gg_boost_error(gg_boost_error(object), ...)
}
