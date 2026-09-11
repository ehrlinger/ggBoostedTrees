test_that("gg_boost_calibration returns the documented column contract", {
  gg <- gg_boost_calibration(boost_fixture())

  expect_s3_class(gg, "gg_boost_calibration")
  expect_identical(
    names(gg),
    c("response", "bin", "time_lo", "time_hi", "time", "n_obs",
      "n_subject", "observed", "observed_lo", "observed_hi", "fitted")
  )
  expect_s3_class(gg$response, "factor")
  expect_s3_class(gg$bin, "factor")
  expect_type(gg$time, "double")
  expect_type(gg$n_obs, "integer")
  expect_type(gg$n_subject, "integer")
  expect_type(gg$observed, "double")
  expect_type(gg$fitted, "double")
})

test_that("every observation lands in exactly one bin", {
  gg <- gg_boost_calibration(boost_fixture())

  expect_identical(sum(gg$n_obs), 189L)
  expect_true(all(gg$n_subject <= 25L))
  expect_identical(nrow(gg), 10L)
})

test_that("bins are ordered by time and have positive width", {
  gg <- gg_boost_calibration(boost_fixture())

  expect_false(is.unsorted(gg$time_lo))
  expect_true(all(gg$time_lo < gg$time_hi))
  expect_identical(levels(gg$bin), as.character(gg$bin))
})

test_that("bin means match a hand computation", {
  fit <- boost_fixture()
  gg <- gg_boost_calibration(fit, breaks = c(0, 1, 2, 3))

  tm <- unlist(fit$time)
  y <- unlist(fit$y.org)
  mu <- unlist(fit$mu)
  # Right-closed bins, the lowest closed on the left too.
  groups <- list(tm <= 1, tm > 1 & tm <= 2, tm > 2)

  expect_identical(nrow(gg), 3L)
  expect_equal(gg$observed, vapply(groups, function(g) mean(y[g]), 0))
  expect_equal(gg$fitted, vapply(groups, function(g) mean(mu[g]), 0))
  expect_identical(gg$n_obs, vapply(groups, sum, 0L))
})

test_that("the interval is mean +/- 1.96 standard errors", {
  fit <- boost_fixture()
  gg <- gg_boost_calibration(fit, breaks = c(0, 1, 2, 3))

  tm <- unlist(fit$time)
  y <- unlist(fit$y.org)[tm <= 1]
  half <- 1.96 * sd(y) / sqrt(length(y))

  expect_equal(gg$observed_lo[1], mean(y) - half)
  expect_equal(gg$observed_hi[1], mean(y) + half)
})

test_that("tied times merge quantile bins and say so", {
  expect_message(
    gg <- gg_boost_calibration(boost_tied_fixture(), n_bins = 4),
    "tied times left 2 of 4 bins"
  )
  expect_identical(nrow(gg), 2L)
  expect_identical(gg$n_obs, c(9L, 3L))
  expect_equal(gg$time_hi, c(5.25, 8))
})

test_that("a single-observation bin gets NA interval bounds", {
  gg <- gg_boost_calibration(boost_tied_fixture(), breaks = c(0, 7.5, 8))

  expect_identical(gg$n_obs[2], 1L)
  expect_true(is.na(gg$observed_lo[2]))
  expect_true(is.na(gg$observed_hi[2]))
})

test_that("breaks override n_bins and drop out-of-range rows loudly", {
  expect_message(
    gg <- gg_boost_calibration(boost_tied_fixture(), breaks = c(0, 6)),
    "dropped 2 observation"
  )
  expect_identical(sum(gg$n_obs), 10L)
})

test_that("a fit with no observed values is refused", {
  obj <- boost_tied_fixture()
  obj$y.org <- NULL

  expect_error(gg_boost_calibration(obj), "no observed values")
})

test_that("all observations outside breaks is an error", {
  expect_error(
    suppressMessages(
      gg_boost_calibration(boost_tied_fixture(), breaks = c(10, 20))
    ),
    "fall within the range of `breaks`"
  )
})

test_that("a response with no complete rows is an error naming it", {
  obj <- boostmlr_fixture()
  obj$y[, 2] <- NA

  expect_error(
    suppressMessages(gg_boost_calibration(obj)),
    "response 'y2' has no rows with both"
  )
})

test_that("an empty middle bin from breaks is dropped", {
  gg <- gg_boost_calibration(
    boost_tied_fixture(), breaks = c(0, 1, 4, 8)
  )

  expect_identical(nrow(gg), 2L)
  expect_identical(gg$n_obs, c(8L, 4L))
  expect_equal(gg$time_lo, c(0, 4))
  expect_equal(gg$time_hi, c(1, 8))
})

test_that("n_bins and breaks are validated", {
  fit <- boost_fixture()

  expect_error(gg_boost_calibration(fit, n_bins = 0), "n_bins")
  expect_error(gg_boost_calibration(fit, n_bins = 2.5), "n_bins")
  expect_error(gg_boost_calibration(fit, n_bins = c(2, 3)), "n_bins")
  expect_error(gg_boost_calibration(fit, n_bins = Inf), "n_bins")
  expect_error(gg_boost_calibration(fit, breaks = "a"), "breaks")
  expect_error(gg_boost_calibration(fit, breaks = c(1, 1)), "breaks")
})

test_that("a foreign object is refused by name", {
  expect_error(
    gg_boost_calibration(data.frame(x = 1)), "gg_boost_calibration"
  )
})

test_that("a predict object passed as object is refused", {
  expect_error(
    gg_boost_calibration(boost_predict_fixture()), "Pass a predict object"
  )
})

test_that("a BoostMLR fit yields one block of bins per response", {
  gg <- suppressMessages(gg_boost_calibration(boostmlr_fixture()))

  expect_identical(levels(gg$response), c("y1", "y2", "y3"))
  expect_true(all(table(gg$response) > 0L))
  expect_identical(sum(gg$n_obs), 390L)
})

test_that("a BoostMLR fit refuses a cohort curve", {
  expect_error(
    gg_boost_calibration(boostmlr_fixture(), pred = boost_predict_fixture()),
    "boostmtree fits only"
  )
})

test_that("no pred means no cohort attribute", {
  expect_null(attr(gg_boost_calibration(boost_fixture()), "cohort"))
})

test_that("the cohort curve is the mean predicted curve", {
  pred <- boost_predict_fixture()
  gg <- gg_boost_calibration(boost_fixture(), pred = pred)
  cohort <- attr(gg, "cohort")

  expect_identical(names(cohort), c("response", "time", "fitted"))
  expect_s3_class(cohort$response, "factor")
  expect_equal(cohort$time, sort(pred$time[[1]]))
  # One column per subject, rows are grid times.
  expect_equal(cohort$fitted, rowMeans(do.call(cbind, pred$mu)))
})

test_that("a pred of the wrong class is refused", {
  expect_error(
    gg_boost_calibration(boost_fixture(), pred = list(a = 1)),
    "must be a boostmtree predict object"
  )
})

test_that("a pred with a different response count is refused", {
  pred <- boost_predict_fixture()
  pred$n.q <- 2L

  expect_error(
    gg_boost_calibration(boost_fixture(), pred = pred),
    "records 2 response"
  )
})

test_that("a pred on subject-specific times is refused", {
  pred <- boost_predict_fixture()
  # What predict() produces when given tm and id: ragged time vectors.
  pred$time[[1]] <- pred$time[[1]][-1]
  pred$mu[[1]] <- pred$mu[[1]][-1]

  expect_error(
    gg_boost_calibration(boost_fixture(), pred = pred),
    "without `tm` and `id`"
  )
})

test_that("fitted values all NA are refused with their own cause", {
  obj <- boost_tied_fixture()
  obj$mu <- lapply(obj$mu, function(v) rep(NA_real_, length(v)))

  expect_error(
    gg_boost_calibration(obj), "no rows with both an observed and a fitted"
  )
})

test_that("a pred with different response labels is refused", {
  pred <- boost_predict_fixture()
  pred$q.set <- "other"

  expect_error(
    gg_boost_calibration(boost_fixture(), pred = pred),
    "labels its response"
  )
})
