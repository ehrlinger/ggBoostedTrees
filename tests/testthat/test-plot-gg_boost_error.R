test_that("autoplot returns a ggplot", {
  p <- ggplot2::autoplot(gg_boost_error(boost_fixture()))

  expect_s3_class(p, "ggplot")
})

test_that("plot is an alias for autoplot", {
  gg <- gg_boost_error(boost_fixture())

  b1 <- ggplot2::ggplot_build(plot(gg))
  b2 <- ggplot2::ggplot_build(ggplot2::autoplot(gg))

  # Compare BUILT plots, not the ggplot objects. aes() quosures capture
  # S3-dispatch bookkeeping (.Generic, .Method, ...) from the calling frame,
  # so two identical plots differ as objects when one reaches the renderer
  # through dispatch and the other does not. ggplot_build() evaluates the
  # quosures away, and its $data carries the computed geometry -- so this
  # catches a real divergence in layers, facets or mapping.
  expect_equal(b1$data, b2$data)
  expect_equal(b1$layout$layout, b2$layout$layout)
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

test_that("the renderer applies no theme", {
  p <- ggplot2::autoplot(gg_boost_error(boost_fixture()))

  expect_equal(length(p$theme), 0L)
})

test_that("the univariate error plot is stable", {
  skip_on_cran()
  # Text rendering is not byte-identical across platforms, and the committed
  # reference SVGs were generated on macOS. Comparing elsewhere reports font
  # differences as regressions. One platform is enough to catch a real
  # rendering change; use vdiffr variants if per-platform references are ever
  # wanted.
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "error univariate",
    ggplot2::autoplot(gg_boost_error(boost_fixture()))
  )
})

test_that("the multi-response error plot is stable", {
  skip_on_cran()
  # Text rendering is not byte-identical across platforms, and the committed
  # reference SVGs were generated on macOS. Comparing elsewhere reports font
  # differences as regressions. One platform is enough to catch a real
  # rendering change; use vdiffr variants if per-platform references are ever
  # wanted.
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "error multi response",
    ggplot2::autoplot(gg_boost_error(boost_multi_fixture()))
  )
})
