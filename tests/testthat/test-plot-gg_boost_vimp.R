point_layer <- function(p) {
  p$layers[vapply(p$layers, function(l) inherits(l$geom, "GeomPoint"),
                  logical(1))][[1]]
}

has_layer <- function(p, geom) {
  any(vapply(p$layers, function(l) inherits(l$geom, geom), logical(1)))
}

test_that("autoplot returns a ggplot", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_fixture()))

  expect_s3_class(p, "ggplot")
})

test_that("plot is an alias for autoplot", {
  gg <- gg_boost_vimp(vimp_shadow_fixture())

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

test_that("shadows set the band but are not drawn as variables", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_shadow_fixture()))

  expect_false(any(grepl("^shadow", levels(p$data$variable))))
  expect_identical(nrow(p$data), 8L)
  expect_identical(nrow(layer_of(p, "GeomPoint")), 8L)
})

test_that("variables run top to bottom by their largest importance", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_shadow_fixture()))

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
  gg <- gg_boost_vimp(vimp_shadow_fixture())
  p <- ggplot2::autoplot(gg)

  expect_equal(sort(layer_of(p, "GeomPoint")$x),
               sort(gg$importance[!gg$shadow]))
})

test_that("each panel's band is the largest shadow importance there", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_shadow_fixture()))
  band <- layer_of(p, "GeomRect")

  # Panel 1 is main (shadows 0.03, -0.01); panel 2 is interaction (0.05, 0.01).
  expect_equal(band$xmax[order(band$PANEL)], c(0.03, 0.05))
  expect_true(all(is.infinite(band$xmin) & band$xmin < 0))
})

test_that("the band is floored at zero when every shadow scores below it", {
  v <- vimp_shadow_fixture(shadow_main = c(-0.02, -0.01))
  p <- ggplot2::autoplot(gg_boost_vimp(v))
  band <- layer_of(p, "GeomRect")

  expect_equal(band$xmax[order(band$PANEL)], c(0, 0.05))
  # So a positive main effect, however small, clears it.
  d <- p$data
  expect_true(d$detectable[d$variable == "x2" & d$component == "main"])
})

test_that("only values right of the band are detectable and stemmed", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_shadow_fixture()))
  d <- p$data

  # x2's main 0.02 is inside the 0.03 band; x3's interaction 0.04 is inside
  # the 0.05 band.
  expect_identical(
    sort(paste(d$variable, d$component)[d$detectable]),
    c("x1 main", "x2 interaction")
  )
  stems <- layer_of(p, "GeomSegment")
  expect_equal(sort(stems$xend), c(0.40, 0.60))
  expect_true(all(stems$x == 0))
})

test_that("without shadows there is no band, no verdict and no legend", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_fixture()))

  expect_identical(nrow(layer_of(p, "GeomRect")), 0L)
  expect_true(all(p$data$detectable))
  expect_false(isTRUE(point_layer(p)$show.legend))
  expect_false(has_layer(p, "GeomText"))
  expect_match(p$labels$caption, "No shadow covariates", fixed = TRUE)
})

test_that("the caption names how many shadows set the band", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_shadow_fixture()))

  expect_match(p$labels$caption,
               "Band: largest importance of 2 shadow covariates",
               fixed = TRUE)
})

test_that("the overall time effect is reported in the caption", {
  v <- vimp_fixture()
  p <- ggplot2::autoplot(gg_boost_vimp(v))

  expect_match(
    p$labels$caption,
    paste0("Overall time effect: ", format(signif(v$time.effect, 3))),
    fixed = TRUE
  )
})

test_that("an interaction panel with nothing detectable says so", {
  v <- vimp_shadow_fixture(shadow_inter = c(0.50, 0.01))
  p <- ggplot2::autoplot(gg_boost_vimp(v))

  # The 0.50 shadow covers x2's 0.40 interaction.
  expect_identical(layer_of(p, "GeomText")$label, "None detectable")
})

test_that("a detectable interaction carries no note", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_shadow_fixture()))

  expect_false(has_layer(p, "GeomText"))
})

test_that("components are side-by-side panels with readable titles", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_fixture()))

  expect_s3_class(p$facet, "FacetWrap")
  layout <- ggplot2::ggplot_build(p)$layout$layout
  expect_identical(as.character(layout$component), c("main", "interaction"))
})

test_that("a single component draws one panel", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_shadow_fixture(),
                                       components = "main"))

  expect_identical(nrow(ggplot2::ggplot_build(p)$layout$layout), 1L)
  expect_false(has_layer(p, "GeomText"))
})

test_that("both legend keys are drawn even when nothing is detectable", {
  v <- vimp_shadow_fixture(shadow_main = c(0.9, 0), shadow_inter = c(0.9, 0))
  p <- ggplot2::autoplot(gg_boost_vimp(v))

  expect_false(any(p$data$detectable))
  expect_true(isTRUE(point_layer(p)$show.legend))
  expect_identical(
    ggplot2::ggplot_build(p)$plot$scales$get_scales("shape")$get_limits(),
    c("Detectable", "Within noise band")
  )
})

test_that("dot size and legend visibility can be overridden through ...", {
  p <- ggplot2::autoplot(gg_boost_vimp(vimp_shadow_fixture()), size = 6,
                         show.legend = FALSE)

  expect_identical(point_layer(p)$aes_params$size, 6)
  expect_false(point_layer(p)$show.legend)
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

test_that("the shadow-band importance plot is stable", {
  skip_on_cran()
  skip_on_os(c("windows", "linux", "solaris"))
  skip_if_not_installed("vdiffr")
  vdiffr::expect_doppelganger(
    "vimp shadow band",
    ggplot2::autoplot(gg_boost_vimp(vimp_shadow_fixture()))
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
