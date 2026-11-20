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
#' The caption says whether boosting ran long enough. It gives the optimal
#' iteration against the number grown, and how much the error fell over the
#' last quarter of the iterations. An optimum at the last iteration does not
#' by itself mean the fit is unfinished: if the error fell by a percent or
#' so over that last stretch, the curve has flattened and more iterations
#' would change little. A curve still falling steeply calls for a refit with
#' more iterations or a larger learning rate.
#'
#' @param object A \code{\link{gg_boost_error}} object.
#' @param x A \code{\link{gg_boost_error}} object.
#' @param optimal Logical. Draw a vertical rule at the optimal iteration.
#'   Defaults to `TRUE`.
#' @param convergence Logical. Report the optimal iteration and the error's
#'   relative change over the last quarter of the iterations in the caption.
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
autoplot.gg_boost_error <- function(object, optimal = TRUE,
                                    convergence = TRUE, ...) {
  .boost_check_gg(object, "gg_boost_error")

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

  if (isTRUE(convergence)) {
    gg_plt <- gg_plt +
      ggplot2::labs(caption = .error_caption(.error_convergence(object)))
  }

  gg_plt
}

#' @rdname autoplot.gg_boost_error
#' @export
plot.gg_boost_error <- function(x, optimal = TRUE, convergence = TRUE, ...) {
  autoplot.gg_boost_error(x, optimal = optimal, convergence = convergence,
                          ...)
}

# One row per response: the optimal iteration (NA when the backend selects
# none), the number of iterations grown, the width of the last quarter, and
# the error's relative change across it (NA when the window starts at zero,
# where a relative change is undefined). Computed from the extracted data
# alone, so the renderer never reaches back into the fit.
.error_convergence <- function(object, tail = 0.25) {
  rows <- lapply(split(object, object$response, drop = TRUE), function(d) {
    d <- d[order(d$iteration), , drop = FALSE]
    m <- nrow(d)
    window <- max(1L, as.integer(round(tail * m)))
    from <- d$value[max(1L, m - window)]
    opt <- d$iteration[d$optimal]
    data.frame(
      response = as.character(d$response[1]),
      m_opt = if (length(opt)) opt[1] else NA_integer_,
      m = m,
      window = window,
      change = if (from == 0) NA_real_ else (d$value[m] - from) / from,
      to = d$value[m],
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

.error_caption <- function(conv) {
  lines <- vapply(seq_len(nrow(conv)), function(i) {
    r <- conv[i, ]
    opt <- if (is.na(r$m_opt)) {
      paste0(r$m, " iterations")
    } else {
      paste0("Optimal iteration ", r$m_opt, " of ", r$m)
    }
    move <- if (!is.na(r$change)) {
      paste0(if (r$change <= 0) "fell " else "rose ",
             format(round(100 * abs(r$change), 1), nsmall = 1), "%")
    } else if (r$to == 0) {
      "stayed at zero"
    } else {
      "rose from zero"
    }
    line <- paste0(opt, "; error ", move, " over the last ",
                   if (r$window == 1L) "iteration" else
                     paste(r$window, "iterations"))
    if (nrow(conv) > 1L) line <- paste0(r$response, ": ", line)
    line
  }, character(1))
  paste(lines, collapse = "\n")
}
