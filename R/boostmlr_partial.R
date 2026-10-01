#' Partial effects from a BoostMLR fit
#'
#' Compute partial effect surfaces for one or more covariates of a
#' `BoostMLR` fit, in a form \code{\link{gg_boost_effect}} accepts.
#'
#' @details
#' `BoostMLR::partial.BoostMLR()` takes one covariate per call and returns a
#' bare list with neither the covariate's name nor the responses' names, so
#' it cannot be told apart from any other list. This wrapper calls it once per
#' covariate with plotting switched off, and records the covariate names and
#' the fit's response names (`y_Names`) alongside the results. It is the
#' `BoostMLR` counterpart of `boostmtree::partial.plot(output = "data")`.
#'
#' Each result holds the raw partial effect (`pList`) and a lowess smooth of
#' it over time (`sList`), as covariate-by-time matrices, one per response.
#' \code{\link{gg_boost_effect}} extracts the smooth.
#'
#' @param object A `BoostMLR` grow object, as returned by
#'   `BoostMLR::BoostMLR()`.
#' @param xvar.names Character vector of covariate names. Defaults to every
#'   covariate in the fit.
#' @param ... Passed to `BoostMLR::partial.BoostMLR()`, for example `n.x`,
#'   `n.tm` or `Mopt`.
#'
#' @return A `boostmlr_partial` object: a list with elements `curves` (one
#'   `partial.BoostMLR()` result per covariate, named by covariate),
#'   `x.var.names` and `response.labels`.
#'
#' @seealso \code{\link{gg_boost_effect}}
#'
#' @examples
#' \donttest{
#' if (requireNamespace("BoostMLR", quietly = TRUE)) {
#'   sim <- BoostMLR::simLong(
#'     n = 20, N = 3, rho = 0.8, model = 1, q_x = 2, q_y = 0
#'   )$dtaL
#'   fit <- BoostMLR::BoostMLR(
#'     x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
#'     M = 50, Verbose = FALSE
#'   )
#'   plot(gg_boost_effect(boostmlr_partial(fit, "x1")))
#' }
#' }
#'
#' @export
boostmlr_partial <- function(object, xvar.names = NULL, ...) {
  if (!inherits(object, "BoostMLR") || !inherits(object, "grow")) {
    stop(
      "boostmlr_partial: expected a BoostMLR grow object; got an object of ",
      "class ", paste(class(object), collapse = "/"), ".",
      call. = FALSE
    )
  }
  if (!requireNamespace("BoostMLR", quietly = TRUE)) {
    stop("boostmlr_partial: the 'BoostMLR' package is required.",
         call. = FALSE)
  }
  xvar.names <- xvar.names %||% object$x_Names
  unknown <- setdiff(xvar.names, object$x_Names)
  if (length(unknown) > 0L) {
    stop(
      "boostmlr_partial: unknown covariate ",
      paste(sQuote(unknown), collapse = ", "), ".",
      call. = FALSE
    )
  }

  curves <- lapply(xvar.names, function(nm) {
    BoostMLR::partial.BoostMLR(
      object, xvar.name = nm, plot.it = FALSE, Verbose = FALSE, ...
    )
  })
  structure(
    list(
      curves = stats::setNames(curves, xvar.names),
      x.var.names = xvar.names,
      response.labels = object$y_Names %||%
        paste0("y", seq_along(curves[[1L]]$sList))
    ),
    class = "boostmlr_partial"
  )
}
