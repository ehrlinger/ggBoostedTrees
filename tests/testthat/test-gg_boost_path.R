test_that("gg_boost_path returns the documented column contract", {
  gg <- gg_boost_path(boost_fixture())

  expect_s3_class(gg, "gg_boost_path")
  expect_identical(names(gg), c("iteration", "value", "parameter", "response"))
  expect_type(gg$iteration, "integer")
  expect_type(gg$value, "double")
  expect_s3_class(gg$parameter, "factor")
  expect_s3_class(gg$response, "factor")
})

test_that("all three parameters are returned by default", {
  gg <- gg_boost_path(boost_fixture())

  expect_identical(levels(gg$parameter), c("rho", "phi", "lambda"))
  expect_identical(nrow(gg), 150L)
})

test_that("parameters can be selected", {
  gg <- gg_boost_path(boost_fixture(), parameters = "rho")

  expect_identical(levels(gg$parameter), "rho")
  expect_identical(nrow(gg), 50L)
})

test_that("values match the fitted parameter paths", {
  fit <- boost_fixture()
  gg <- gg_boost_path(fit, parameters = "phi")

  expect_equal(gg$value, as.numeric(fit$phi))
})

test_that("matrix-valued paths are split by response", {
  gg <- gg_boost_path(boost_multi_fixture(), parameters = "rho")

  expect_identical(nrow(gg), 8L)
  expect_identical(levels(gg$response), c("lo", "hi"))
  expect_identical(as.integer(table(gg$response)), c(4L, 4L))
})

test_that("an absent parameter is dropped rather than erroring", {
  fit <- boost_fixture()
  fit$lambda <- NULL
  gg <- gg_boost_path(fit)

  expect_identical(levels(gg$parameter), c("rho", "phi"))
})

test_that("gg_boost_path errors when no requested parameter is present", {
  fit <- boost_fixture()
  fit$rho <- NULL
  fit$phi <- NULL
  fit$lambda <- NULL

  expect_error(gg_boost_path(fit), "no parameter paths")
})

test_that("gg_boost_path rejects an unknown parameter name", {
  expect_error(gg_boost_path(boost_fixture(), parameters = "sigma"), "sigma")
})

test_that("duplicate parameters are de-duplicated rather than erroring", {
  gg <- gg_boost_path(boost_fixture(), parameters = c("rho", "rho"))

  expect_identical(levels(gg$parameter), "rho")
  expect_identical(nrow(gg), 50L)
})

test_that("gg_boost_path rejects an empty parameters vector", {
  expect_error(
    gg_boost_path(boost_fixture(), parameters = character(0)),
    "non-empty"
  )
})

test_that("gg_boost_path rejects a non-boostmtree object", {
  expect_error(gg_boost_path(data.frame(x = 1)), "gg_boost_path")
})

test_that("gg_boost_path errors on a path/n.q shape mismatch", {
  fit <- boost_multi_fixture()
  fit$rho <- matrix(fit$rho[, 1], ncol = 1L)

  expect_error(gg_boost_path(fit, parameters = "rho"), "rho")
})

test_that("a BoostMLR fit yields rho and phi paths", {
  f <- boostmlr_fixture()
  gg <- gg_boost_path(f)

  expect_identical(
    names(gg), c("iteration", "value", "parameter", "response")
  )
  expect_identical(levels(gg$parameter), c("rho", "phi"))
  expect_identical(nrow(gg), as.integer(f$M) * length(f$y_Names) * 2L)
})

test_that("BoostMLR path values come from Rho and Phi", {
  f <- boostmlr_fixture()
  gg <- gg_boost_path(f)

  expect_equal(
    gg$value[gg$parameter == "rho" & gg$response == "y1"],
    unname(f$Rho[, 1])
  )
  expect_equal(
    gg$value[gg$parameter == "phi" & gg$response == "y3"],
    unname(f$Phi[, 3])
  )
})

test_that("requesting lambda from a BoostMLR fit is refused with a reason", {
  # BoostMLR's Lambda_List holds per-iteration basis coefficients, not a
  # scalar smoothing parameter per response, so it is not the same quantity.
  expect_error(
    gg_boost_path(boostmlr_fixture(), parameters = "lambda"),
    "lambda"
  )
})
