# The fitted fixture. Read from disk, never refit -- see fixtures/make-fixtures.R.
boost_fixture <- function() {
  readRDS(test_path("fixtures", "boost_continuous.rds"))
}

# A hand-built two-response object. simLong() cannot produce n.q > 1, but
# boostmtree stores err.rate as a LIST and rho/phi/lambda as MATRICES in that
# case, and the extractors must handle both shapes. Only the fields the
# extractors read are populated.
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
      lambda = matrix(seq(10, 80, length.out = m * 2L), nrow = m)
    ),
    class = c("boostmtree", "grow")
  )
}
