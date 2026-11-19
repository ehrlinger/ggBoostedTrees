#' Plot a \code{\link{gg_boost_prediction}} object
#'
#' Each subject's predicted response at a fixed time, against one covariate.
#'
#' @details
#' For a numeric covariate every subject is a point and a loess smoother
#' traces the trend. The smoother summarises the points; it is not a partial
#' effect, because the other covariates are left at each subject's own values.
#' A flat smoother over a wide scatter says the covariate matters little at
#' this time and the others drive the spread.
#'
#' For a factor covariate the points are grouped by level with each level's
#' mean marked.
#'
#' The returned plot carries no theme.
#'
#' @param object A \code{\link{gg_boost_prediction}} object.
#' @param x A \code{\link{gg_boost_prediction}} object.
#' @param covariate Name of the covariate to place on the x axis.
#' @param ... Passed to \code{\link[ggplot2]{geom_point}}.
#'
#' @return A `ggplot` object.
#'
#' @seealso \code{\link{gg_boost_prediction}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' fit <- boostmtree::boostmtree(
#'   x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, cv.flag = TRUE, verbose = FALSE
#' )
#' plot(gg_boost_prediction(fit, time = 1), covariate = "x1")
#' }
#'
#' @importFrom ggplot2 autoplot ggplot aes geom_point geom_smooth stat_summary
#'   labs
#' @export
autoplot.gg_boost_prediction <- function(object, covariate, ...) {
  .boost_check_gg(object, "gg_boost_prediction")

  covariates <- setdiff(names(object), c("id", "predicted"))
  if (missing(covariate) || !is.character(covariate) ||
        length(covariate) != 1L || !covariate %in% covariates) {
    stop(
      "autoplot.gg_boost_prediction: 'covariate' must name one of ",
      paste(sQuote(covariates), collapse = ", "), ".",
      call. = FALSE
    )
  }

  ylab <- paste0("Predicted response at time ", attr(object, "time"))
  gg_plt <- ggplot2::ggplot(
    object,
    ggplot2::aes(x = .data[[covariate]], y = .data[["predicted"]])
  ) +
    ggplot2::geom_point(...) +
    ggplot2::labs(x = covariate, y = ylab)

  if (is.numeric(object[[covariate]])) {
    gg_plt <- gg_plt +
      ggplot2::geom_smooth(method = "loess", formula = y ~ x, se = FALSE)
  } else {
    gg_plt <- gg_plt +
      ggplot2::stat_summary(fun = mean, geom = "point", shape = 23,
                            size = 3, fill = "white")
  }

  gg_plt
}

#' @rdname autoplot.gg_boost_prediction
#' @export
plot.gg_boost_prediction <- function(x, covariate, ...) {
  autoplot.gg_boost_prediction(x, covariate, ...)
}
