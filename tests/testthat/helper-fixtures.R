# The fitted fixture. Read from disk, never refit. See the generator under
# the fixtures directory for how it was produced.
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

# Interpretation fixtures. Read from disk, never recomputed -- partial.plot()
# costs seconds per variable. See fixtures/make-fixtures.R.
vimp_fixture <- function() {
  readRDS(testthat::test_path("fixtures", "vimp_marginal.rds"))
}

vimp_joint_fixture <- function() {
  readRDS(testthat::test_path("fixtures", "vimp_joint.rds"))
}

partial_fixture <- function() {
  readRDS(testthat::test_path("fixtures", "effect_partial.rds"))
}

marginal_fixture <- function() {
  readRDS(testthat::test_path("fixtures", "effect_marginal.rds"))
}

# Effect fixtures whose covariate is a two-level factor. boostmtree returns a
# character x column for these, one row per level.
partial_factor_fixture <- function() {
  readRDS(testthat::test_path("fixtures", "effect_partial_factor.rds"))
}

marginal_factor_fixture <- function() {
  readRDS(testthat::test_path("fixtures", "effect_marginal_factor.rds"))
}

# The BoostMLR grow object. Read from disk, never refit. BoostMLR stores the
# same information as boostmtree in a flat layout: mu and y are
# observation-by-response matrices, tm and id flat vectors.
boostmlr_fixture <- function() {
  readRDS(testthat::test_path("fixtures", "boostmlr_grow.rds"))
}

# The slimmed predict object: predict(fit, x = fit$x) on the committed fit,
# keeping only the fields gg_boost_trajectory() reads. Every subject shares
# one 15-point time grid. See fixtures/make-fixtures.R.
boost_predict_fixture <- function() {
  readRDS(testthat::test_path("fixtures", "boost_predict.rds"))
}

# A hand-built fit whose times are mostly tied at 0, as echoes at discharge
# are in clinical data. Eight of twelve observations sit at time 0, so the
# quantile edges collapse. Four bins requested give two:
# [0, 5.25] with 9 observations and (5.25, 8] with 3.
boost_tied_fixture <- function() {
  structure(
    list(
      n.q = 1L,
      q.set = NA,
      id.unique = 1:4,
      time = list(c(0, 0, 0, 5), c(0, 0, 6), c(0, 0, 7), c(0, 8)),
      mu = list(c(1, 1, 1, 2), c(1, 1, 3), c(1, 1, 4), c(1, 5)),
      y.org = list(c(1, 2, 3, 2), c(1, 2, 3), c(2, 1, 4), c(1, 5))
    ),
    class = c("boostmtree", "grow")
  )
}
