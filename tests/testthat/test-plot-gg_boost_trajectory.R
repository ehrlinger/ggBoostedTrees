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
  expect_error(
    plot.gg_boost_trajectory(data.frame(x = 1)), "gg_boost_trajectory"
  )
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

test_that("a repeated identifier in subset is not an error", {
  gg <- gg_boost_trajectory(boost_fixture())
  keep <- levels(gg$id)[1]

  # subset feeds factor(levels = ), which rejects duplicated levels with a
  # bare "factor level [2] is duplicated" carrying no function name. Naming a
  # subject twice is a harmless thing for a caller to do.
  p <- ggplot2::autoplot(gg, subset = c(keep, keep))

  expect_identical(levels(droplevels(p$data$id)), keep)
})

test_that("subset keeps the caller's order after de-duplication", {
  gg <- gg_boost_trajectory(boost_fixture())
  ids <- levels(gg$id)[1:3]
  # Reversed, with a repeat: the surviving order should be first-appearance.
  p <- ggplot2::autoplot(gg, subset = c(ids[3], ids[1], ids[3]))

  expect_identical(levels(p$data$id), c(ids[3], ids[1]))
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

test_that("alpha pins the 12/n formula and its caps", {
  # The default alpha is what makes an overplotted cohort readable as a
  # density, so a silent change to the constant or the floor/cap would
  # change every trajectory figure the package draws without any test
  # failing. Pin the actual contract: max(0.1, min(0.9, 12 / n)).
  expect_equal(.boost_trajectory_alpha(5L), 0.9) # small cohort hits the cap
  expect_equal(.boost_trajectory_alpha(60L), 0.2) # mid-range formula value
  expect_equal(.boost_trajectory_alpha(500L), 0.1) # large cohort hits the floor
})

test_that("an explicit alpha overrides the computed one", {
  gg <- gg_boost_trajectory(boost_fixture())
  p <- ggplot2::autoplot(gg, alpha = 0.42)

  line <- p$layers[[which(vapply(
    p$layers, function(l) class(l$geom)[1], character(1)
  ) == "GeomLine")[1]]]
  expect_equal(line$aes_params$alpha, 0.42)
})

test_that("no observed values suppresses the point layer, not the line", {
  # A predict object carries no observed response, and autoplot silently
  # drops the point layer for it. Nothing else in the suite exercises this
  # branch, and a regression here would silently blank out a layer.
  fit <- boost_fixture()
  fit$y.org <- NULL
  gg <- gg_boost_trajectory(fit)

  expect_no_warning(p <- ggplot2::ggplot_build(ggplot2::autoplot(gg)))

  geoms <- vapply(
    p$plot$layers, function(l) class(l$geom)[1], character(1)
  )
  expect_false("GeomPoint" %in% geoms)
  expect_true("GeomLine" %in% geoms)
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
