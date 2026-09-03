#' Plot a \code{\link{gg_boost_error}} object
#'
#' The error path of a boosted multivariate tree fit against the boosting
#' iteration, with the cross-validated optimal iteration marked.
#'
#' @details
#' The returned plot carries no theme, so it composes with any `ggplot2`
#' theme or scale. Several responses are drawn as facets rather than as
#' coloured series, because the responses do not share a y scale.
#'
#' @param object A \code{\link{gg_boost_error}} object.
#' @param x A \code{\link{gg_boost_error}} object.
#' @param optimal Logical. Draw a vertical rule at the optimal iteration.
#'   Defaults to `TRUE`.
#' @param ... Passed to \code{\link[ggplot2]{geom_line}}.
#'
#' @return A `ggplot` object.
#'
#' @seealso \code{\link{gg_boost_error}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' fit <- boostmtree::boostmtree(
#'   x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, cv.flag = TRUE, verbose = FALSE
#' )
#' plot(gg_boost_error(fit))
#' }
#'
#' @importFrom ggplot2 autoplot ggplot aes geom_line geom_vline facet_wrap labs
#' @export
autoplot.gg_boost_error <- function(object, optimal = TRUE, ...) {
  if (!inherits(object, "gg_boost_error")) {
    stop("Incorrect object type: expected a gg_boost_error object.",
         call. = FALSE)
  }

  gg_plt <- ggplot2::ggplot(
    object,
    ggplot2::aes(x = .data[["iteration"]], y = .data[["value"]])
  ) +
    ggplot2::geom_line(...) +
    ggplot2::labs(x = "Boosting Iteration", y = "Error")

  if (isTRUE(optimal) && any(object$optimal)) {
    rules <- object[object$optimal, c("iteration", "response"), drop = FALSE]
    gg_plt <- gg_plt +
      ggplot2::geom_vline(
        data = rules,
        ggplot2::aes(xintercept = .data[["iteration"]]),
        linetype = "dashed"
      )
  }

  # Facet only when there is something to separate: a single-response fit
  # gets a bare panel rather than a strip labelled "y".
  if (nlevels(object$response) > 1L) {
    gg_plt <- gg_plt + ggplot2::facet_wrap(~ response, scales = "free_y")
  }

  gg_plt
}

#' @rdname autoplot.gg_boost_error
#' @export
plot.gg_boost_error <- function(x, optimal = TRUE, ...) {
  autoplot.gg_boost_error(x, optimal = optimal, ...)
}
