test_that("autoplot returns a ggplot", {
  p <- ggplot2::autoplot(gg_boost_error(boost_fixture()))

  expect_s3_class(p, "ggplot")
})

test_that("plot is an alias for autoplot", {
  gg <- gg_boost_error(boost_fixture())

  p1 <- plot(gg)
  p2 <- ggplot2::autoplot(gg)

  # Compare data/labels/layer geoms rather than the full ggplot objects:
  # ggplot2 4.0.3's aes() quosures capture S3-dispatch bookkeeping
  # (.Generic, .Method, .GenericCallEnv, ...) from the calling frame, so a
  # direct call vs. a generic-dispatched call differ in that bookkeeping
  # even though the two plots are identical in every visible respect.
  expect_equal(p1$data, p2$data)
  expect_equal(p1$labels, p2$labels)
  expect_equal(
    vapply(p1$layers, function(l) class(l$geom)[1], character(1)),
    vapply(p2$layers, function(l) class(l$geom)[1], character(1))
  )
})

test_that("the renderer rejects a foreign object", {
  expect_error(plot.gg_boost_error(data.frame(x = 1)), "gg_boost_error")
})

test_that("axis labels name the boosting iteration and the error", {
  p <- ggplot2::autoplot(gg_boost_error(boost_fixture()))

  expect_identical(p$labels$x, "Boosting Iteration")
  expect_identical(p$labels$y, "Error")
})

test_that("the optimal iteration is drawn as its own layer", {
  p <- ggplot2::autoplot(gg_boost_error(boost_fixture()))

  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_true("GeomLine" %in% geoms)
  expect_true("GeomVline" %in% geoms)
})

test_that("marking the optimum can be switched off", {
  p <- ggplot2::autoplot(gg_boost_error(boost_fixture()), optimal = FALSE)

  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_false("GeomVline" %in% geoms)
})

test_that("the univariate error plot is stable", {
  skip_on_cran()
  vdiffr::expect_doppelganger(
    "error univariate",
    ggplot2::autoplot(gg_boost_error(boost_fixture()))
  )
})

test_that("the multi-response error plot is stable", {
  skip_on_cran()
  vdiffr::expect_doppelganger(
    "error multi response",
    ggplot2::autoplot(gg_boost_error(boost_multi_fixture()))
  )
})
