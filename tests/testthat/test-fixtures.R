test_that("the committed fixture is a cv.flag boostmtree grow object", {
  fit <- boost_fixture()

  expect_s3_class(fit, "boostmtree")
  expect_identical(class(fit)[2], "grow")
  expect_false(is.null(fit$err.rate))
  expect_identical(colnames(fit$err.rate), c("l1", "l2"))
  expect_identical(nrow(fit$err.rate), 50L)
})

test_that("the fixture has an interior optimal iteration", {
  fit <- boost_fixture()

  # An m.opt pinned at 1 or at M would make the `optimal` column untestable.
  expect_gt(fit$m.opt, 1L)
  expect_lt(fit$m.opt, 50L)
})

test_that("fixture provenance is recorded", {
  txt <- readLines(test_path("fixtures", "boost_continuous.dcf"))

  expect_true(any(grepl("^Backend: boostmtree", txt)))
  expect_true(any(grepl("cv.flag = TRUE", txt, fixed = TRUE)))
})

test_that("the multi-response helper builds the shapes it claims to", {
  obj <- boost_multi_fixture()

  expect_true(is.list(obj$err.rate))
  expect_length(obj$err.rate, 2L)
  expect_true(is.matrix(obj$rho))
  expect_identical(ncol(obj$rho), 2L)
})

test_that("the multi-response helper carries nested trajectory fields", {
  obj <- boost_multi_fixture()

  expect_length(obj$time, 2L)
  expect_length(obj$mu, 2L)
  expect_true(is.list(obj$mu[[1]]))
  expect_identical(lengths(obj$time), lengths(obj$mu[[1]]))
  expect_true(is.unsorted(obj$time[[1]]))
})
