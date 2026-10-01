test_that("boostmlr_partial refuses a non-BoostMLR object", {
  expect_error(boostmlr_partial(boost_fixture()), "BoostMLR grow object")
})

test_that("boostmlr_partial refuses an unknown covariate", {
  skip_if_not_installed("BoostMLR")
  expect_error(boostmlr_partial(boostmlr_fixture(), "nope"), "unknown")
})

test_that("boostmlr_partial names covariates and responses", {
  skip_on_cran()
  skip_if_not_installed("BoostMLR")
  fit <- boostmlr_fixture()
  bp <- boostmlr_partial(fit, "x1", n.x = 5, n.tm = 4)

  expect_s3_class(bp, "boostmlr_partial")
  expect_identical(names(bp$curves), "x1")
  expect_identical(bp$response.labels, fit$y_Names)
  expect_length(bp$curves$x1$sList, length(fit$y_Names))

  gg <- gg_boost_effect(bp)
  expect_identical(nlevels(gg$response), length(fit$y_Names))
})
