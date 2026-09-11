#' Plot a \code{\link{gg_boost_calibration}} object
#'
#' Observed against fitted over follow-up: bin means of the observed values
#' with their intervals, the fitted bin means beside them, and the cohort mean
#' curve when the object carries one.
#'
#' @details
#' Each bin is drawn as a thin horizontal segment spanning its time range at
#' the observed mean. With equal-count bins that segment is the tail-support
#' signal: where observations are sparse, a bin has to stretch further to
#' collect its share, so a long segment late in follow-up means a thin tail.
#'
#' Observed bin means are points with vertical 95\% intervals (`ci = TRUE`);
#' fitted bin means are a second point series in another shape, joined by a
#' dashed line. Where the two agree bin by bin, the model is calibrated over
#' that stretch of follow-up. The cohort curve, drawn as a heavier line, is
#' the mean predicted curve across all subjects; it can depart from the bin
#' means late in follow-up when the subjects still being measured differ from
#' the cohort, which is a property of follow-up rather than of the model.
#'
#' The returned plot carries no theme.
#'
#' @param object A \code{\link{gg_boost_calibration}} object.
#' @param x A \code{\link{gg_boost_calibration}} object.
#' @param ci Logical. Draw 95\% intervals on the observed bin means. Defaults
#'   to `TRUE`; bins holding one observation have none.
#' @param ... Not used; present for S3 consistency.
#'
#' @return A `ggplot` object.
#'
#' @seealso \code{\link{gg_boost_calibration}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' fit <- boostmtree::boostmtree(
#'   x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, verbose = FALSE
#' )
#' plot(gg_boost_calibration(fit, pred = predict(fit, x = fit$x)))
#' }
#'
#' @importFrom ggplot2 autoplot ggplot aes geom_segment geom_linerange
#'   geom_line geom_point facet_wrap labs
#' @export
autoplot.gg_boost_calibration <- function(object, ci = TRUE, ...) {
  .boost_check_gg(object, "gg_boost_calibration")

  cohort <- attr(object, "cohort")
  dta <- as.data.frame(unclass(object), stringsAsFactors = FALSE)

  # Observed and fitted share the point layer so one shape legend
  # distinguishes them.
  pts <- rbind(
    data.frame(response = dta$response, time = dta$time,
               value = dta$observed, series = "Observed"),
    data.frame(response = dta$response, time = dta$time,
               value = dta$fitted, series = "Fitted")
  )
  pts$series <- factor(pts$series, levels = c("Observed", "Fitted"))

  gg_plt <- ggplot2::ggplot() +
    ggplot2::geom_segment(
      data = dta,
      ggplot2::aes(
        x = .data[["time_lo"]], xend = .data[["time_hi"]],
        y = .data[["observed"]], yend = .data[["observed"]]
      ),
      colour = "grey60"
    )

  if (isTRUE(ci)) {
    # A single-observation bin has NA bounds; drawing it would emit a
    # removed-rows warning and show nothing.
    gg_plt <- gg_plt +
      ggplot2::geom_linerange(
        data = dta[!is.na(dta$observed_lo), , drop = FALSE],
        ggplot2::aes(
          x = .data[["time"]], ymin = .data[["observed_lo"]],
          ymax = .data[["observed_hi"]]
        )
      )
  }

  gg_plt <- gg_plt +
    ggplot2::geom_line(
      data = pts[pts$series == "Fitted", , drop = FALSE],
      ggplot2::aes(
        x = .data[["time"]], y = .data[["value"]],
        group = .data[["response"]]
      ),
      linetype = "dashed"
    ) +
    ggplot2::geom_point(
      data = pts,
      ggplot2::aes(
        x = .data[["time"]], y = .data[["value"]],
        shape = .data[["series"]]
      ),
      size = 2
    )

  if (!is.null(cohort)) {
    gg_plt <- gg_plt +
      ggplot2::geom_line(
        data = cohort,
        ggplot2::aes(
          x = .data[["time"]], y = .data[["fitted"]],
          group = .data[["response"]]
        ),
        linewidth = 1.2
      )
  }

  gg_plt <- gg_plt +
    ggplot2::labs(x = "Time", y = "Response", shape = NULL)

  if (nlevels(dta$response) > 1L) {
    gg_plt <- gg_plt +
      ggplot2::facet_wrap(~ response, scales = "free_y")
  }

  gg_plt
}

#' @rdname autoplot.gg_boost_calibration
#' @export
plot.gg_boost_calibration <- function(x, ci = TRUE, ...) {
  autoplot.gg_boost_calibration(x, ci = ci, ...)
}
