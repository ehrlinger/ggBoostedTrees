test_that("gg_boost_prediction returns one row per subject with covariates", {
  fit <- boost_fixture()
  gg <- gg_boost_prediction(fit, time = 1)

  expect_s3_class(gg, "gg_boost_prediction")
  expect_identical(nrow(gg), nrow(fit$x))
  expect_identical(names(gg), c("id", "predicted", names(fit$x)))
  expect_equal(gg$x1, fit$x$x1)
  expect_identical(attr(gg, "time"), 1)
})

test_that("predictions are boostmtree's own at the cross-validated m.opt", {
  fit <- boost_fixture()
  gg <- gg_boost_prediction(fit, time = 1)
  n <- nrow(fit$x)

  direct <- predict(fit, x = fit$x, tm = rep(1, n), id = seq_len(n),
                    M = fit$m.opt)
  expect_equal(gg$predicted, vapply(direct$mu, `[`, numeric(1), 1L))
  expect_identical(attr(gg, "m"), fit$m.opt)
})

test_that("the prediction moves with time", {
  fit <- boost_fixture()

  early <- gg_boost_prediction(fit, time = 0.25)$predicted
  late <- gg_boost_prediction(fit, time = 3)$predicted
  expect_false(isTRUE(all.equal(early, late)))
})

test_that("a time outside the observed follow-up is refused", {
  fit <- boost_fixture()

  expect_error(gg_boost_prediction(fit, time = 10), "outside the observed")
  expect_error(gg_boost_prediction(fit, time = 0), "outside the observed")
})

test_that("time must be a single finite number", {
  fit <- boost_fixture()

  expect_error(gg_boost_prediction(fit, time = c(1, 2)), "single finite")
  expect_error(gg_boost_prediction(fit, time = "1"), "single finite")
  expect_error(gg_boost_prediction(fit, time = NA_real_), "single finite")
})

test_that("covariates that collide with added columns are refused", {
  fit <- boost_fixture()
  names(fit$x)[1] <- "predicted"

  expect_error(gg_boost_prediction(fit, time = 1), "collide")
})

test_that("multi-response fits are refused", {
  fit <- boost_fixture()
  fit$n.q <- 2L

  expect_error(gg_boost_prediction(fit, time = 1), "multi-response")
})

test_that("BoostMLR fits are refused explicitly", {
  expect_error(
    gg_boost_prediction(boostmlr_fixture(), time = 1),
    "BoostMLR fits are not supported"
  )
})

test_that("a foreign object is refused", {
  expect_error(gg_boost_prediction(data.frame(x = 1), time = 1),
               "expected a 'boostmtree' object")
})

# boostmtree keeps a response-level wrapper around mu for a two-level
# nominal or ordinal fit even though n.q is 1. Fitted live: these take well
# under a second and no stored fixture covers the families.
two_level_fit <- function(family) {
  set.seed(1)
  s <- boostmtree::simLong(n = 20, n.time = 3, model = 1,
                           family = "binary")$data.list
  boostmtree::boostmtree(
    x = s$features, tm = s$time, id = s$id, y = s$y,
    M = 10, verbose = FALSE, family = family
  )
}

for (family in c("nominal", "ordinal")) {
  test_that(paste("a two-level", family, "fit predicts every subject"), {
    fit <- two_level_fit(family)
    t_mid <- stats::median(unlist(fit$time))
    gg <- gg_boost_prediction(fit, time = t_mid)
    n <- nrow(fit$x)

    direct <- predict(fit, x = fit$x, tm = rep(t_mid, n), id = seq_len(n),
                      M = fit$M, .extrapolate = FALSE)
    expect_identical(nrow(gg), n)
    expect_equal(gg$predicted,
                 vapply(direct$mu[[1]], `[`, numeric(1), 1L))
    # The bug this guards: the first subject recycled into every row.
    expect_gt(length(unique(gg$predicted)), 1L)
  })
}
