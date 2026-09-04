# Return the left operand unless it is NULL. Mirrors the helper boostmtree
# uses internally, so ported extraction logic reads the same as its source.
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

# Every extractor front-door calls this so that a wrong object type produces
# one consistent message naming the function the user actually called.
.boost_check_grow <- function(object, call_name) {
  if (!inherits(object, "boostmtree")) {
    stop(
      call_name, ": expected a 'boostmtree' object; got an object of class ",
      paste(class(object), collapse = "/"), ".",
      call. = FALSE
    )
  }
  invisible(object)
}

# Every renderer front-door calls this so that a wrong object type produces
# one consistent message naming the class the renderer expects.
.boost_check_gg <- function(object, class_name) {
  if (!inherits(object, class_name)) {
    stop("Incorrect object type: expected a ", class_name, " object.",
         call. = FALSE)
  }
  invisible(object)
}

# BoostMLR predict objects share the "BoostMLR" class with grow objects and
# carry some of the same fields, so dispatch alone does not distinguish them.
# They are deliberately unsupported: their Error_Rate is test error, and they
# record an Mopt that these extractors would otherwise silently discard.
.boost_check_mlr_grow <- function(object, call_name) {
  if (!inherits(object, "grow")) {
    stop(
      call_name, ": expected a BoostMLR 'grow' object; got an object of ",
      "class ", paste(class(object), collapse = "/"), ". BoostMLR predict ",
      "objects are not supported.",
      call. = FALSE
    )
  }
  invisible(object)
}

# Pivot a BoostMLR M-by-response matrix into long form. BoostMLR stores
# Error_Rate, Rho and Phi identically, so the three extractions differ only in
# which matrix they read and what they call the value.
.boost_mlr_long <- function(mat, labels, call_name) {
  mat <- as.matrix(mat)
  if (ncol(mat) != length(labels)) {
    stop(
      call_name, ": the fit names ", length(labels), " response(s) but ",
      "records ", ncol(mat), " column(s).",
      call. = FALSE
    )
  }
  do.call(rbind, lapply(seq_len(ncol(mat)), function(q) {
    data.frame(
      iteration = seq_len(nrow(mat)),
      value = as.numeric(mat[, q]),
      response = factor(labels[q], levels = labels),
      stringsAsFactors = FALSE
    )
  }))
}

# Labels for the `response` column. boostmtree records q.set as NA for a
# univariate fit, so a single response is labelled "y" rather than "NA".
.boost_response_labels <- function(object) {
  n_q <- object$n.q %||% 1L
  q_set <- object$q.set
  if (is.null(q_set) || all(is.na(q_set))) {
    if (n_q == 1L) {
      return("y")
    }
    return(paste0("y", seq_len(n_q)))
  }
  as.character(q_set)
}
