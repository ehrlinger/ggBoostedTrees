# The fitted fixture. Read from disk, never refit -- see fixtures/make-fixtures.R.
boost_fixture <- function() {
  readRDS(testthat::test_path("fixtures", "boost_continuous.rds"))
}

# A hand-built two-response object. simLong() cannot produce n.q > 1, but
# boostmtree stores err.rate as a LIST and rho/phi/lambda as MATRICES in that
# case, and the extractors must handle both shapes. Only the fields the
# extractors read are populated.
#
# n.q > 1 is reachable ONLY for family = "nominal" or "ordinal" in the
# boostmtree fork; continuous fits hard-code n.q = 1L. That is why this
# fixture sets family = "nominal" rather than the default continuous family.
# It also omits the third class element real grow objects carry
# ("mtree.pspline.learner"), because nothing under test reads it.
boost_multi_fixture <- function() {
  m <- 4L
  err <- lapply(1:2, function(q) {
    matrix(
      c(seq(1, 0.7, length.out = m), seq(2, 1.4, length.out = m) * q),
      nrow = m, ncol = 2L, dimnames = list(NULL, c("l1", "l2"))
    )
  })
  structure(
    list(
      n.q = 2L,
      q.set = c("lo", "hi"),
      family = "nominal",
      y.sd = 2,
      m.opt = c(2L, 3L),
      err.rate = err,
      rho = matrix(seq(0.1, 0.8, length.out = m * 2L), nrow = m),
      phi = matrix(seq(1, 8, length.out = m * 2L), nrow = m),
      lambda = matrix(seq(10, 80, length.out = m * 2L), nrow = m),
      # Trajectory fields. Per-subject vectors, nested by response exactly as
      # boostmtree nests mu and y.org when n.q > 1. Times are deliberately
      # out of order and contain a duplicate, mirroring what boostmtree
      # actually stores -- the extractor must sort them.
      id.unique = c(101, 102),
      time = list(c(2, 1, 1), c(3, 1)),
      mu = list(
        list(c(0.2, 0.1, 0.1), c(0.3, 0.1)),
        list(c(1.2, 1.1, 1.1), c(1.3, 1.1))
      ),
      y.org = list(
        list(c(0.25, 0.15, 0.05), c(0.35, 0.15)),
        list(c(1.25, 1.15, 1.05), c(1.35, 1.15))
      )
    ),
    class = c("boostmtree", "grow")
  )
}
