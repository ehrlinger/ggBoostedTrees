test_that("gg_boost_effect returns the documented column contract", {
  gg <- gg_boost_effect(partial_fixture())

  expect_s3_class(gg, "gg_boost_effect")
  expect_identical(
    names(gg),
    c("variable", "x", "x_label", "time", "estimate", "kind", "response")
  )
  expect_s3_class(gg$variable, "factor")
  expect_type(gg$x, "double")
  expect_type(gg$time, "double")
  expect_type(gg$estimate, "double")
  expect_s3_class(gg$kind, "factor")
})

test_that("a partial object is labelled partial", {
  gg <- gg_boost_effect(partial_fixture())

  expect_identical(levels(gg$kind), "partial")
})

test_that("a marginal object is labelled marginal", {
  gg <- gg_boost_effect(marginal_fixture())

  expect_identical(levels(gg$kind), "marginal")
})

test_that("every variable and time point becomes rows", {
  p <- partial_fixture()
  gg <- gg_boost_effect(p)

  expect_identical(levels(gg$variable), c("x1", "x2"))
  expect_setequal(unique(gg$time), p$time.points)
  expect_identical(
    nrow(gg),
    nrow(p$curves$x1) * length(p$time.points) * length(p$curves)
  )
})

test_that("partial estimates are the wide curve columns pivoted long", {
  p <- partial_fixture()
  gg <- gg_boost_effect(p)

  for (k in seq_along(p$time.points)) {
    at_k <- gg[gg$variable == "x1" & gg$time == p$time.points[k], ]
    expect_equal(at_k$x, p$curves$x1$x)
    expect_equal(at_k$estimate, p$curves$x1[[k + 1L]])
  }
})

test_that("time is parsed to a number, not left as a label", {
  gg <- gg_boost_effect(marginal_fixture())

  expect_type(gg$time, "double")
  expect_false(any(is.na(gg$time)))
  expect_setequal(unique(gg$time), marginal_fixture()$time.points)
})

test_that("the marginal kind takes the smoothed curve, not the raw scatter", {
  m <- marginal_fixture()
  gg <- gg_boost_effect(m)

  first <- gg[gg$variable == "x1" & gg$time == m$time.points[1], ]
  expect_equal(first$x, m$smooth$x1[[1]]$x)
  expect_equal(first$estimate, m$smooth$x1[[1]]$y)
})

test_that("gg_boost_effect rejects a non-effect object", {
  expect_error(gg_boost_effect(data.frame(x = 1)), "gg_boost_effect")
  expect_error(gg_boost_effect(boost_fixture()), "partial.plot")
})

test_that("a single-response object carries its own response label", {
  gg <- gg_boost_effect(partial_fixture())

  expect_s3_class(gg$response, "factor")
  expect_identical(levels(gg$response), partial_fixture()$response.labels)
})

for (family in c("ordinal", "nominal")) {
  test_that(paste("a", family, "partial object gives one block per response"), {
    p <- partial_multi_fixture(family)
    gg <- gg_boost_effect(p)

    expect_s3_class(gg, "gg_boost_effect")
    expect_identical(levels(gg$response), p$response.labels)
    expect_identical(levels(gg$kind), "partial")
    expect_identical(
      nrow(gg),
      length(p$response.labels) * nrow(p$curves[[1]]$x1) *
        length(p$time.points)
    )
    # Each response's rows are that response's own curves, not a copy.
    for (q in seq_along(p$response.labels)) {
      at <- gg[gg$response == p$response.labels[q] &
                 gg$time == p$time.points[1], ]
      expect_equal(at$estimate, p$curves[[q]]$x1[[2L]])
    }
  })

  test_that(paste("a", family, "marginal object gives a block per response"), {
    m <- marginal_multi_fixture(family)
    gg <- gg_boost_effect(m)

    expect_identical(levels(gg$response), m$response.labels)
    expect_identical(levels(gg$kind), "marginal")
    for (q in seq_along(m$response.labels)) {
      at <- gg[gg$response == m$response.labels[q] &
                 gg$time == m$time.points[1], ]
      expect_equal(at$estimate, m$smooth[[q]]$x1[[1L]]$y)
    }
  })
}

test_that("a multi-response object without response labels still works", {
  p <- partial_multi_fixture("ordinal")
  p$response.labels <- NULL

  gg <- gg_boost_effect(p)
  expect_identical(levels(gg$response), names(p$curves))
})

test_that("the contract carries an x_label column", {
  gg <- gg_boost_effect(partial_fixture())

  expect_identical(
    names(gg),
    c("variable", "x", "x_label", "time", "estimate", "kind", "response")
  )
  expect_type(gg$x_label, "character")
})

test_that("a continuous covariate leaves x_label NA", {
  gg <- gg_boost_effect(partial_fixture())

  expect_true(all(is.na(gg$x_label)))
})

test_that("a factor covariate is extracted without coercion warnings", {
  # The defect this fixes: as.numeric() on a character grid produced an
  # all-NA x, four coercion warnings, and a plot with zero rows.
  expect_no_warning(gg <- gg_boost_effect(partial_factor_fixture()))

  expect_false(any(is.na(gg$x)))
  expect_false(any(is.na(gg$x_label)))
})

test_that("factor levels become labels with integer positions", {
  gg <- gg_boost_effect(partial_factor_fixture())

  expect_setequal(unique(gg$x_label), c("high", "low"))
  expect_setequal(unique(gg$x), c(1, 2))
  # The position must map one-to-one onto the label, or the axis lies.
  expect_identical(
    length(unique(paste(gg$x, gg$x_label))), length(unique(gg$x_label))
  )
})

test_that("a discrete covariate yields one row per level per time", {
  p <- partial_factor_fixture()
  gg <- gg_boost_effect(p)

  expect_identical(nrow(gg), 2L * length(p$time.points))
})

test_that("the marginal factor path extracts without warnings", {
  expect_no_warning(gg <- gg_boost_effect(marginal_factor_fixture()))

  expect_setequal(unique(gg$x_label), c("high", "low"))
  expect_identical(levels(gg$kind), "marginal")
})

test_that("a boostmlr_partial object yields one block per response", {
  bp <- boostmlr_partial_fixture()
  gg <- gg_boost_effect(bp)

  expect_s3_class(gg, "gg_boost_effect")
  expect_identical(
    names(gg),
    c("variable", "x", "x_label", "time", "estimate", "kind", "response")
  )
  expect_identical(levels(gg$response), bp$response.labels)
  expect_identical(levels(gg$variable), c("x1", "x2"))
  expect_identical(levels(gg$kind), "partial")
  expect_true(all(is.na(gg$x_label)))
})

test_that("BoostMLR estimates are the smoothed matrices pivoted long", {
  bp <- boostmlr_partial_fixture()
  gg <- gg_boost_effect(bp)
  cv <- bp$curves$x2

  for (q in seq_along(bp$response.labels)) {
    for (k in c(1L, length(cv$tm.unq))) {
      at <- gg[gg$variable == "x2" &
                 gg$response == bp$response.labels[q] &
                 gg$time == cv$tm.unq[k], ]
      expect_equal(at$x, cv$x.unq)
      expect_equal(at$estimate, cv$sList[[q]][, k])
    }
  }
})

test_that("a boostmlr_partial with mismatched responses is refused", {
  bp <- boostmlr_partial_fixture()
  bp$response.labels <- c("a", "b")

  expect_error(gg_boost_effect(bp), "response")
})
