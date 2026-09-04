test_that("gg_boost_trajectory returns the documented column contract", {
  gg <- gg_boost_trajectory(boost_fixture())

  expect_s3_class(gg, "gg_boost_trajectory")
  expect_identical(
    names(gg), c("id", "time", "fitted", "observed", "response")
  )
  expect_s3_class(gg$id, "factor")
  expect_type(gg$time, "double")
  expect_type(gg$fitted, "double")
  expect_type(gg$observed, "double")
  expect_s3_class(gg$response, "factor")
})

test_that("one row per observation, not per subject", {
  fit <- boost_fixture()
  gg <- gg_boost_trajectory(fit)

  expect_identical(nrow(gg), sum(lengths(fit$time)))
  expect_identical(nlevels(gg$id), length(fit$id.unique))
})

test_that("rows are sorted by time within each subject", {
  gg <- gg_boost_trajectory(boost_fixture())

  by_subject <- split(gg$time, gg$id)
  expect_false(any(vapply(by_subject, is.unsorted, logical(1))))
})

test_that("subject identifiers come from id.unique", {
  fit <- boost_fixture()
  gg <- gg_boost_trajectory(fit)

  expect_identical(levels(gg$id), as.character(fit$id.unique))
})

test_that("fitted and observed keep their pairing through the sort", {
  fit <- boost_fixture()
  gg <- gg_boost_trajectory(fit)

  # Subject 1 in the fixture has unsorted times, so a sort that moved one
  # column without the others would break this.
  first <- fit$id.unique[1]
  ord <- order(fit$time[[1]])
  rows <- gg[gg$id == as.character(first), ]

  expect_equal(rows$time, fit$time[[1]][ord])
  expect_equal(rows$fitted, fit$mu[[1]][ord])
  expect_equal(rows$observed, fit$y.org[[1]][ord])
})

test_that("a univariate fit is labelled y", {
  gg <- gg_boost_trajectory(boost_fixture())

  expect_identical(levels(gg$response), "y")
})

test_that("a multi-response object yields one block per response", {
  gg <- gg_boost_trajectory(boost_multi_fixture())

  expect_identical(levels(gg$response), c("lo", "hi"))
  expect_identical(nrow(gg), 10L)
  expect_identical(as.integer(table(gg$response)), c(5L, 5L))
})

test_that("observed is NA when the fit records no observed values", {
  fit <- boost_fixture()
  fit$y.org <- NULL
  gg <- gg_boost_trajectory(fit)

  expect_true(all(is.na(gg$observed)))
  expect_false(any(is.na(gg$fitted)))
})

test_that("gg_boost_trajectory errors when the fit records no fitted values", {
  fit <- boost_fixture()
  fit$mu <- NULL

  expect_error(gg_boost_trajectory(fit), "fitted values")
})

test_that("gg_boost_trajectory fails loud on a subject-count mismatch", {
  fit <- boost_fixture()
  fit$time <- fit$time[1:5]

  expect_error(gg_boost_trajectory(fit), "5")
})

test_that("gg_boost_trajectory rejects a non-boostmtree object", {
  expect_error(gg_boost_trajectory(data.frame(x = 1)), "gg_boost_trajectory")
})
