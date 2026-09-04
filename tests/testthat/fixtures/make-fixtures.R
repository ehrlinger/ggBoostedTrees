# Regenerate the committed model fixture.
#
#   Rscript tests/testthat/fixtures/make-fixtures.R
#
# Run this only when the backend version changes. The .rds is committed so
# that R CMD check never refits a model; refitting would blow the check-time
# budget. Re-run rewrites the provenance file alongside it.
#
# cv.flag = TRUE is REQUIRED: without it boostmtree records no err.rate and
# no m.opt, and gg_boost_error() has nothing to extract.

library(boostmtree)

here <- file.path("tests", "testthat", "fixtures")
stopifnot(dir.exists(here))

## The model fixture is NOT refit when it already exists.
##
## boostmtree's $base.learner (the stored randomForestSRC ensembles) is not
## bit-reproducible across refits, so an unconditional refit rewrites the file
## on every run and invalidates every committed vdiffr snapshot downstream.
## Every field ggBoostedTrees actually extracts -- err.rate, mu, y.org, time,
## id.unique, rho, phi, lambda, m.opt -- IS bit-identical across refits, so the
## committed fixture stays valid indefinitely.
model.path <- file.path(here, "boost_continuous.rds")
if (file.exists(model.path) && !nzchar(Sys.getenv("REGENERATE_MODEL_FIXTURE"))) {
  message("boost_continuous.rds exists; not refitting. ",
          "Set REGENERATE_MODEL_FIXTURE=1 to force.")
} else {
  set.seed(7)
  sim <- simLong(
    n = 25, n.time = 4, rho = 0.8, model = 1, family = "continuous"
  )$data.list

  fit <- boostmtree(
    x = sim$features,
    tm = sim$time,
    id = sim$id,
    y = sim$y,
    family = "continuous",
    M = 50,
    cv.flag = TRUE,
    verbose = FALSE,
    control = boostmtree.control(seed = 7)
  )

  saveRDS(fit, model.path, compress = "xz")
}
fit <- readRDS(model.path)

writeLines(
  c(
    "Fixture: boost_continuous.rds",
    paste0("Backend: boostmtree ", as.character(packageVersion("boostmtree"))),
    "Source: ehrlinger/boostmtree_src@v2.0.2-ccf (subdir = boostmtree)",
    paste0("Generated: ", format(Sys.Date())),
    paste0("R: ", R.version.string),
    "Call: simLong(n = 25, n.time = 4, rho = 0.8, model = 1,",
    "  family = 'continuous'); boostmtree(M = 50, cv.flag = TRUE,",
    "  control = boostmtree.control(seed = 7)); set.seed(7)",
    paste0("m.opt: ", fit$m.opt),
    "",
    "Interpretation fixtures: vimp_marginal.rds, vimp_joint.rds,",
    "  effect_partial.rds, effect_marginal.rds",
    "Effect variables: x1, x2",
    "vimp() permutes and consumes RNG: set.seed(7) precedes each vimp call.",
    "partial.plot() and marginal.plot() are deterministic.",
    "The model fixture is not refit when present -- boostmtree's $base.learner",
    "  is not bit-reproducible across refits, though every field this package",
    "  extracts is. Force with REGENERATE_MODEL_FIXTURE=1.",
    "Note: vimp(joint = TRUE) CANNOT be generated under CRAN boostmtree 2.0.0,",
    "  which raises 'length of dimnames [1] not equal to array extent'.",
    "  The fork is required to regenerate vimp_joint.rds.",
    "",
    "Factor-covariate effect fixtures: effect_partial_factor.rds,",
    "  effect_marginal_factor.rds (covariate x2 as a two-level factor).",
    "  The underlying fit is deliberately NOT committed; only the effect",
    "  objects are needed and they are small.",
    "",
    "BoostMLR fixture: boostmlr_grow.rds",
    paste0("  BoostMLR ", if (requireNamespace("BoostMLR", quietly = TRUE)) {
      as.character(utils::packageVersion("BoostMLR"))
    } else {
      "not installed"
    }, " (CRAN); simLong(n = 20, N = 3, rho = 0.8, model = 1,"),
    "  q_x = 2, q_y = 0); BoostMLR(M = 50, VarFlag = TRUE); set.seed(3)",
    "  BoostMLR records no optimal iteration, so gg_boost_error()'s",
    "  optimal column is all FALSE for this backend."
  ),
  file.path(here, "boost_continuous.dcf")
)

cat("wrote fixture, m.opt =", fit$m.opt, "\n")

## Interpretation fixtures (Phase 3).
##
## vimp() is cheap but partial.plot() costs seconds per variable, which is far
## too slow for R CMD check. All four are committed and read from disk.
##
## Two variables is enough: it exercises the per-variable list structure while
## keeping generation quick and the files small.
effect.vars <- c("x1", "x2")

## vimp() permutes, so it consumes RNG: two calls on the SAME fit differ unless
## seeded. partial.plot() and marginal.plot() are deterministic and need no seed.
set.seed(7)
saveRDS(
  vimp.boostmtree(fit),
  file.path(here, "vimp_marginal.rds"), compress = "xz"
)
set.seed(7)
saveRDS(
  vimp.boostmtree(fit, joint = TRUE),
  file.path(here, "vimp_joint.rds"), compress = "xz"
)
saveRDS(
  partial.plot(
    fit, x.var.names = effect.vars, output = "data", verbose = FALSE
  ),
  file.path(here, "effect_partial.rds"), compress = "xz"
)
saveRDS(
  marginal.plot(
    fit, x.var.names = effect.vars, output = "data", verbose = FALSE
  ),
  file.path(here, "effect_marginal.rds"), compress = "xz"
)

cat("wrote interpretation fixtures for", paste(effect.vars, collapse = ", "), "\n")

## Effect fixtures with a FACTOR covariate.
##
## boostmtree returns a character x column for a factor predictor, one row per
## level rather than a grid. The fit itself is not committed: only the effect
## objects are needed, and they are a few kilobytes.
set.seed(11)
fac.sim <- simLong(n = 20, n.time = 4, model = 1)$data.list
fac.x <- fac.sim$features
fac.x$x2 <- factor(ifelse(fac.x$x2 > median(fac.x$x2), "high", "low"))

fac.fit <- boostmtree(
  x = fac.x, tm = fac.sim$time, id = fac.sim$id, y = fac.sim$y,
  M = 20, cv.flag = TRUE, verbose = FALSE,
  control = boostmtree.control(seed = 11)
)

saveRDS(
  partial.plot(fac.fit, x.var.names = "x2", output = "data", verbose = FALSE),
  file.path(here, "effect_partial_factor.rds"), compress = "xz"
)
saveRDS(
  marginal.plot(fac.fit, x.var.names = "x2", output = "data", verbose = FALSE),
  file.path(here, "effect_marginal_factor.rds"), compress = "xz"
)

cat("wrote factor-covariate effect fixtures\n")

## BoostMLR fixture (Phase 4).
##
## BoostMLR is a Suggests package, so guard its use here. The extractors
## themselves need no guard: they read list elements and never call a BoostMLR
## function, so S3 dispatch works off the class attribute alone.
##
## n = 20, N = 3, M = 50 gives 130 observations across 3 responses in about
## 300 KB. BoostMLR is natively multi-response, which is why this fixture is
## worth having beyond the second-backend proof: it is the first real
## multi-response object in the suite.
if (!requireNamespace("BoostMLR", quietly = TRUE)) {
  message("BoostMLR not installed; skipping boostmlr_grow.rds.")
} else {
  set.seed(3)
  mlr.sim <- BoostMLR::simLong(
    n = 20, N = 3, rho = 0.8, model = 1, q_x = 2, q_y = 0
  )$dtaL

  mlr.fit <- BoostMLR::BoostMLR(
    x = mlr.sim$features, tm = mlr.sim$time, id = mlr.sim$id, y = mlr.sim$y,
    M = 50, VarFlag = TRUE, Verbose = FALSE
  )

  saveRDS(mlr.fit, file.path(here, "boostmlr_grow.rds"), compress = "xz")
  cat("wrote BoostMLR fixture:", length(mlr.fit$tm), "observations,",
      ncol(mlr.fit$y), "responses\n")
}
