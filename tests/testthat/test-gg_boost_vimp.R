test_that("gg_boost_vimp returns the documented column contract", {
  gg <- gg_boost_vimp(vimp_fixture())

  expect_s3_class(gg, "gg_boost_vimp")
  expect_identical(
    names(gg), c("variable", "importance", "component", "response")
  )
  expect_s3_class(gg$variable, "factor")
  expect_type(gg$importance, "double")
  expect_s3_class(gg$component, "factor")
  expect_s3_class(gg$response, "factor")
})

test_that("both components are returned by default", {
  gg <- gg_boost_vimp(vimp_fixture())

  expect_identical(levels(gg$component), c("main", "interaction"))
  expect_identical(nrow(gg), 8L)
})

test_that("components can be selected", {
  gg <- gg_boost_vimp(vimp_fixture(), components = "main")

  expect_identical(levels(gg$component), "main")
  expect_identical(nrow(gg), 4L)
})

test_that("the :time suffix is stripped from interaction variable names", {
  gg <- gg_boost_vimp(vimp_fixture())

  # Without stripping, a variable would appear twice under different labels
  # and could never be compared or dodged across components.
  expect_identical(levels(gg$variable), c("x1", "x2", "x3", "x4"))
  expect_false(any(grepl(":time", gg$variable, fixed = TRUE)))
})

test_that("importance values come from the matching component matrix", {
  v <- vimp_fixture()
  gg <- gg_boost_vimp(v)

  expect_equal(
    gg$importance[gg$component == "main"], unname(v$main[, 1])
  )
  expect_equal(
    gg$importance[gg$component == "interaction"], unname(v$interaction[, 1])
  )
})

test_that("the metric and time effect ride along as attributes", {
  v <- vimp_fixture()
  gg <- gg_boost_vimp(v)

  expect_identical(attr(gg, "metric"), v$metric)
  expect_equal(attr(gg, "time.effect"), v$time.effect)
})

test_that("a joint vimp object collapses to one variable", {
  gg <- gg_boost_vimp(vimp_joint_fixture())

  expect_identical(levels(gg$variable), "joint.vimp")
  expect_identical(nrow(gg), 2L)
})

test_that("gg_boost_vimp rejects an unknown component", {
  expect_error(gg_boost_vimp(vimp_fixture(), components = "spurious"),
               "spurious")
})

test_that("gg_boost_vimp fails loud on a component/response shape mismatch", {
  v <- vimp_fixture()
  v$main <- v$main[, 0, drop = FALSE]

  expect_error(gg_boost_vimp(v), "column")
})

test_that("gg_boost_vimp rejects a non-vimp object", {
  expect_error(gg_boost_vimp(data.frame(x = 1)), "gg_boost_vimp")
  # A fitted model is the most likely wrong input, so name it specifically.
  expect_error(gg_boost_vimp(boost_fixture()), "vimp.boostmtree")
})
