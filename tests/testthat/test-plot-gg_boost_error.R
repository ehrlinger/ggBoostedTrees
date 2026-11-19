test_that("autoplot returns a ggplot", {
  p <- ggplot2::autoplot(gg_boost_error(boost_fixture()))

  expect_s3_class(p, "ggplot")
})

test_that("plot is an alias for autoplot", {
  gg <- gg_boost_error(boost_fixture())

  b1 <- ggplot2::ggplot_build(plot(gg))
  b2 <- ggplot2::ggplot_build(ggplot2::autoplot(gg))

  # Compare BUILT plots, not the ggplot objects. aes() quosures capture
  # S3-dispatch bookkeeping (.Generic, .Method, ...) from the calling frame,
  # so two identical plots differ as objects when one reaches the renderer
  # through dispatch and the other does not. ggplot_build() evaluates the
  # quosures away, and its $data carries the computed geometry -- so this
  # catches a real divergence in layers, facets or mapping.
  expect_equal(b1$data, b2$data)
  expect_equal(b1$layout$layout, b2$layout$layout)
})

test_that("the renderer rejects a foreign object", {
  expect_error(plot.gg_boost_error(data.frame(x = 1)), "gg_boost_error")
})

test_that("axis labels name the boosting iteration and the error", {
  p <- ggplot2::autoplot(gg_boost_error(boost_fixture()))

  expect_identical(p$labels$x, "Boosting Iteration")
  expect_identical(p$labels$y, "Error")
})

test_that("the optimal iteration is drawn as its own layer", {
  p <- ggplot2::autoplot(gg_boost_error(boost_fixture()))

  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_true("GeomLine" %in% geoms)
  expect_true("GeomVline" %in% geoms)
})

test_that("marking the optimum can be switched off", {
  p <- ggplot2::autoplot(gg_boost_error(boost_fixture()), optimal = FALSE)

  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_false("GeomVline" %in% geoms)
})

test_that("the renderer applies no theme", {
  p <- ggplot2::autoplot(gg_boost_error(boost_fixture()))

  expect_equal(length(p$theme), 0L)
})

test_that("the univariate error plot is stable", {
  skip_on_cran()
  # Text rendering is not byte-identical across platforms, and the committed
  # reference SVGs were generated on macOS. Comparing elsewhere reports font
  # differences as regressions. One platform is enough to catch a real
  # rendering change; use vdiffr variants if per-platform references are ever
  # wanted.
  skip_on_os(c("windows", "linux", "solaris"))
  skip_if_not_installed("vdiffr")
  vdiffr::expect_doppelganger(
    "error univariate",
    ggplot2::autoplot(gg_boost_error(boost_fixture()))
  )
})

test_that("the multi-response error plot is stable", {
  skip_on_cran()
  # Text rendering is not byte-identical across platforms, and the committed
  # reference SVGs were generated on macOS. Comparing elsewhere reports font
  # differences as regressions. One platform is enough to catch a real
  # rendering change; use vdiffr variants if per-platform references are ever
  # wanted.
  skip_on_os(c("windows", "linux", "solaris"))
  skip_if_not_installed("vdiffr")
  vdiffr::expect_doppelganger(
    "error multi response",
    ggplot2::autoplot(gg_boost_error(boost_multi_fixture()))
  )
})

# A hand-built error path: 8 iterations, optimum at 6, error falling from 1.0
# to 0.8 over the last quarter (iterations 6 to 8).
error_path <- function(value = c(2, 1.6, 1.3, 1.1, 1.05, 1.0, 0.9, 0.8),
                       m_opt = 6L, response = "y") {
  d <- data.frame(
    iteration = seq_along(value),
    value = value,
    response = factor(response),
    optimal = seq_along(value) == m_opt
  )
  class(d) <- c("gg_boost_error", class(d))
  d
}

test_that("convergence is measured over the last quarter of iterations", {
  conv <- .error_convergence(error_path())

  expect_identical(conv$m_opt, 6L)
  expect_identical(conv$m, 8L)
  expect_identical(conv$window, 2L)
  expect_equal(conv$change, (0.8 - 1.0) / 1.0)
})

test_that("the caption reports the optimum and the tail change", {
  p <- ggplot2::autoplot(error_path())

  expect_identical(
    p$labels$caption,
    "Optimal iteration 6 of 8; error fell 20.0% over the last 2 iterations"
  )
})

test_that("a rising tail is reported as a rise", {
  p <- ggplot2::autoplot(error_path(c(1, 0.9, 0.8, 0.7, 0.75, 0.8, 0.85, 0.9),
                                    m_opt = 4L))

  expect_match(p$labels$caption, "error rose 12.5%", fixed = TRUE)
})

test_that("a backend with no optimum reports the iterations grown", {
  p <- ggplot2::autoplot(error_path(m_opt = 0L))

  expect_match(p$labels$caption, "^8 iterations; error fell")
})

test_that("each response gets its own caption line", {
  d <- rbind(error_path(response = "a"), error_path(response = "b"))
  d$response <- factor(as.character(d$response), levels = c("a", "b"))
  class(d) <- c("gg_boost_error", "data.frame")

  lines <- strsplit(ggplot2::autoplot(d)$labels$caption, "\n")[[1]]
  expect_length(lines, 2L)
  expect_match(lines[1], "^a: Optimal iteration 6 of 8")
  expect_match(lines[2], "^b: Optimal iteration 6 of 8")
})

test_that("the convergence caption can be switched off", {
  p <- ggplot2::autoplot(error_path(), convergence = FALSE)

  expect_null(p$labels$caption)
})
