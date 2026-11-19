#' Plot a \code{\link{gg_boost_vimp}} object
#'
#' Variable importance as a dot chart: one panel for the main effect of each
#' covariate and one for its interaction with time, sharing a variable axis.
#' When the fit carries shadow covariates, the noise they set is shaded.
#'
#' @details
#' The two panels share one variable axis, so a covariate reads across a row:
#' a long stem under "Main effect" and a hollow dot under "Interaction with
#' time" is a covariate whose effect is constant over follow-up; a stem in the
#' second panel means its effect changes with time. Variables run top to
#' bottom by the largest importance they reach in either component. Both
#' panels share one importance scale, so an interaction can be judged against
#' the main effects, not only against other interactions. Every value is drawn
#' at its signed importance.
#'
#' `boostmtree` importance has no fixed scale: what a covariate with no signal
#' scores rises with the amount of boosting. The reference is therefore
#' measured in the fit itself, from shadow covariates added before fitting
#' with \code{\link{boost_shadow}}. In each panel the shaded band runs up to
#' the largest importance any shadow reached in that component (or zero, if
#' every shadow scored below zero). A covariate right of the band is
#' detectable and drawn as a filled dot on a stem; one inside it is hollow.
#' Shadows set the band but are not drawn as variables. This is a reading aid,
#' not a test, and a hollow dot means "not detected in this fit", not "no
#' effect": a real but small effect often falls inside the band.
#'
#' Without shadows there is no noise reference, so no band is drawn and no
#' value is marked detectable or not; the caption says so.
#'
#' When no covariate has a detectable interaction with time, that panel says
#' so in words. The overall time effect, when the source object records one,
#' is reported in the caption: it says whether the trajectory has a shape at
#' all, which the per-covariate interactions cannot.
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
#' @seealso \code{\link{gg_boost_vimp}}, \code{\link{boost_shadow}}
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

  shadow <- object$shadow %||% rep(FALSE, nrow(object))
  has_shadow <- any(shadow)
  n_shadow <- length(unique(as.character(object$variable[shadow])))
  thresholds <- .vimp_shadow_thresholds(object[shadow, , drop = FALSE])
  object <- object[!shadow, , drop = FALSE]

  # Most important at the top: ggplot draws the first factor level at the
  # bottom of a discrete y axis, so the levels run in increasing order.
  by_variable <- tapply(object$importance, as.character(object$variable),
                        max, na.rm = TRUE)
  object$variable <- factor(as.character(object$variable),
                            levels = names(sort(by_variable)))

  if (has_shadow) {
    key <- paste(object$component, object$response)
    band <- thresholds$band[match(key, paste(thresholds$component,
                                             thresholds$response))]
    object$detectable <- !is.na(object$importance) &
      object$importance > band
  } else {
    object$detectable <- !is.na(object$importance)
  }
  object$mark <- factor(
    ifelse(object$detectable, "Detectable", "Within noise band"),
    levels = c("Detectable", "Within noise band")
  )

  metric <- attr(object, "metric") %||% "Importance"
  caption <- .vimp_caption(attr(object, "time.effect"), n_shadow)

  gg_plt <- ggplot2::ggplot(
    object,
    ggplot2::aes(x = .data[["importance"]], y = .data[["variable"]])
  ) +
    ggplot2::geom_rect(
      data = thresholds,
      ggplot2::aes(xmax = .data[["band"]]),
      xmin = -Inf, ymin = -Inf, ymax = Inf, fill = "grey85",
      inherit.aes = FALSE
    ) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey40") +
    ggplot2::geom_segment(
      data = object[object$detectable, , drop = FALSE],
      ggplot2::aes(x = 0, xend = .data[["importance"]],
                   yend = .data[["variable"]])
    ) +
    do.call(ggplot2::geom_point, .vimp_point_args(has_shadow, ...)) +
    ggplot2::scale_shape_manual(
      values = c(`Detectable` = 16, `Within noise band` = 21),
      name = NULL, drop = FALSE
    ) +
    # Pinned, because the stem layer holds only detectable rows and a
    # discrete scale trained on it first would put those variables first.
    ggplot2::scale_y_discrete(limits = levels(object$variable)) +
    ggplot2::labs(x = metric, y = NULL, caption = caption) +
    if (has_shadow) .vimp_none_note(object)

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

# The noise reference for each panel: the largest importance any shadow
# reached in that component and response, floored at zero so a covariate
# must at least make the error worse. Empty when there are no shadows.
.vimp_shadow_thresholds <- function(shadows) {
  if (nrow(shadows) == 0L) {
    return(data.frame(component = factor(), response = factor(),
                      band = numeric()))
  }
  out <- stats::aggregate(
    importance ~ component + response, data = shadows,
    FUN = function(v) max(0, v)
  )
  names(out)[names(out) == "importance"] <- "band"
  out
}

# Caption lines: the overall time effect, and where the band came from.
.vimp_caption <- function(time_effect, n_shadow) {
  lines <- character()
  if (length(time_effect) > 0L && !anyNA(time_effect)) {
    lines <- c(lines, paste0("Overall time effect: ",
                             paste(format(signif(time_effect, 3)),
                                   collapse = ", ")))
  }
  lines <- c(lines, if (n_shadow > 0L) {
    paste0("Band: largest importance of ", n_shadow, " shadow covariates")
  } else {
    "No shadow covariates, so no noise band; see boost_shadow()"
  })
  paste(lines, collapse = "\n")
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

# Defaults for the dot layer, with any argument the caller passes through
# `...` (size, stroke, show.legend, ...) taking precedence. With shadows,
# show.legend = TRUE draws both legend keys even when every value is inside
# the band (drop = FALSE alone keeps the label but draws no symbol). Without
# shadows there is no verdict to explain, so there is no legend.
.vimp_point_args <- function(has_shadow, ...) {
  args <- list(
    mapping = ggplot2::aes(shape = .data[["mark"]]),
    size = 3.5, stroke = 1, fill = "white", show.legend = has_shadow
  )
  dots <- list(...)
  args[names(dots)] <- dots
  args
}
