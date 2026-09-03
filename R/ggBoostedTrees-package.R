#' ggBoostedTrees: Visually Exploring Boosted Tree Models
#'
#' Graphic elements for exploring boosted tree models. Each figure is produced
#' in two steps: a `gg_boost_*()` extractor pulls a tidy data frame with a
#' documented column contract out of a fitted model, and `autoplot()` renders
#' that data frame. Adding a new modelling backend means writing extractor
#' methods only.
#'
#' @keywords internal
"_PACKAGE"

#' @importFrom rlang .data
NULL

## boostmtree is declared in Imports to machine-enforce the fork's version
## floor (>= 2.0.1), not because plotting code calls into it: dispatch is by
## S3 class, never by direct call. The @importFrom below exists solely to
## give R CMD check a genuine namespace use so it does not flag the
## dependency as unused -- do not remove it and move boostmtree back to
## Suggests.
#' @importFrom boostmtree boostmtree
NULL
