pooled_fixture <- function() {
  gg_boost_vimp(list(
    a = vimp_shadow_fixture(), # nolint: object_usage_linter. A test helper.
    b = vimp_shadow_fixture(shadow_main = c(0.015, 0),
                            shadow_inter = c(0.035, 0)),
    c = vimp_shadow_fixture(shadow_main = c(-0.02, -0.01),
                            shadow_inter = c(0.5, 0.1))
  ))
}

test_that("plot is an alias for autoplot", {
  gg <- pooled_fixture()

  b1 <- ggplot2::ggplot_build(plot(gg))
  b2 <- ggplot2::ggplot_build(ggplot2::autoplot(gg))

  expect_equal(b1$data, b2$data)
  expect_equal(b1$layout$layout, b2$layout$layout)
})

test_that("the renderer rejects a foreign object", {
  expect_error(plot.gg_boost_vimp_pool(data.frame(x = 1)),
               "gg_boost_vimp_pool")
})

test_that("each box is drawn from the extracted percentiles", {
  gg <- pooled_fixture()
  box <- layer_of(ggplot2::autoplot(gg), "GeomBoxplot")

  expect_identical(nrow(box), nrow(gg))
  expect_setequal(box$xmiddle, gg$q50)
  expect_setequal(box$xmin, gg$q15)
  expect_setequal(box$xmax, gg$q85)
  expect_setequal(box$xlower, gg$q25)
  expect_setequal(box$xupper, gg$q75)
})

test_that("every run is drawn as a point at its margin", {
  gg <- pooled_fixture()
  pts <- layer_of(ggplot2::autoplot(gg), "GeomPoint")

  expect_identical(nrow(pts), nrow(attr(gg, "runs")))
  expect_setequal(pts$x, attr(gg, "runs")$margin)
})

test_that("each row is labelled with the runs that cleared the band", {
  gg <- pooled_fixture()
  txt <- layer_of(ggplot2::autoplot(gg), "GeomText")

  expect_setequal(txt$label, paste0(gg$n_detected, "/", gg$n_runs))
  expect_true("3/3" %in% txt$label)
})

test_that("zero is drawn as the reference every run was judged against", {
  vline <- layer_of(ggplot2::autoplot(pooled_fixture()), "GeomVline")

  expect_true(all(vline$xintercept == 0))
})

test_that("variables run top to bottom by their largest median margin", {
  p <- ggplot2::autoplot(pooled_fixture())

  # ggplot draws the first level at the bottom: x1 (main) and x2
  # (interaction) have the largest medians and sit at the top.
  expect_identical(p$scales$get_scales("y")$limits,
                   c("x4", "x3", "x2", "x1"))
})

test_that("the axis and caption say what is drawn", {
  gg <- pooled_fixture()
  p <- ggplot2::autoplot(gg)

  expect_identical(p$labels$x,
                   paste0(attr(gg, "metric"), " minus the run's shadow band"))
  expect_match(p$labels$caption, "^3 runs, each judged against its own")
})

test_that("components are side-by-side panels with readable titles", {
  p <- ggplot2::autoplot(pooled_fixture())
  layout <- ggplot2::ggplot_build(p)$layout$layout

  expect_identical(nrow(layout), 2L)
  expect_identical(as.character(layout$component),
                   c("main", "interaction"))
})

test_that("point size can be overridden through ...", {
  p <- ggplot2::autoplot(pooled_fixture(), size = 4)
  pts <- layer_of(p, "GeomPoint")

  expect_true(all(pts$size == 4))
})

test_that("the pooled importance plot is stable", {
  skip_on_cran()
  skip_if_not_installed("vdiffr")

  vdiffr::expect_doppelganger(
    "pooled-vimp", ggplot2::autoplot(pooled_fixture())
  )
})

test_that("a row subset draws only the runs for the cells it keeps", {
  gg <- pooled_fixture()
  main <- gg[gg$component == "main", ]
  p <- ggplot2::autoplot(main)

  pts <- layer_of(p, "GeomPoint")
  expect_identical(nrow(pts), 12L)
  expect_identical(nrow(ggplot2::ggplot_build(p)$layout$layout), 1L)
})
