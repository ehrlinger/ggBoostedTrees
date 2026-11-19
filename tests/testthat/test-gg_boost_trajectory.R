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

test_that("the reference fixture has no flat out-of-bag trajectory", {
  fit <- boost_fixture()

  expect_true(isTRUE(fit$cv.flag))
  expect_no_warning(gg <- gg_boost_trajectory(fit))
  n_fitted <- tapply(gg$fitted, gg$id, function(v) length(unique(v)))
  expect_true(all(n_fitted > 1L))
})

# What the seed-reuse defect leaves behind: subjects absent from every
# iteration's out-of-bag record up to m.opt, with mu at the starting value.
never_oob <- function(fit, subjects, value = -5.5) {
  fit$gamma.i.list[[1]] <- lapply(fit$gamma.i.list[[1]], function(step) {
    step[subjects] <- list(NULL)
    step
  })
  fit$mu[subjects] <- lapply(
    fit$mu[subjects], function(v) rep(value, length(v))
  )
  fit
}

test_that("subjects never out of bag by m.opt warn with the count", {
  fit <- never_oob(boost_fixture(), 1:3)

  expect_warning(
    gg <- gg_boost_trajectory(fit),
    "3 of 25 subject\\(s\\) were never out of bag by m.opt"
  )
  # The warning flags the data; it does not drop or alter rows.
  expect_identical(nrow(gg), length(unlist(fit$time)))
  expect_true(all(gg$fitted[gg$id %in% fit$id.unique[1:3]] == -5.5))
})

test_that("a real pre-2.0.13 seeded fit still warns", {
  expect_warning(
    gg_boost_trajectory(boost_seed_defect_fixture()),
    "16 of 25 subject\\(s\\) were never out of bag by m.opt"
  )
})

test_that("out of bag only after m.opt still counts as never out of bag", {
  fit <- boost_fixture()
  steps <- fit$gamma.i.list[[1]]
  before <- seq_len(fit$m.opt)
  steps[before] <- lapply(steps[before], function(step) {
    step[1] <- list(NULL)
    step
  })
  fit$gamma.i.list[[1]] <- steps

  expect_warning(gg_boost_trajectory(fit), "1 of 25 subject")
})

test_that("an intercept-only time design (d = 0) is flat but does not warn", {
  fit <- boost_d0_fixture()
  expect_true(isTRUE(fit$cv.flag))

  expect_no_warning(gg <- gg_boost_trajectory(fit))
  # Flat by construction: one fitted value per subject across 4 times.
  n_fitted <- tapply(gg$fitted, gg$id, function(v) length(unique(v)))
  n_time <- tapply(gg$time, gg$id, function(v) length(unique(v)))
  expect_true(all(n_fitted == 1L))
  expect_true(all(n_time > 1L))
})

test_that("a flat subject that was out of bag does not warn", {
  fit <- boost_fixture()
  fit$mu[1:3] <- lapply(fit$mu[1:3], function(v) rep(-5.5, length(v)))

  expect_no_warning(gg_boost_trajectory(fit))
})

test_that("no out-of-bag record, or no cross-validation, means no warning", {
  fit <- never_oob(boost_fixture(), 1:3)
  fit$cv.flag <- FALSE
  expect_no_warning(gg_boost_trajectory(fit))

  fit <- never_oob(boost_fixture(), 1:3)
  fit$gamma.i.list <- NULL
  expect_no_warning(gg_boost_trajectory(fit))
})

test_that("calibration passes the never-out-of-bag warning through", {
  fit <- never_oob(boost_fixture(), 1:3)

  expect_warning(gg_boost_calibration(fit), "never out of bag")
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

test_that("a y/mu dimension mismatch is refused, not silently misaligned", {
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
