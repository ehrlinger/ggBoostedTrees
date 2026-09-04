test_that("gg_boost_effect returns the documented column contract", {
  gg <- gg_boost_effect(partial_fixture())

  expect_s3_class(gg, "gg_boost_effect")
  expect_identical(
    names(gg), c("variable", "x", "time", "estimate", "kind")
  )
  expect_s3_class(gg$variable, "factor")
  expect_type(gg$x, "double")
  expect_type(gg$time, "double")
  expect_type(gg$estimate, "double")
  expect_s3_class(gg$kind, "factor")
})

test_that("a partial object is labelled partial", {
  gg <- gg_boost_effect(partial_fixture())

  expect_identical(levels(gg$kind), "partial")
})

test_that("a marginal object is labelled marginal", {
  gg <- gg_boost_effect(marginal_fixture())

  expect_identical(levels(gg$kind), "marginal")
})

test_that("every variable and time point becomes rows", {
  p <- partial_fixture()
  gg <- gg_boost_effect(p)

  expect_identical(levels(gg$variable), c("x1", "x2"))
  expect_setequal(unique(gg$time), p$time.points)
  expect_identical(
    nrow(gg),
    nrow(p$curves$x1) * length(p$time.points) * length(p$curves)
  )
})

test_that("partial estimates are the wide curve columns pivoted long", {
  p <- partial_fixture()
  gg <- gg_boost_effect(p)

  for (k in seq_along(p$time.points)) {
    at_k <- gg[gg$variable == "x1" & gg$time == p$time.points[k], ]
    expect_equal(at_k$x, p$curves$x1$x)
    expect_equal(at_k$estimate, p$curves$x1[[k + 1L]])
  }
})

test_that("time is parsed to a number, not left as a label", {
  gg <- gg_boost_effect(marginal_fixture())

  expect_type(gg$time, "double")
  expect_false(any(is.na(gg$time)))
  expect_setequal(unique(gg$time), marginal_fixture()$time.points)
})

test_that("the marginal kind takes the smoothed curve, not the raw scatter", {
  m <- marginal_fixture()
  gg <- gg_boost_effect(m)

  first <- gg[gg$variable == "x1" & gg$time == m$time.points[1], ]
  expect_equal(first$x, m$smooth$x1[[1]]$x)
  expect_equal(first$estimate, m$smooth$x1[[1]]$y)
})

test_that("gg_boost_effect rejects a non-effect object", {
  expect_error(gg_boost_effect(data.frame(x = 1)), "gg_boost_effect")
  expect_error(gg_boost_effect(boost_fixture()), "partial.plot")
})

test_that("a nested (multi-response) partial object is rejected", {
  p <- partial_fixture()
  p$curves <- list(y1 = p$curves, y2 = p$curves)

  expect_error(gg_boost_effect(p), "single-response")
})

test_that("a nested (multi-response) marginal object is rejected", {
  m <- marginal_fixture()
  m$smooth <- list(y1 = m$smooth, y2 = m$smooth)

  expect_error(gg_boost_effect(m), "single-response")
})
