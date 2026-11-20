#' Plot a \code{\link{gg_boost_vimp_pool}} object
#'
#' Pooled variable importance: for each covariate, the spread over runs of its
#' importance minus that run's shadow band, with the share of runs in which it
#' cleared the band.
#'
#' @details
#' The layout follows \code{\link{plot.gg_boost_vimp}}: one panel for the main
#' effect and one for the interaction with time, sharing a variable axis, with
#' covariates running top to bottom by the largest median they reach in either
#' panel.
#'
#' Each run has its own band, so the runs are not drawn on the importance
#' scale against one shaded band. Instead the x axis is the margin over the
#' band: each run's importance minus the band of that run and panel. Zero is
#' then the line every run was judged against, and a run right of it cleared
#' its band. The box spans the 25th to 75th percentile of the margin across
#' runs, the whiskers the 15th to 85th, and each run is a small point. The
#' label at the right of each row, such as `18/50`, counts the runs that
#' cleared the band.
#'
#' A box well right of zero is a covariate that clears the band in nearly
#' every run; one straddling zero is borderline, and its verdict from any
#' single run is not to be trusted. The share is a measure of stability, not
#' a test.
#'
#' The x axis is labelled with the `metric` attribute. The caption gives the
#' number of runs and, when every run records one, the median overall time
#' effect. The returned plot carries no theme.
#'
#' @param object A \code{\link{gg_boost_vimp_pool}} object.
#' @param x A \code{\link{gg_boost_vimp_pool}} object.
#' @param ... Passed to \code{\link[ggplot2]{geom_point}} for the run points.
#'
#' @return A `ggplot` object.
#'
#' @seealso \code{\link{gg_boost_vimp_pool}}, \code{\link{plot.gg_boost_vimp}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' x <- boost_shadow(sim$features, sim$id, k = 2)
#' fit <- boostmtree::boostmtree(
#'   x = x, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, cv.flag = TRUE, verbose = FALSE
#' )
#' runs <- lapply(1:3, function(i) boostmtree::vimp.boostmtree(fit))
#' plot(gg_boost_vimp(runs))
#' }
#'
#' @importFrom ggplot2 geom_boxplot scale_x_continuous expansion
#' @export
autoplot.gg_boost_vimp_pool <- function(object, ...) {
  .boost_check_gg(object, "gg_boost_vimp_pool")
  runs <- attr(object, "runs")
  # A row subset of the frame keeps the whole runs attribute; draw only the
  # runs for the cells still in the frame.
  cell_key <- function(d) {
    paste(d$variable, d$component, d$response, sep = "\r")
  }
  runs <- runs[cell_key(runs) %in% cell_key(object), , drop = FALSE]

  # Most important at the top, as in the single-run figure.
  by_variable <- tapply(object$q50, as.character(object$variable),
                        max, na.rm = TRUE)
  var_levels <- names(sort(by_variable))
  object$variable <- factor(as.character(object$variable), levels = var_levels)
  runs$variable <- factor(as.character(runs$variable), levels = var_levels)
  object$label <- paste0(object$n_detected, "/", object$n_runs)

  metric <- attr(object, "metric") %||% "Importance"
  caption <- .vimp_pool_caption(attr(object, "n_runs") %||% max(object$n_runs),
                                attr(object, "time.effect"))

  point_args <- list(
    data = runs,
    mapping = ggplot2::aes(x = .data[["margin"]], y = .data[["variable"]]),
    size = 1, alpha = 0.5, inherit.aes = FALSE
  )
  dots <- list(...)
  point_args[names(dots)] <- dots

  gg_plt <- ggplot2::ggplot(object, ggplot2::aes(y = .data[["variable"]])) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey40") +
    ggplot2::geom_boxplot(
      ggplot2::aes(
        xmin = .data[["q15"]], xlower = .data[["q25"]],
        xmiddle = .data[["q50"]], xupper = .data[["q75"]],
        xmax = .data[["q85"]], group = .data[["variable"]]
      ),
      stat = "identity", orientation = "y", width = 0.6, fill = "grey90"
    ) +
    do.call(ggplot2::geom_point, point_args) +
    ggplot2::geom_text(
      ggplot2::aes(label = .data[["label"]]),
      x = Inf, hjust = 1.1, size = 3
    ) +
    # Room at the right for the k/N labels, clear of the boxes and points.
    ggplot2::scale_x_continuous(
      expand = ggplot2::expansion(mult = c(0.05, 0.3))
    ) +
    ggplot2::scale_y_discrete(limits = var_levels) +
    ggplot2::labs(x = paste0(metric, " minus the run's shadow band"),
                  y = NULL, caption = caption)

  labeller <- ggplot2::as_labeller(c(
    main = "Main effect", interaction = "Interaction with time"
  ))
  if (nlevels(object$response) > 1L) {
    gg_plt + ggplot2::facet_grid(
      response ~ component,
      labeller = ggplot2::labeller(component = labeller)
    )
  } else {
    gg_plt + ggplot2::facet_wrap(~ component, labeller = labeller)
  }
}

#' @rdname autoplot.gg_boost_vimp_pool
#' @export
plot.gg_boost_vimp_pool <- function(x, ...) {
  autoplot.gg_boost_vimp_pool(x, ...)
}

# Caption lines: how many runs, what the box and label mean, and the median
# overall time effect.
.vimp_pool_caption <- function(n_runs, time_effect) {
  lines <- c(
    paste0(n_runs, " runs, each judged against its own shadow band; ",
           "k/N runs cleared it"),
    "Box 25th to 75th percentile, whiskers 15th to 85th"
  )
  if (length(time_effect) > 0L && !anyNA(time_effect)) {
    lines <- c(lines, paste0("Median overall time effect: ",
                             paste(format(signif(time_effect, 3)),
                                   collapse = ", ")))
  }
  paste(lines, collapse = "\n")
}
