test_that("the committed fixture is a cv.flag boostmtree grow object", {
  fit <- boost_fixture()

  expect_s3_class(fit, "boostmtree")
  expect_identical(class(fit)[2], "grow")
  expect_false(is.null(fit$err.rate))
  expect_identical(colnames(fit$err.rate), c("l1", "l2"))
  expect_identical(nrow(fit$err.rate), 50L)
})

test_that("the fixture has an interior optimal iteration", {
  fit <- boost_fixture()

  # An m.opt pinned at 1 or at M would make the `optimal` column untestable.
  expect_gt(fit$m.opt, 1L)
  expect_lt(fit$m.opt, 50L)
})

test_that("fixture provenance is recorded", {
  txt <- readLines(test_path("fixtures", "boost_continuous.dcf"))

  expect_true(any(grepl("^Backend: boostmtree", txt)))
  expect_true(any(grepl("cv.flag = TRUE", txt, fixed = TRUE)))
})

test_that("the multi-response helper builds the shapes it claims to", {
  obj <- boost_multi_fixture()

  expect_true(is.list(obj$err.rate))
  expect_length(obj$err.rate, 2L)
  expect_true(is.matrix(obj$rho))
  expect_identical(ncol(obj$rho), 2L)
})

test_that("the multi-response helper carries nested trajectory fields", {
  obj <- boost_multi_fixture()

  expect_length(obj$time, 2L)
  expect_length(obj$mu, 2L)
  expect_true(is.list(obj$mu[[1]]))
  expect_identical(lengths(obj$time), lengths(obj$mu[[1]]))
  expect_true(is.unsorted(obj$time[[1]]))
})

test_that("the vimp fixtures carry the shapes the extractor reads", {
  v <- vimp_fixture()

  expect_s3_class(v, "vimp.boostmtree")
  expect_true(is.matrix(v$main))
  expect_true(is.matrix(v$interaction))
  expect_identical(rownames(v$main), c("x1", "x2", "x3", "x4"))
  # The interaction rownames carry a :time suffix the extractor must strip.
  expect_identical(
    rownames(v$interaction), paste0(c("x1", "x2", "x3", "x4"), ":time")
  )
  expect_false(v$joint)
})

test_that("the joint vimp fixture collapses to one row", {
  v <- vimp_joint_fixture()

  expect_true(v$joint)
  expect_identical(dim(v$main), c(1L, 1L))
  expect_identical(rownames(v$main), "joint.vimp")
  expect_identical(rownames(v$interaction), "joint.vimp:time")
})

test_that("the partial fixture is a wide curve frame per variable", {
  p <- partial_fixture()

  expect_s3_class(p, "partial.plot.boostmtree")
  expect_identical(names(p$curves), c("x1", "x2"))
  expect_identical(names(p$curves$x1)[1], "x")
  expect_true(all(grepl("^time\\.", names(p$curves$x1)[-1])))
  expect_length(p$time.points, ncol(p$curves$x1) - 1L)
})

test_that("the marginal fixture carries raw and smoothed curves", {
  m <- marginal_fixture()

  expect_s3_class(m, "marginal.plot.boostmtree")
  expect_identical(names(m$smooth), c("x1", "x2"))
  expect_true(all(grepl("^time = ", names(m$smooth$x1))))
  expect_identical(names(m$smooth$x1[[1]]), c("x", "y"))
  # The raw scatter is deliberately not extracted; see the spec.
  expect_false(is.null(m$data))
})

test_that("the BoostMLR fixture carries the shapes the extractors read", {
  f <- boostmlr_fixture()

  expect_s3_class(f, "BoostMLR")
  expect_identical(class(f)[2], "grow")
  expect_identical(f$y_Names, c("y1", "y2", "y3"))
  expect_true(is.matrix(f$mu))
  expect_true(is.matrix(f$y))
  expect_identical(dim(f$mu), dim(f$y))
  expect_identical(length(f$tm), nrow(f$mu))
  expect_identical(length(f$id), nrow(f$mu))
})

test_that("the BoostMLR path matrices are M by response", {
  f <- boostmlr_fixture()

  for (nm in c("Error_Rate", "Rho", "Phi")) {
    expect_true(is.matrix(f[[nm]]), label = nm)
    expect_identical(colnames(f[[nm]]), f$y_Names, label = nm)
    expect_identical(nrow(f[[nm]]), as.integer(f$M), label = nm)
  }
})

test_that("BoostMLR records no optimal iteration", {
  f <- boostmlr_fixture()

  # This is why gg_boost_error()'s optimal column is all FALSE for BoostMLR.
  expect_length(grep("opt", names(f), ignore.case = TRUE), 0L)
})

test_that("mu carries no column names, so labels must come from y_Names", {
  f <- boostmlr_fixture()

  expect_null(colnames(f$mu))
})
