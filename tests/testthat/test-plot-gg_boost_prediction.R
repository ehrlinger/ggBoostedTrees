test_that("a numeric covariate draws points and a loess smoother", {
  gg <- gg_boost_prediction(boost_fixture(), time = 1)
  p <- ggplot2::autoplot(gg, covariate = "x1")

  expect_s3_class(p, "ggplot")
  expect_s3_class(p$layers[[1]]$geom, "GeomPoint")
  expect_s3_class(p$layers[[2]]$stat, "StatSmooth")
  expect_identical(p$layers[[2]]$stat_params$method, "loess")
  # One point per subject, at that subject's covariate and prediction.
  built <- ggplot2::ggplot_build(p)$data[[1]]
  expect_equal(sort(built$x), sort(gg$x1))
  expect_equal(sort(built$y), sort(gg$predicted))
})

test_that("a factor covariate marks each level's mean", {
  gg <- gg_boost_prediction(boost_fixture(), time = 1)
  gg$grp <- factor(rep(c("a", "b"), length.out = nrow(gg)))
  p <- ggplot2::autoplot(gg, covariate = "grp")

  means <- ggplot2::ggplot_build(p)$data[[2]]
  expect_equal(
    means$y,
    unname(as.numeric(tapply(gg$predicted, gg$grp, mean)))
  )
})

test_that("the y axis names the prediction time", {
  p <- ggplot2::autoplot(gg_boost_prediction(boost_fixture(), time = 2),
                         covariate = "x2")

  expect_identical(p$labels$y, "Predicted response at time 2")
  expect_identical(p$labels$x, "x2")
})

test_that("the covariate must name a column", {
  gg <- gg_boost_prediction(boost_fixture(), time = 1)

  expect_error(ggplot2::autoplot(gg), "must name one of")
  expect_error(ggplot2::autoplot(gg, covariate = "predicted"),
               "must name one of")
  expect_error(ggplot2::autoplot(gg, covariate = "nope"), "must name one of")
})

test_that("plot is an alias for autoplot", {
  gg <- gg_boost_prediction(boost_fixture(), time = 1)

  b1 <- ggplot2::ggplot_build(plot(gg, covariate = "x1"))
  b2 <- ggplot2::ggplot_build(ggplot2::autoplot(gg, covariate = "x1"))
  expect_equal(b1$data, b2$data)
})

test_that("the renderer rejects a foreign object", {
  expect_error(plot.gg_boost_prediction(data.frame(x = 1), "x"),
               "gg_boost_prediction")
})
