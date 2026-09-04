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

test_that("a BoostMLR predict object is refused", {
  # Predict objects share the "BoostMLR" class and even carry an Error_Rate,
  # but it is test error and the object records a real Mopt this extractor
  # would otherwise discard. Built by hand from the grow fixture -- no
  # prediction is computed.
  f <- boostmlr_fixture()
  class(f) <- c("BoostMLR", "predict")

  expect_error(gg_boost_error(f), "grow")
})

test_that("use.rmse is refused positionally too", {
  # The generic declares use.rmse as its second formal, so positional use is
  # valid API syntax. Detecting only a NAMED entry in ... let the positional
  # form through: the caller asked for a different scale and silently got the
  # standardized values back.
  expect_error(
    gg_boost_error(boostmlr_fixture(), FALSE),
    "use.rmse"
  )
})

test_that("use.rmse is refused on the BoostMLR path", {
  expect_error(
    gg_boost_error(boostmlr_fixture(), use.rmse = FALSE),
    "y\\.sd"
  )
})

test_that("use.rmse = TRUE is accepted on the BoostMLR path", {
  # TRUE is the generic's default and names the scale BoostMLR already
  # returns, so the explicit spelling of the default must not be an error.
  # Refusing it broke backend-agnostic calling, which is the one thing the
  # tidy intermediate exists to promise.
  f <- boostmlr_fixture()

  expect_identical(gg_boost_error(f, use.rmse = TRUE), gg_boost_error(f))
  expect_identical(gg_boost_error(f, TRUE), gg_boost_error(f))
})

test_that("a mixed list of fits maps over gg_boost_error with use.rmse", {
  # The shape that broke: a wrapper that always passes the argument
  # explicitly, over fits from both backends.
  fits <- list(boost_fixture(), boostmlr_fixture())

  out <- lapply(fits, gg_boost_error, use.rmse = TRUE)

  expect_length(out, 2L)
  expect_true(all(vapply(out, inherits, logical(1), "gg_boost_error")))
})

test_that("gg_boost_error output rbinds across backends unchanged", {
  # Nothing else binds the two backends' outputs together; a type or
  # column-order difference would otherwise surface only when a user facets
  # or rbind()s them.
  gg_tree <- gg_boost_error(boost_fixture())
  gg_mlr <- gg_boost_error(boostmlr_fixture())

  combined <- rbind(gg_tree, gg_mlr)

  expect_identical(nrow(combined), nrow(gg_tree) + nrow(gg_mlr))
  expect_identical(names(combined), names(gg_tree))
  expect_identical(names(combined), names(gg_mlr))
  expect_identical(vapply(combined, class, character(1)),
                   vapply(gg_tree, class, character(1)))
})

test_that("the BoostMLR error plot draws with no optimal rule", {
  p <- ggplot2::autoplot(gg_boost_error(boostmlr_fixture()))

  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_true("GeomLine" %in% geoms)
  expect_false("GeomVline" %in% geoms)
})
