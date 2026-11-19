#' Plot a \code{\link{gg_boost_vimp}} object
#'
#' Variable importance as a dot chart: one panel for the main effect of each
#' covariate and one for its interaction with time, sharing a variable axis,
#' with the noise band shaded in each.
#'
#' @details
#' The two panels share one variable axis, so a covariate reads across a row:
#' a long stem under "Main effect" and a hollow dot under "Interaction with
#' time" is a covariate whose effect is constant over follow-up; a stem in the
#' second panel means its effect changes with time. Variables run top to
#' bottom by the largest importance they reach in either component. Both
#' panels share one importance scale, so an interaction can be judged against
#' the main effects, not only against other interactions.
#'
#' `boostmtree` reports importance as the relative increase in error after
#' perturbing a covariate, so a covariate that contributes nothing scores near
#' zero and is as often slightly negative as slightly positive. The negative
#' values therefore show how far noise alone reaches. The shaded band runs
#' from minus to plus the largest absolute negative importance for the
#' response, across both components; a value is detectable only when it lies
#' to the right of the band, and is then drawn as a filled dot on a stem.
#' Values inside the band are hollow. With no negative values there is no
#' band and any positive value is detectable. This is a reading aid, not a
#' test.
#'
#' Every value is drawn at its signed importance. When no covariate has a
#' detectable interaction with time, that panel says so in words. The overall
#' time effect, when the source object records one, is reported in the
#' caption: it says whether the trajectory has a shape at all, which the
#' per-covariate interactions cannot.
#'
#' The x axis is labelled with the `metric` attribute carried by the extracted
#' object. The returned plot carries no theme.
#'
#' @param object A \code{\link{gg_boost_vimp}} object.
#' @param x A \code{\link{gg_boost_vimp}} object.
#' @param ... Passed to \code{\link[ggplot2]{geom_point}}.
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
#' @importFrom ggplot2 autoplot ggplot aes geom_point geom_segment geom_rect
#'   geom_vline geom_text facet_wrap facet_grid labs scale_shape_manual
#'   as_labeller scale_y_discrete
#' @export
autoplot.gg_boost_vimp <- function(object, ...) {
  .boost_check_gg(object, "gg_boost_vimp")

  # Most important at the top: ggplot draws the first factor level at the
  # bottom of a discrete y axis, so the levels run in increasing order.
  by_variable <- tapply(object$importance, object$variable, max, na.rm = TRUE)
  object$variable <- factor(as.character(object$variable),
                            levels = names(sort(by_variable)))

  object$band <- stats::ave(object$importance, object$response,
                            FUN = .vimp_noise_band)
  object$detectable <- !is.na(object$importance) &
    object$importance > object$band
  object$mark <- factor(
    ifelse(object$detectable, "Detectable", "Within noise band"),
    levels = c("Detectable", "Within noise band")
  )

  metric <- attr(object, "metric") %||% "Importance"
  time_effect <- attr(object, "time.effect")
  caption <- if (length(time_effect) > 0L && !anyNA(time_effect)) {
    paste0("Overall time effect: ",
           paste(format(signif(time_effect, 3)), collapse = ", "))
  }

  bands <- unique(object[object$band > 0,
                         c("component", "response", "band")])

  gg_plt <- ggplot2::ggplot(
    object,
    ggplot2::aes(x = .data[["importance"]], y = .data[["variable"]])
  ) +
    ggplot2::geom_rect(
      data = bands,
      ggplot2::aes(xmin = -.data[["band"]], xmax = .data[["band"]]),
      ymin = -Inf, ymax = Inf, fill = "grey85", inherit.aes = FALSE
    ) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey40") +
    ggplot2::geom_segment(
      data = object[object$detectable, , drop = FALSE],
      ggplot2::aes(x = 0, xend = .data[["importance"]],
                   yend = .data[["variable"]])
    ) +
    ggplot2::geom_point(
      ggplot2::aes(shape = .data[["mark"]]), size = 3.5, stroke = 1,
      fill = "white", ...
    ) +
    ggplot2::scale_shape_manual(
      values = c(`Detectable` = 16, `Within noise band` = 21),
      name = NULL, drop = FALSE
    ) +
    # Pinned, because the stem layer holds only detectable rows and a
    # discrete scale trained on it first would put those variables first.
    ggplot2::scale_y_discrete(limits = levels(object$variable)) +
    ggplot2::labs(x = metric, y = NULL, caption = caption) +
    .vimp_none_note(object)

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

#' @rdname autoplot.gg_boost_vimp
#' @export
plot.gg_boost_vimp <- function(x, ...) {
  autoplot.gg_boost_vimp(x, ...)
}

# How far noise alone reaches: a covariate that contributes nothing scores
# near zero with either sign, so the largest negative importance bounds what
# chance produces. Zero when nothing is negative. Called once per response,
# since each has its own noise.
.vimp_noise_band <- function(importance) {
  negatives <- importance[!is.na(importance) & importance < 0]
  if (length(negatives) > 0L) max(abs(negatives)) else 0
}

# Say in words when the interaction panel has nothing detectable in it; a
# column of hollow dots inside the band is easy to read past.
.vimp_none_note <- function(object) {
  inter <- object[object$component == "interaction", , drop = FALSE]
  if (nrow(inter) == 0L) {
    return(NULL)
  }
  none <- tapply(inter$detectable, inter$response, function(d) !any(d))
  none <- names(none)[!is.na(none) & none]
  if (length(none) == 0L) {
    return(NULL)
  }
  notes <- data.frame(
    component = factor("interaction", levels = levels(object$component)),
    response = factor(none, levels = levels(object$response)),
    label = "None detectable",
    stringsAsFactors = FALSE
  )
  ggplot2::geom_text(
    data = notes,
    ggplot2::aes(label = .data[["label"]]),
    x = Inf, y = -Inf, hjust = 1.05, vjust = -0.6, inherit.aes = FALSE
  )
}
