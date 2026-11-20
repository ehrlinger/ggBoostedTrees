# Three runs with known bands, built from vimp_shadow_fixture(). The real
# covariates are the same in every run; only the shadows move the band.
#   run a: band 0.03 (main), 0.05 (interaction)
#   run b: band 0.015, 0.035, so x2's main and x3's interaction clear it
#   run c: band 0 (every shadow below zero, floored), 0.5, so x2's
#          interaction does not clear it
pool_runs <- function() {
  list(
    a = vimp_shadow_fixture(), # nolint: object_usage_linter. A test helper.
    b = vimp_shadow_fixture(shadow_main = c(0.015, 0),
                            shadow_inter = c(0.035, 0)),
    c = vimp_shadow_fixture(shadow_main = c(-0.02, -0.01),
                            shadow_inter = c(0.5, 0.1))
  )
}

cell <- function(gg, variable, component) {
  gg[gg$variable == variable & gg$component == component, , drop = FALSE]
}

test_that("a list of runs returns the documented column contract", {
  gg <- gg_boost_vimp(pool_runs())

  expect_s3_class(gg, "gg_boost_vimp_pool")
  expect_false(inherits(gg, "gg_boost_vimp"))
  expect_identical(
    names(gg),
    c("variable", "component", "response", "n_runs", "n_detected", "share",
      "median_importance", "q15", "q25", "q50", "q75", "q85")
  )
  expect_identical(
    names(attr(gg, "runs")),
    c("variable", "component", "response", "run", "importance", "band",
      "margin", "detected")
  )
})

test_that("shadows are pooled into the bands, not reported as variables", {
  gg <- gg_boost_vimp(pool_runs())

  expect_identical(levels(gg$variable), c("x1", "x2", "x3", "x4"))
  expect_identical(nrow(gg), 8L)
  expect_identical(nrow(attr(gg, "runs")), 24L)
})

test_that("each run is judged against its own band", {
  runs <- attr(gg_boost_vimp(pool_runs()), "runs")

  band <- tapply(runs$band, list(runs$run, runs$component), unique)
  expect_equal(band["a", "main"], 0.03)
  expect_equal(band["b", "main"], 0.015)
  expect_equal(band["c", "main"], 0)
  expect_equal(band["a", "interaction"], 0.05)
  expect_equal(band["b", "interaction"], 0.035)
  expect_equal(band["c", "interaction"], 0.5)
  expect_equal(runs$margin, runs$importance - runs$band)
  expect_identical(runs$detected, runs$margin > 0)
})

test_that("the share counts the runs that cleared their band", {
  gg <- gg_boost_vimp(pool_runs())

  expect_identical(gg$n_runs, rep(3L, 8L))
  expect_identical(cell(gg, "x1", "main")$n_detected, 3L)
  expect_identical(cell(gg, "x2", "main")$n_detected, 2L)
  expect_identical(cell(gg, "x3", "main")$n_detected, 1L)
  expect_identical(cell(gg, "x4", "main")$n_detected, 0L)
  expect_identical(cell(gg, "x2", "interaction")$n_detected, 2L)
  expect_identical(cell(gg, "x3", "interaction")$n_detected, 1L)
  expect_equal(gg$share, gg$n_detected / gg$n_runs)
})

test_that("the percentiles are of the margin over runs", {
  gg <- gg_boost_vimp(pool_runs())
  x2 <- cell(gg, "x2", "main")

  # Margins for x2's main effect: -0.01 (a), 0.005 (b), 0.02 (c).
  expect_equal(x2$q50, 0.005)
  expect_equal(x2$q25, -0.0025)
  expect_equal(x2$q75, 0.0125)
  expect_equal(x2$q15, -0.0055)
  expect_equal(x2$q85, 0.0155)
  expect_equal(x2$median_importance, 0.02)
})

test_that("runs are labelled by list names, or numbered", {
  named <- attr(gg_boost_vimp(pool_runs()), "runs")
  expect_identical(levels(named$run), c("a", "b", "c"))

  numbered <- attr(gg_boost_vimp(unname(pool_runs())), "runs")
  expect_identical(levels(numbered$run), c("1", "2", "3"))
})

test_that("the run count, metric and time effect ride along", {
  runs <- pool_runs()
  gg <- gg_boost_vimp(runs)

  expect_identical(attr(gg, "n_runs"), 3L)
  expect_identical(attr(gg, "metric"), runs$a$metric)
  expect_equal(attr(gg, "time.effect"), runs$a$time.effect)
})

test_that("one run in a list pools to shares of 0 or 1", {
  gg <- gg_boost_vimp(list(vimp_shadow_fixture()))

  expect_identical(attr(gg, "n_runs"), 1L)
  expect_true(all(gg$share %in% c(0, 1)))
  expect_equal(gg$q50, gg$q15)
  # The same verdicts the single-run figure draws: x1 main, x2 interaction.
  expect_identical(
    as.character(gg$variable[gg$share == 1]), c("x1", "x2")
  )
})

test_that("components can be selected", {
  gg <- gg_boost_vimp(pool_runs(), components = "interaction")

  expect_identical(levels(gg$component), "interaction")
  expect_identical(nrow(gg), 4L)
})

test_that("a single vimp object is not pooled", {
  gg <- gg_boost_vimp(vimp_shadow_fixture())

  expect_s3_class(gg, "gg_boost_vimp")
  expect_false(inherits(gg, "gg_boost_vimp_pool"))
})

test_that("an empty list or bad run names stop", {
  expect_error(gg_boost_vimp(list()), "empty")
  runs <- pool_runs()
  names(runs) <- c("a", "", "c")
  expect_error(gg_boost_vimp(runs), "name every run")
  names(runs) <- c("a", "a", "c")
  expect_error(gg_boost_vimp(runs), "name every run")
})

test_that("a run that is not a vimp.boostmtree object stops, by name", {
  runs <- pool_runs()
  runs$b <- data.frame(x = 1)

  expect_error(gg_boost_vimp(runs), "run .b. is an object of class")
})

test_that("a run with no shadows stops, by name", {
  runs <- pool_runs()
  runs$c <- vimp_fixture()

  expect_error(gg_boost_vimp(runs), "run .c. has no shadow")
})

test_that("a run on different covariates stops, by name", {
  runs <- pool_runs()
  v <- runs$b
  rownames(v$main)[3] <- "z3"
  rownames(v$interaction)[3] <- "z3:time"
  runs$b <- v

  expect_error(gg_boost_vimp(runs), "run .b. differs .* covariates")
})

test_that("a run on a different metric stops, by name", {
  runs <- pool_runs()
  runs$c$metric <- "something else"

  expect_error(gg_boost_vimp(runs), "run .c. differs .* metric")
})
