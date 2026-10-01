#' Variable importance data object
#'
#' Extract variable importance from a \code{\link[boostmtree]{vimp.boostmtree}}
#' object, or from a `BoostMLR` predict object, for both the main effect of
#' each covariate and its interaction with time.
#'
#' @details
#' `boostmtree` reports importance in two parts. The main effect asks what is
#' lost by perturbing a covariate; the interaction asks what is lost by
#' perturbing its interaction with time. For a longitudinal model the second is
#' often the interesting one, since it is where a covariate whose effect
#' *changes* over follow-up shows up.
#'
#' `boostmtree` labels the interaction rows `x1:time`, `x2:time` and so on. The
#' suffix is stripped here, so a variable carries one label across both
#' components and can be compared or dodged against itself.
#'
#' The importance metric is a string on the source object rather than a fixed
#' quantity, so it travels as the `metric` attribute and the renderer uses it to
#' label the axis. The overall time effect has no variable to attach to and
#' travels as the `time.effect` attribute.
#'
#' A joint importance object (`vimp.boostmtree(fit, joint = TRUE)`) reports a
#' single combined value, labelled `joint.vimp`. Note that CRAN `boostmtree`
#' 2.0.0 cannot produce one at all; the patched build this package requires is
#' needed to compute it.
#'
#' `BoostMLR` computes importance inside prediction: pass the object returned
#' by `BoostMLR::predictBoostMLR(fit, x, tm, id, y, importance = TRUE)`, whose
#' `$vimp` holds one matrix per response. `BoostMLR` splits the covariate-time
#' interaction across its overlapping time intervals (columns `Int_Eff.1`,
#' `Int_Eff.2`, ...); these are summed here to one `interaction` value per
#' covariate so the result has the same shape as for `boostmtree`. The
#' per-interval matrices travel unsummed as the `interaction.by.interval`
#' attribute, one per response. The `metric` is `"Standardized VIMP"`, and no
#' `time.effect` is recorded. A joint importance from
#' `BoostMLR::vimp.BoostMLR(joint = TRUE)` is a bare list and is not accepted.
#'
#' @param object A \code{\link[boostmtree]{vimp.boostmtree}} object, or a
#'   `BoostMLR` predict object made with `importance = TRUE`.
#' @param components Character vector naming the components to extract, any of
#'   `"main"` and `"interaction"`. Defaults to both.
#' @param ... Not used; present for S3 consistency.
#'
#' @return A `gg_boost_vimp` `data.frame` with columns:
#'   \describe{
#'     \item{variable}{Factor covariate name.}
#'     \item{importance}{Numeric importance.}
#'     \item{component}{Factor, `main` or `interaction`.}
#'     \item{response}{Factor naming the response.}
#'   }
#'   with attributes `metric` (the importance metric) and `time.effect`, plus
#'   `interaction.by.interval` for `BoostMLR`.
#'
#' @seealso \code{\link{plot.gg_boost_vimp}}, \code{\link{gg_boost_effect}}
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
#' @export
gg_boost_vimp <- function(object, components = c("main", "interaction"), ...) {
  UseMethod("gg_boost_vimp", object)
}

# Only reached for objects that are not vimp results; see gg_boost_error.
#' @export
gg_boost_vimp.default <- function(object,
                                  components = c("main", "interaction"),
                                  ...) {
  stop(
    "gg_boost_vimp: expected a 'vimp.boostmtree' object or a BoostMLR ",
    "predict object; got an object of class ",
    paste(class(object), collapse = "/"),
    ". Produce one with boostmtree::vimp.boostmtree(fit) or ",
    "BoostMLR::predictBoostMLR(fit, x, tm, id, y, importance = TRUE).",
    call. = FALSE
  )
}

#' @export
gg_boost_vimp.vimp.boostmtree <- function(object,
                                          components = c("main", "interaction"),
                                          ...) {
  components <- .boost_vimp_components(components)

  present <- components[vapply(
    components, function(cm) !is.null(object[[cm]]), logical(1)
  )]
  if (length(present) == 0L) {
    stop(
      "gg_boost_vimp: this object records no importance for ",
      paste(sQuote(components), collapse = ", "), ".",
      call. = FALSE
    )
  }

  # Variable labels come from the main matrix when it is present, because the
  # interaction rownames carry a ':time' suffix that must not leak into the
  # factor levels.
  strip_time <- function(x) sub(":time$", "", x)
  reference <- object[[present[1]]]
  var_levels <- strip_time(rownames(reference))

  blocks <- lapply(present, function(cm) {
    mat <- object[[cm]]
    if (ncol(mat) < 1L) {
      stop(
        "gg_boost_vimp: the '", cm, "' component has no response column.",
        call. = FALSE
      )
    }
    variables <- strip_time(rownames(mat))
    if (!identical(variables, var_levels)) {
      stop(
        "gg_boost_vimp: the '", cm, "' component names ", length(variables),
        " variable(s) that do not match the ", length(var_levels),
        " in '", present[1], "'.",
        call. = FALSE
      )
    }
    response_labels <- colnames(mat) %||% (
      if (ncol(mat) == 1L) "y" else paste0("y", seq_len(ncol(mat)))
    )

    do.call(rbind, lapply(seq_len(ncol(mat)), function(q) {
      data.frame(
        variable = factor(variables, levels = var_levels),
        importance = as.numeric(mat[, q]),
        component = factor(cm, levels = present),
        response = factor(response_labels[q], levels = response_labels),
        stringsAsFactors = FALSE
      )
    }))
  })

  gg_dta <- do.call(rbind, blocks)
  rownames(gg_dta) <- NULL
  class(gg_dta) <- c("gg_boost_vimp", class(gg_dta))
  attr(gg_dta, "metric") <- object$metric
  attr(gg_dta, "time.effect") <- object$time.effect
  gg_dta
}

#' @export
gg_boost_vimp.BoostMLR <- function(object,
                                   components = c("main", "interaction"),
                                   ...) {
  components <- .boost_vimp_components(components)
  if (!inherits(object, "predict") || is.null(object$vimp)) {
    stop(
      "gg_boost_vimp: this BoostMLR object records no importance. Pass the ",
      "result of BoostMLR::predictBoostMLR(fit, x, tm, id, y, ",
      "importance = TRUE) rather than the grow object.",
      call. = FALSE
    )
  }
  vimp <- object$vimp
  labels <- names(vimp) %||% object$y_Names %||% paste0("y", seq_along(vimp))
  var_levels <- rownames(vimp[[1L]]) %||% object$x_Names

  # Column 1 is the main effect; the rest split the covariate-time
  # interaction over BoostMLR's overlapping time intervals.
  by_component <- list(
    main = function(mat) mat[, 1L],
    interaction = function(mat) rowSums(mat[, -1L, drop = FALSE])
  )

  gg_dta <- do.call(rbind, lapply(components, function(cm) {
    do.call(rbind, lapply(seq_along(vimp), function(q) {
      mat <- vimp[[q]]
      if (cm == "interaction" && ncol(mat) < 2L) {
        stop(
          "gg_boost_vimp: response '", labels[q], "' records no ",
          "interaction importance.",
          call. = FALSE
        )
      }
      data.frame(
        variable = factor(var_levels, levels = var_levels),
        importance = as.numeric(by_component[[cm]](mat)),
        component = factor(cm, levels = components),
        response = factor(labels[q], levels = labels),
        stringsAsFactors = FALSE
      )
    }))
  }))

  rownames(gg_dta) <- NULL
  class(gg_dta) <- c("gg_boost_vimp", class(gg_dta))
  attr(gg_dta, "metric") <- "Standardized VIMP"
  attr(gg_dta, "interaction.by.interval") <- stats::setNames(
    lapply(vimp, function(mat) mat[, -1L, drop = FALSE]), labels
  )
  gg_dta
}

# Validate `components` against the two importance parts both backends report.
.boost_vimp_components <- function(components) {
  if (!is.character(components) || length(components) == 0L) {
    stop(
      "gg_boost_vimp: 'components' must be a non-empty character vector.",
      call. = FALSE
    )
  }
  components <- unique(components)

  known <- c("main", "interaction")
  unknown <- setdiff(components, known)
  if (length(unknown) > 0L) {
    stop(
      "gg_boost_vimp: unknown component ",
      paste(sQuote(unknown), collapse = ", "),
      ". Expected any of ", paste(sQuote(known), collapse = ", "), ".",
      call. = FALSE
    )
  }
  components
}
