test_that("autoplot returns a ggplot", {
  p <- ggplot2::autoplot(gg_boost_trajectory(boost_fixture()))

  expect_s3_class(p, "ggplot")
})

test_that("plot is an alias for autoplot", {
  gg <- gg_boost_trajectory(boost_fixture())

  b1 <- ggplot2::ggplot_build(plot(gg))
  b2 <- ggplot2::ggplot_build(ggplot2::autoplot(gg))

  # Compare BUILT plots, not the ggplot objects. aes() quosures capture
  # S3-dispatch bookkeeping (.Generic, .Method, ...) from the calling frame,
  # so two identical plots differ as objects when one reaches the renderer
  # through dispatch and the other does not.
  expect_equal(b1$data, b2$data)
  expect_equal(b1$layout$layout, b2$layout$layout)
})

test_that("the renderer rejects a foreign object", {
  expect_error(plot.gg_boost_trajectory(data.frame(x = 1)), "gg_boost_trajectory")
})

test_that("axis labels name time and the response", {
  p <- ggplot2::autoplot(gg_boost_trajectory(boost_fixture()))

  expect_identical(p$labels$x, "Time")
  expect_identical(p$labels$y, "Response")
})

test_that("fitted lines and observed points are both drawn by default", {
  p <- ggplot2::autoplot(gg_boost_trajectory(boost_fixture()))

  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_true("GeomLine" %in% geoms)
  expect_true("GeomPoint" %in% geoms)
})

test_that("observed = FALSE drops the point layer", {
  p <- ggplot2::autoplot(
    gg_boost_trajectory(boost_fixture()), observed = FALSE
  )

  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_false("GeomPoint" %in% geoms)
})

test_that("subset keeps only the named subjects", {
  gg <- gg_boost_trajectory(boost_fixture())
  keep <- levels(gg$id)[1:3]
  p <- ggplot2::autoplot(gg, subset = keep)

  expect_setequal(as.character(unique(p$data$id)), keep)
})

test_that("subset errors on an identifier the data does not contain", {
  gg <- gg_boost_trajectory(boost_fixture())

  expect_error(ggplot2::autoplot(gg, subset = "not-a-subject"), "not-a-subject")
})

test_that("n_max thins the cohort and says so", {
  gg <- gg_boost_trajectory(boost_fixture())

  expect_message(
    p <- ggplot2::autoplot(gg, n_max = 5),
    "5 of 25"
  )
  expect_length(unique(as.character(p$data$id)), 5L)
})

test_that("n_max = Inf draws every subject without a message", {
  gg <- gg_boost_trajectory(boost_fixture())

  expect_no_message(p <- ggplot2::autoplot(gg, n_max = Inf))
  expect_length(unique(as.character(p$data$id)), 25L)
})

test_that("alpha falls as the cohort grows", {
  # The default alpha exists to turn overplotting into a density read, so it
  # must actually respond to how many subjects are drawn.
  few <- .boost_trajectory_alpha(5L)
  many <- .boost_trajectory_alpha(500L)

  expect_gt(few, many)
  expect_lte(few, 1)
  expect_gt(many, 0)
})

test_that("an explicit alpha overrides the computed one", {
  gg <- gg_boost_trajectory(boost_fixture())
  p <- ggplot2::autoplot(gg, alpha = 0.42)

  line <- p$layers[[which(vapply(
    p$layers, function(l) class(l$geom)[1], character(1)
  ) == "GeomLine")[1]]]
  expect_equal(line$aes_params$alpha, 0.42)
})

test_that("the trajectory plot is stable", {
  skip_on_cran()
  # Text rendering is not byte-identical across platforms, and the committed
  # reference SVGs were generated on macOS.
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "trajectory univariate",
    ggplot2::autoplot(gg_boost_trajectory(boost_fixture()), n_max = Inf)
  )
})

test_that("the multi-response trajectory plot is stable", {
  skip_on_cran()
  skip_on_os(c("windows", "linux", "solaris"))
  vdiffr::expect_doppelganger(
    "trajectory multi response",
    ggplot2::autoplot(gg_boost_trajectory(boost_multi_fixture()))
  )
})
