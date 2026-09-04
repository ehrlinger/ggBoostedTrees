test_that("gg_boost_error returns the documented column contract", {
  gg <- gg_boost_error(boost_fixture())

  expect_s3_class(gg, "gg_boost_error")
  expect_s3_class(gg, "data.frame")
  expect_identical(names(gg), c("iteration", "value", "response", "optimal"))
  expect_type(gg$iteration, "integer")
  expect_type(gg$value, "double")
  expect_s3_class(gg$response, "factor")
  expect_type(gg$optimal, "logical")
})

test_that("gg_boost_error returns one row per boosting iteration", {
  fit <- boost_fixture()
  gg <- gg_boost_error(fit)

  expect_identical(nrow(gg), 50L)
  expect_identical(gg$iteration, 1:50)
})

test_that("gg_boost_error takes values from the l2 column", {
  fit <- boost_fixture()
  gg <- gg_boost_error(fit)

  expect_equal(gg$value, unname(fit$err.rate[, "l2"]))
})

test_that("use.rmse = FALSE returns the unstandardized squared error", {
  fit <- boost_fixture()
  gg <- gg_boost_error(fit, use.rmse = FALSE)

  expect_equal(gg$value, unname((fit$err.rate[, "l2"] * fit$y.sd)^2))
})

test_that("optimal marks exactly the m.opt iteration", {
  fit <- boost_fixture()
  gg <- gg_boost_error(fit)

  expect_identical(sum(gg$optimal), 1L)
  expect_identical(gg$iteration[gg$optimal], as.integer(fit$m.opt))
})

test_that("a univariate fit is labelled y", {
  gg <- gg_boost_error(boost_fixture())

  expect_identical(levels(gg$response), "y")
})

test_that("a multi-response object yields one block per response", {
  gg <- gg_boost_error(boost_multi_fixture())

  expect_identical(nrow(gg), 8L)
  expect_identical(levels(gg$response), c("lo", "hi"))
  expect_identical(sum(gg$optimal), 2L)
})

test_that("gg_boost_error rejects a fit without cv.flag", {
  fit <- boost_fixture()
  fit$err.rate <- NULL

  expect_error(gg_boost_error(fit), "cv.flag")
})

test_that("gg_boost_error rejects a non-boostmtree object", {
  expect_error(gg_boost_error(data.frame(x = 1)), "gg_boost_error")
})

test_that("gg_boost_error errors on an err.rate/n.q shape mismatch", {
  fit <- boost_multi_fixture()
  fit$err.rate <- fit$err.rate[[1]]

  expect_error(gg_boost_error(fit), "n\\.q")
})

test_that("a BoostMLR fit yields the error contract", {
  f <- boostmlr_fixture()
  gg <- gg_boost_error(f)

  expect_s3_class(gg, "gg_boost_error")
  expect_identical(
    names(gg), c("iteration", "value", "response", "optimal")
  )
  expect_identical(nrow(gg), as.integer(f$M) * length(f$y_Names))
  expect_identical(levels(gg$response), f$y_Names)
})

test_that("BoostMLR error values come from Error_Rate", {
  f <- boostmlr_fixture()
  gg <- gg_boost_error(f)

  expect_equal(gg$value[gg$response == "y2"], unname(f$Error_Rate[, 2]))
})

test_that("optimal is all FALSE because BoostMLR selects no iteration", {
  gg <- gg_boost_error(boostmlr_fixture())

  # Deriving argmin here would label a computation the backend never did as
  # "the optimal iteration".
  expect_false(any(gg$optimal))
})

test_that("the BoostMLR error plot draws with no optimal rule", {
  p <- ggplot2::autoplot(gg_boost_error(boostmlr_fixture()))

  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_true("GeomLine" %in% geoms)
  expect_false("GeomVline" %in% geoms)
})
