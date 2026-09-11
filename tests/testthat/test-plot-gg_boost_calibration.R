layer_geoms <- function(p) {
  # ggplot2 4.x names the layers list; only the geom sequence is under test.
  unname(vapply(p$layers, function(l) class(l$geom)[1], character(1)))
}

test_that("autoplot returns a ggplot", {
  p <- ggplot2::autoplot(gg_boost_calibration(boost_fixture()))

  expect_s3_class(p, "ggplot")
})

test_that("plot is an alias for autoplot", {
  gg <- gg_boost_calibration(boost_fixture())

  b1 <- ggplot2::ggplot_build(plot(gg))
  b2 <- ggplot2::ggplot_build(ggplot2::autoplot(gg))

  # Compare BUILT plots: aes() quosures capture dispatch bookkeeping, so two
  # identical plots differ as objects when only one went through dispatch.
  expect_equal(b1$data, b2$data)
  expect_equal(b1$layout$layout, b2$layout$layout)
})

test_that("the renderer rejects a foreign object", {
  expect_error(
    plot.gg_boost_calibration(data.frame(x = 1)), "gg_boost_calibration"
  )
})

test_that("axis labels name time and the response", {
  p <- ggplot2::autoplot(gg_boost_calibration(boost_fixture()))

  expect_identical(p$labels$x, "Time")
  expect_identical(p$labels$y, "Response")
})

test_that("bin spans, intervals, fitted line and points are drawn", {
  p <- ggplot2::autoplot(gg_boost_calibration(boost_fixture()))

  expect_identical(
    layer_geoms(p),
    c("GeomSegment", "GeomLinerange", "GeomLine", "GeomPoint")
  )
})

test_that("ci = FALSE drops the interval layer", {
  p <- ggplot2::autoplot(gg_boost_calibration(boost_fixture()), ci = FALSE)

  expect_false("GeomLinerange" %in% layer_geoms(p))
})

test_that("a cohort attribute adds the cohort line", {
  gg <- gg_boost_calibration(boost_fixture(), pred = boost_predict_fixture())
  p <- ggplot2::autoplot(gg)

  expect_identical(sum(layer_geoms(p) == "GeomLine"), 2L)
})

test_that("building does not warn, including single-observation bins", {
  gg <- gg_boost_calibration(boost_tied_fixture(), breaks = c(0, 7.5, 8))

  expect_no_warning(ggplot2::ggplot_build(ggplot2::autoplot(gg)))
  expect_no_warning(ggplot2::ggplot_build(ggplot2::autoplot(
    gg_boost_calibration(boost_fixture(), pred = boost_predict_fixture())
  )))
})

test_that("several responses facet and one does not", {
  multi <- ggplot2::autoplot(gg_boost_calibration(boostmlr_fixture()))
  single <- ggplot2::autoplot(gg_boost_calibration(boost_fixture()))

  expect_s3_class(multi$facet, "FacetWrap")
  expect_false(inherits(single$facet, "FacetWrap"))
})

test_that("the univariate calibration plot is stable", {
  skip_on_cran()
  # Text rendering is not byte-identical across platforms, and the committed
  # reference SVGs were generated on macOS.
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "calibration univariate",
    ggplot2::autoplot(gg_boost_calibration(boost_fixture()))
  )
})

test_that("the calibration plot with a cohort curve is stable", {
  skip_on_cran()
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "calibration cohort",
    ggplot2::autoplot(
      gg_boost_calibration(boost_fixture(), pred = boost_predict_fixture())
    )
  )
})

test_that("the multi-response calibration plot is stable", {
  skip_on_cran()
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "calibration multi response",
    ggplot2::autoplot(gg_boost_calibration(boostmlr_fixture()))
  )
})
