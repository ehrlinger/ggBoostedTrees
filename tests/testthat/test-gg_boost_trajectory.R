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

  # Checked across every subject (not one hand-picked index) so the
  # assertion has teeth regardless of which subjects happen to have
  # constant vs. varying mu, and survives the fixture being regenerated.
  for (i in seq_along(fit$id.unique)) {
    id <- as.character(fit$id.unique[i])
    ord <- order(fit$time[[i]])
    rows <- gg[gg$id == id, ]

    expect_equal(rows$time, fit$time[[i]][ord])
    expect_equal(rows$fitted, fit$mu[[i]][ord])
    expect_equal(rows$observed, fit$y.org[[i]][ord])
  }
})

test_that("fitted and observed keep their pairing across nested responses", {
  gg <- gg_boost_trajectory(boost_multi_fixture())
  fit <- boost_multi_fixture()

  for (q in seq_len(fit$n.q)) {
    response <- levels(gg$response)[q]
    for (i in seq_along(fit$id.unique)) {
      id <- as.character(fit$id.unique[i])
      ord <- order(fit$time[[i]])
      rows <- gg[gg$response == response & gg$id == id, ]

      expect_equal(rows$time, fit$time[[i]][ord])
      expect_equal(rows$fitted, fit$mu[[q]][[i]][ord])
      expect_equal(rows$observed, fit$y.org[[q]][[i]][ord])
    }
  }
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

test_that("gg_boost_trajectory fails loud on an observed-length mismatch", {
  fit <- boost_fixture()
  fit$y.org[[1]] <- fit$y.org[[1]][1:3]

  expect_error(gg_boost_trajectory(fit), "observed value")
})

test_that("gg_boost_trajectory fails loud on a response-count mismatch in mu", {
  fit <- boost_multi_fixture()
  fit$mu <- fit$mu[1]

  expect_error(gg_boost_trajectory(fit), "n.q")
})

test_that("gg_boost_trajectory fails loud with no subjects", {
  fit <- boost_fixture()
  fit$time <- list()
  fit$id.unique <- fit$id.unique[0]
  fit$mu <- fit$mu[0]
  fit$y.org <- fit$y.org[0]

  expect_error(gg_boost_trajectory(fit), "gg_boost_trajectory")
})

test_that("a BoostMLR fit yields the same contract as a boostmtree fit", {
  gg <- gg_boost_trajectory(boostmlr_fixture())

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

test_that("one row per observation per response", {
  f <- boostmlr_fixture()
  gg <- gg_boost_trajectory(f)

  expect_identical(nrow(gg), length(f$tm) * ncol(f$mu))
  expect_identical(levels(gg$response), f$y_Names)
})

test_that("response labels come from y_Names, not mu colnames", {
  f <- boostmlr_fixture()
  gg <- gg_boost_trajectory(f)

  # mu carries no column names at all, so a label taken from there would be NA.
  expect_null(colnames(f$mu))
  expect_identical(levels(gg$response), c("y1", "y2", "y3"))
})

test_that("fitted and observed come from the matching response column", {
  f <- boostmlr_fixture()
  gg <- gg_boost_trajectory(f)

  rows <- gg[gg$response == "y2", ]
  # Matches the extractor's own ordering: subjects by first appearance in
  # id (via match()), not by sorted id value -- these agree only by
  # coincidence when the fixture's ids happen to arrive ascending.
  id_levels <- unique(as.character(f$id))
  ord <- order(match(as.character(f$id), id_levels), f$tm)
  expect_equal(rows$fitted, unname(f$mu[ord, 2]))
  expect_equal(rows$observed, unname(f$y[ord, 2]))
})

test_that("a BoostMLR predict object is refused", {
  f <- boostmlr_fixture()
  class(f) <- c("BoostMLR", "predict")

  expect_error(gg_boost_trajectory(f), "grow")
})

test_that("a y/mu dimension mismatch is refused rather than silently misaligned", {
  f <- boostmlr_fixture()
  # Fewer rows in y than mu would otherwise silently subset to the wrong
  # rows via as.matrix() recycling/truncation rather than erroring.
  f$y <- f$y[seq_len(nrow(f$y) - 1L), , drop = FALSE]

  expect_error(gg_boost_trajectory(f), "dimensions")
})

test_that("rows are sorted by time within subject", {
  gg <- gg_boost_trajectory(boostmlr_fixture())

  by_subject <- split(gg$time, list(gg$id, gg$response), drop = TRUE)
  expect_false(any(vapply(by_subject, is.unsorted, logical(1))))
})

test_that("the BoostMLR trajectory plot draws without touching a renderer", {
  # The whole architectural claim: a new backend is extractor methods only.
  p <- ggplot2::autoplot(gg_boost_trajectory(boostmlr_fixture()))

  expect_s3_class(p, "ggplot")
  built <- ggplot2::ggplot_build(p)
  expect_gt(nrow(built$data[[1]]), 0L)
})
