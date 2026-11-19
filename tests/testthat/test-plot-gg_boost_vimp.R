test_that("autoplot returns a ggplot", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_fixture()))

  expect_s3_class(p, "ggplot")
})

test_that("plot is an alias for autoplot", {
  gg <- gg_boost_vimp(vimp_fixture())

  b1 <- ggplot2::ggplot_build(plot(gg))
  b2 <- ggplot2::ggplot_build(ggplot2::autoplot(gg))

  # Compare BUILT plots, not the ggplot objects. aes() quosures capture
  # S3-dispatch bookkeeping (.Generic, .Method, ...) from the calling frame.
  expect_equal(b1$data, b2$data)
  expect_equal(b1$layout$layout, b2$layout$layout)
})

test_that("the renderer rejects a foreign object", {
  expect_error(plot.gg_boost_vimp(data.frame(x = 1)), "gg_boost_vimp")
})

test_that("the x axis is labelled with the metric from the source object", {
  v <- vimp_fixture()
  p <- ggplot2::autoplot(gg_boost_vimp(v))

  # The metric is a property of how vimp was computed, not a constant, so a
  # hard-coded axis label would be a lie on some objects.
  expect_identical(p$labels$x, v$metric)
})

test_that("variables run top to bottom by their largest importance", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_signal_fixture()))

  # x1 peaks at 0.60, x2 at 0.40, x3 at 0.04, x4 at -0.02. The first level
  # is drawn at the bottom of a discrete y axis.
  expect_identical(levels(p$data$variable), c("x4", "x3", "x2", "x1"))
  # And the drawn axis agrees: the stem layer holds only x1 and x2, and must
  # not reorder the scale.
  b <- ggplot2::ggplot_build(p)
  expect_identical(b$layout$panel_params[[1]]$y$get_labels(),
                   c("x4", "x3", "x2", "x1"))
})

test_that("every value is drawn at its signed importance", {
  gg <- gg_boost_vimp(vimp_signal_fixture())
  p <- ggplot2::autoplot(gg)
  dots <- layer_of(p, "GeomPoint")

  expect_equal(sort(dots$x), sort(gg$importance))
})

test_that("the noise band is the largest negative importance", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_signal_fixture()))
  band <- layer_of(p, "GeomRect")

  # One band per component panel, both from -0.05 to 0.05.
  expect_identical(nrow(band), 2L)
  expect_equal(unique(band$xmin), -0.05)
  expect_equal(unique(band$xmax), 0.05)
})

test_that("only values right of the band are detectable and stemmed", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_signal_fixture()))
  d <- p$data

  # x3's interaction of 0.04 is positive but inside the 0.05 band.
  expect_identical(
    sort(paste(d$variable, d$component)[d$detectable]),
    c("x1 main", "x2 interaction")
  )
  stems <- layer_of(p, "GeomSegment")
  expect_equal(sort(stems$xend), c(0.40, 0.60))
  expect_true(all(stems$x == 0))
})

test_that(".vimp_noise_band is zero when nothing is negative", {
  expect_identical(.vimp_noise_band(c(0.3, 0.01, NA)), 0)
  expect_identical(.vimp_noise_band(c(0.3, -0.04, -0.05, NA)), 0.05)
})

test_that("no band is drawn when nothing is negative", {
  v <- vimp_signal_fixture()
  v$main[, 1] <- abs(v$main[, 1])
  v$interaction[, 1] <- abs(v$interaction[, 1])
  p <- ggplot2::autoplot(gg_boost_vimp(v))

  expect_identical(nrow(layer_of(p, "GeomRect")), 0L)
  expect_true(all(p$data$detectable))
})

test_that("an interaction panel with nothing detectable says so", {
  # Every value in the recorded fixture is inside its own noise band.
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_fixture()))
  note <- layer_of(p, "GeomText")

  expect_identical(note$label, "None detectable")
})

test_that("a detectable interaction carries no note", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_signal_fixture()))

  expect_false(any(vapply(p$layers, function(l) inherits(l$geom, "GeomText"),
                          logical(1))))
})

test_that("components are side-by-side panels with readable titles", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_fixture()))

  expect_s3_class(p$facet, "FacetWrap")
  layout <- ggplot2::ggplot_build(p)$layout$layout
  expect_identical(as.character(layout$component), c("main", "interaction"))
})

test_that("the overall time effect is reported in the caption", {
  v <- vimp_fixture()
  p <- ggplot2::autoplot(gg_boost_vimp(v))

  expect_identical(
    p$labels$caption,
    paste0("Overall time effect: ", format(signif(v$time.effect, 3)))
  )
})

test_that("a single component draws one panel and no note", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_fixture(), components = "main"))

  expect_identical(nrow(ggplot2::ggplot_build(p)$layout$layout), 1L)
  expect_false(any(vapply(p$layers, function(l) inherits(l$geom, "GeomText"),
                          logical(1))))
})

test_that("both legend keys are drawn even when nothing is detectable", {
  # Every value in the recorded fixture sits inside its noise band.
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_fixture()))
  point_layer <- p$layers[vapply(p$layers, function(l) {
    inherits(l$geom, "GeomPoint")
  }, logical(1))][[1]]

  expect_true(isTRUE(point_layer$show.legend))
  expect_identical(
    ggplot2::ggplot_build(p)$plot$scales$get_scales("shape")$get_limits(),
    c("Detectable", "Within noise band")
  )
})

test_that("dot size and legend visibility can be overridden through ...", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_fixture()), size = 6,
                         show.legend = FALSE)
  point_layer <- p$layers[vapply(p$layers, function(l) {
    inherits(l$geom, "GeomPoint")
  }, logical(1))][[1]]

  expect_identical(point_layer$aes_params$size, 6)
  expect_false(point_layer$show.legend)
})

test_that("the importance plot is stable", {
  skip_on_cran()
  # Text rendering is not byte-identical across platforms, and the committed
  # reference SVGs were generated on macOS.
  skip_on_os(c("windows", "linux", "solaris"))
  skip_if_not_installed("vdiffr")
  vdiffr::expect_doppelganger(
    "vimp both components",
    ggplot2::autoplot(gg_boost_vimp(vimp_fixture()))
  )
})

test_that("the joint importance plot is stable", {
  skip_on_cran()
  skip_on_os(c("windows", "linux", "solaris"))
  skip_if_not_installed("vdiffr")
  vdiffr::expect_doppelganger(
    "vimp joint",
    ggplot2::autoplot(gg_boost_vimp(vimp_joint_fixture()))
  )
})
