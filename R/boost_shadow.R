#' Add shadow covariates before fitting
#'
#' Append permuted copies of every covariate to a `boostmtree` design, so that
#' variable importance has a noise reference measured in the same fit.
#'
#' @details
#' Variable importance from \code{\link[boostmtree]{vimp.boostmtree}} has no
#' fixed scale. How much a covariate with no signal scores depends on the
#' fit: the more boosting, the more the trees lean on noise, and the higher
#' every importance climbs. A shadow is a copy of a covariate whose values
#' have been shuffled between subjects, so it keeps the covariate's
#' distribution but carries no information about the response. Fitted
#' alongside the real covariates, the shadows show what noise scores in this
#' fit. \code{\link{autoplot.gg_boost_vimp}} draws the largest shadow
#' importance as a band, and reads a covariate as detectable only when it
#' clears that band.
#'
#' More shadows make the band stricter, because the largest of more noise
#' scores is higher. The band is a reference measured in the fit, not a test
#' with a known error rate. Each copy shuffles the subjects once for every
#' covariate, so the shadows keep the covariates' correlations with each
#' other; and a covariate with no effect of its own can clear the band when
#' it is correlated with one that has an effect. Each shadow widens `x` by
#' one column and slows the fit in proportion.
#'
#' \strong{A verdict near the band's edge needs repeated runs.} The band and
#' the importances both move from run to run, and a refit moves them as much
#' as a rerun of \code{\link[boostmtree]{vimp.boostmtree}} on the same fit.
#' In one simulation (100 subjects, 5 shadow copies, 50 seeds), strong
#' effects cleared the band in 98 to 100% of runs and true nulls in 0 to
#' 6%. Small or borderline effects cleared it in only 14 to 46%. That is one
#' design at one sample size; other sizes were not measured. Before reporting
#' a covariate close to the band, refit and rerun the importance under
#' several seeds, and report how often it clears the band.
#'
#' Values are shuffled between subjects, not between rows, so each shadow is
#' constant within a subject, as a baseline covariate is. Covariates must
#' therefore be constant within subject; a time-varying covariate has no
#' subject-level value to shuffle and is refused.
#'
#' Shadows are named `shadow1.<covariate>`, `shadow2.<covariate>`, and so on;
#' \code{\link{gg_boost_vimp}} recognises them by that name. The shuffle uses
#' R's random number generator, so call \code{set.seed()} first for a
#' reproducible design.
#'
#' @param x A `data.frame` of covariates, one row per observation, as passed
#'   to \code{\link[boostmtree]{boostmtree}}.
#' @param id Subject identifier for each row of `x`.
#' @param k Number of shadow copies of each covariate. Defaults to 5.
#'
#' @return `x` with `ncol(x) * k` shadow columns appended.
#'
#' @seealso \code{\link{gg_boost_vimp}}, \code{\link{autoplot.gg_boost_vimp}}
#'
#' @examples
#' sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
#' set.seed(1)
#' x <- boost_shadow(sim$features, sim$id, k = 2)
#' names(x)
#'
#' @export
boost_shadow <- function(x, id, k = 5) {
  if (!is.data.frame(x) || ncol(x) == 0L) {
    stop("boost_shadow: 'x' must be a data.frame with at least one column.",
         call. = FALSE)
  }
  if (length(id) != nrow(x)) {
    stop("boost_shadow: 'id' has ", length(id), " value(s) but 'x' has ",
         nrow(x), " row(s).", call. = FALSE)
  }
  if (!is.numeric(k) || length(k) != 1L || is.na(k) || k < 1 ||
        k != round(k)) {
    stop("boost_shadow: 'k' must be a single positive whole number.",
         call. = FALSE)
  }
  taken <- names(x)[.is_shadow(names(x))]
  if (length(taken) > 0L) {
    stop("boost_shadow: 'x' already has shadow-named column(s) ",
         paste(sQuote(taken), collapse = ", "), ".", call. = FALSE)
  }

  first <- !duplicated(id)
  subject_rows <- match(id, id[first])
  subjects <- x[first, , drop = FALSE]

  # A shadow is a subject-level shuffle, so every covariate must have one
  # value per subject. Values are compared, not attributes: subsetting drops
  # a column's label, so a labeled column would never equal its own subset.
  varying <- names(x)[vapply(names(x), function(v) {
    !identical(as.vector(x[[v]]), as.vector(subjects[[v]][subject_rows]))
  }, logical(1))]
  if (length(varying) > 0L) {
    stop("boost_shadow: covariate(s) ",
         paste(sQuote(varying), collapse = ", "),
         " vary within subject; shadows need one value per subject.",
         call. = FALSE)
  }

  shadows <- lapply(seq_len(k), function(j) {
    shuffled <- subjects[sample.int(nrow(subjects)), , drop = FALSE]
    shuffled <- shuffled[subject_rows, , drop = FALSE]
    names(shuffled) <- paste0("shadow", j, ".", names(x))
    shuffled
  })
  out <- do.call(cbind, c(list(x), shadows))
  # Copied as an attribute: rownames<- would turn default integer row names
  # into strings, so the original columns would no longer equal `x`.
  attr(out, "row.names") <- attr(x, "row.names")
  out
}

# TRUE for a name boost_shadow() gives its columns (shadow1.x1, ...);
# gg_boost_vimp() reads them back with this.
.is_shadow <- function(names) {
  grepl("^shadow[0-9]+\\.", names)
}
