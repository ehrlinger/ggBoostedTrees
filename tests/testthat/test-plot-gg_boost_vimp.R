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

  # coord_flip() swaps the drawn axes but not the aesthetic names, so the
  # metric lives on $labels$y and is drawn horizontally. Verified.
  #
  # The metric is a property of how vimp was computed, not a constant, so a
  # hard-coded axis label would be a lie on some objects.
  expect_identical(p$labels$y, v$metric)
  expect_identical(p$labels$x, "Variable")
})

test_that("variables are ordered by importance rather than by name", {
  gg <- gg_boost_vimp(vimp_fixture(), components = "main")
  p <- ggplot2::autoplot(gg)

  ord <- order(gg$importance)
  expect_identical(levels(p$data$variable), as.character(gg$variable[ord]))
})

test_that("components are faceted", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_fixture()))

  expect_s3_class(p$facet, "FacetWrap")
})

test_that("a single component draws without facets", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_fixture(), components = "main"))

  expect_s3_class(p$facet, "FacetNull")
})

test_that("the importance plot is stable", {
  skip_on_cran()
  # Text rendering is not byte-identical across platforms, and the committed
  # reference SVGs were generated on macOS.
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "vimp both components",
    ggplot2::autoplot(gg_boost_vimp(vimp_fixture()))
  )
})

test_that("the joint importance plot is stable", {
  skip_on_cran()
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "vimp joint",
    ggplot2::autoplot(gg_boost_vimp(vimp_joint_fixture()))
  )
})
