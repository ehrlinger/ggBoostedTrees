#' Plot a \code{\link{gg_boost_trajectory}} object
#'
#' Observed and fitted subject trajectories over time: one line per subject
#' through the fitted values, with the observed values as points.
#'
#' @details
#' The extractor returns every subject, so thinning happens here and the tidy
#' data frame always represents the whole fit. `subset` names the subjects to
#' keep; `n_max` caps how many are drawn, sampling at random and saying so.
#' Set `n_max = Inf` to draw all of them. Random sampling is not seeded --
#' call `set.seed()` first for a reproducible figure.
#'
#' Transparency is doing real work in this figure rather than decorating it.
#' A cohort of any size overplots, and partial transparency turns the tangle
#' into something you can read densities off: where many subjects follow the
#' same path the ink accumulates. The default `alpha` therefore falls as the
#' number of subjects drawn rises. Pass `alpha` explicitly to override.
#'
#' The returned plot carries no theme.
#'
#' @param object A \code{\link{gg_boost_trajectory}} object.
#' @param x A \code{\link{gg_boost_trajectory}} object.
#' @param subset Character or numeric vector of subject identifiers to keep.
#'   `NULL` (default) keeps all of them.
#' @param n_max Maximum number of subjects to draw. Defaults to 100; `Inf`
#'   draws every subject.
#' @param observed Logical. Draw the observed values as points. Defaults to
#'   `TRUE`, and is ignored when the fit records no observed values.
#' @param alpha Numeric transparency for both layers. `NULL` (default)
#'   computes one from the number of subjects drawn.
#' @param ... Passed to \code{\link[ggplot2]{geom_line}}.
#'
#' @return A `ggplot` object.
#'
#' @seealso \code{\link{gg_boost_trajectory}}
#'
#' @examples
#' \donttest{
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' fit <- boostmtree::boostmtree(
#'   x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'   M = 50, verbose = FALSE
#' )
#' plot(gg_boost_trajectory(fit))
#' }
#'
#' @importFrom ggplot2 autoplot ggplot aes geom_line geom_point facet_wrap labs
#' @export
autoplot.gg_boost_trajectory <- function(object,
                                         subset = NULL,
                                         n_max = 100,
                                         observed = TRUE,
                                         alpha = NULL,
                                         ...) {
  .boost_check_gg(object, "gg_boost_trajectory")

  if (!is.null(subset)) {
    wanted <- as.character(subset)
    missing_ids <- setdiff(wanted, levels(object$id))
    if (length(missing_ids) > 0L) {
      stop(
        "autoplot.gg_boost_trajectory: no such subject(s): ",
        paste(missing_ids, collapse = ", "), ".",
        call. = FALSE
      )
    }
    object <- object[as.character(object$id) %in% wanted, , drop = FALSE]
    object$id <- factor(as.character(object$id), levels = wanted)
  }

  drawn <- levels(droplevels(object$id))
  if (is.finite(n_max) && length(drawn) > n_max) {
    message(
      "Drawing ", n_max, " of ", length(drawn),
      " subjects, chosen at random. Pass n_max = Inf to draw all, or ",
      "subset to choose; call set.seed() first for a reproducible sample."
    )
    keep <- sample(drawn, n_max)
    object <- object[as.character(object$id) %in% keep, , drop = FALSE]
    object$id <- factor(as.character(object$id), levels = keep)
    drawn <- keep
  }

  if (is.null(alpha)) {
    alpha <- .boost_trajectory_alpha(length(drawn))
  }

  gg_plt <- ggplot2::ggplot(
    object,
    ggplot2::aes(x = .data[["time"]], y = .data[["fitted"]])
  ) +
    ggplot2::geom_line(
      ggplot2::aes(group = .data[["id"]]),
      alpha = alpha,
      ...
    ) +
    ggplot2::labs(x = "Time", y = "Response")

  # A predict object carries no observed values; drawing an all-NA point
  # layer would emit a removed-rows warning and show nothing.
  if (isTRUE(observed) && any(!is.na(object$observed))) {
    gg_plt <- gg_plt +
      ggplot2::geom_point(
        ggplot2::aes(y = .data[["observed"]]),
        alpha = alpha,
        na.rm = TRUE
      )
  }

  if (nlevels(object$response) > 1L) {
    gg_plt <- gg_plt +
      ggplot2::facet_wrap(~ response, scales = "free_y")
  }

  gg_plt
}

#' @rdname autoplot.gg_boost_trajectory
#' @export
plot.gg_boost_trajectory <- function(x,
                                     subset = NULL,
                                     n_max = 100,
                                     observed = TRUE,
                                     alpha = NULL,
                                     ...) {
  autoplot.gg_boost_trajectory(
    x, subset = subset, n_max = n_max, observed = observed, alpha = alpha, ...
  )
}

# Transparency as a density read: with many subjects on one panel the lines
# overlap, and the accumulated ink is the signal. Falls from 0.9 for a handful
# of subjects toward a floor of 0.1 for a large cohort, so a spaghetti plot
# stays legible without the caller tuning it.
.boost_trajectory_alpha <- function(n) {
  if (n <= 0L) {
    return(0.9)
  }
  max(0.1, min(0.9, 12 / n))
}
