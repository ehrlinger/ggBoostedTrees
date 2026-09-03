test_that("autoplot on a model object gives the error plot", {
  fit <- boost_fixture()

  b1 <- ggplot2::ggplot_build(ggplot2::autoplot(fit))
  b2 <- ggplot2::ggplot_build(ggplot2::autoplot(gg_boost_error(fit)))

  # Compare BUILT plots, not the ggplot objects. aes() quosures capture
  # S3-dispatch bookkeeping (.Generic, .Method, ...) from the calling frame,
  # so two identical plots differ as objects when one reaches the renderer
  # through dispatch and the other does not. ggplot_build() evaluates the
  # quosures away, and its $data carries the computed geometry -- so this
  # catches a real divergence in layers, facets or mapping.
  expect_equal(b1$data, b2$data)
  expect_equal(b1$layout$layout, b2$layout$layout)
})

test_that("autoplot on a model object returns a ggplot", {
  expect_s3_class(ggplot2::autoplot(boost_fixture()), "ggplot")
})

test_that("autoplot on a fit without cv.flag explains the cause", {
  fit <- boost_fixture()
  fit$err.rate <- NULL

  expect_error(ggplot2::autoplot(fit), "cv.flag")
})
