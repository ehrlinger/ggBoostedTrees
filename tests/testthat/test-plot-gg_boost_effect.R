test_that("autoplot returns a ggplot", {
  p <- ggplot2::autoplot(gg_boost_effect(partial_fixture()))

  expect_s3_class(p, "ggplot")
})

test_that("plot is an alias for autoplot", {
  gg <- gg_boost_effect(partial_fixture())

  b1 <- ggplot2::ggplot_build(plot(gg))
  b2 <- ggplot2::ggplot_build(ggplot2::autoplot(gg))

  # Compare BUILT plots, not the ggplot objects; see plot.gg_boost_error.
  expect_equal(b1$data, b2$data)
  expect_equal(b1$layout$layout, b2$layout$layout)
})

test_that("the renderer rejects a foreign object", {
  expect_error(plot.gg_boost_effect(data.frame(x = 1)), "gg_boost_effect")
})

test_that("axis labels name the covariate and the effect", {
  p <- ggplot2::autoplot(gg_boost_effect(partial_fixture()))

  expect_identical(p$labels$x, "Covariate value")
  expect_identical(p$labels$y, "Effect")
})

test_that("one line is drawn per time point", {
  gg <- gg_boost_effect(partial_fixture())
  p <- ggplot2::autoplot(gg)

  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_true("GeomLine" %in% geoms)
  built <- ggplot2::ggplot_build(p)
  expect_identical(
    length(unique(built$data[[1]]$group)),
    length(unique(gg$time)) * nlevels(gg$variable)
  )
})

test_that("variables are faceted", {
  p <- ggplot2::autoplot(gg_boost_effect(partial_fixture()))

  expect_s3_class(p$facet, "FacetWrap")
})

test_that("the partial effect plot is stable", {
  skip_on_cran()
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "effect partial",
    ggplot2::autoplot(gg_boost_effect(partial_fixture()))
  )
})

test_that("the marginal effect plot is stable", {
  skip_on_cran()
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "effect marginal",
    ggplot2::autoplot(gg_boost_effect(marginal_fixture()))
  )
})

test_that("a discrete covariate draws points on a labelled axis", {
  p <- ggplot2::autoplot(gg_boost_effect(partial_factor_fixture()))

  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  # Lines across a discrete axis would imply an ordering the data lacks.
  expect_true("GeomPoint" %in% geoms)
  expect_false("GeomLine" %in% geoms)
})

test_that("the discrete axis is labelled with levels, not positions", {
  p <- ggplot2::autoplot(gg_boost_effect(partial_factor_fixture()))
  built <- ggplot2::ggplot_build(p)

  labels <- as.character(built$layout$panel_params[[1]]$x$get_labels())
  expect_setequal(labels[!is.na(labels)], c("high", "low"))
})

test_that("a continuous covariate still draws lines", {
  p <- ggplot2::autoplot(gg_boost_effect(partial_fixture()))

  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_true("GeomLine" %in% geoms)
  expect_false("GeomPoint" %in% geoms)
})

test_that("a mixed object is refused with guidance", {
  mixed <- rbind(
    gg_boost_effect(partial_fixture()),
    gg_boost_effect(partial_factor_fixture())
  )
  class(mixed) <- c("gg_boost_effect", "data.frame")

  # ggplot2 allows one scale type per aesthetic across all facets, so a
  # continuous and a discrete covariate cannot share a figure.
  expect_error(ggplot2::autoplot(mixed), "one at a time")
})

test_that("the discrete effect plot is stable", {
  skip_on_cran()
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "effect partial factor",
    ggplot2::autoplot(gg_boost_effect(partial_factor_fixture()))
  )
})
