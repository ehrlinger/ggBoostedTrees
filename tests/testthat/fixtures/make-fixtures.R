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
dcf.path <- file.path(here, "boost_continuous.dcf")
regenerate <- nzchar(Sys.getenv("REGENERATE_MODEL_FIXTURE"))
if (file.exists(model.path) && !regenerate) {
  message("boost_continuous.rds exists; not refitting. ",
          "Set REGENERATE_MODEL_FIXTURE=1 to force.")
  # A reused model keeps the randomForestSRC version it was fitted under,
  # not the one installed now.
  rf.line <- grep("^randomForestSRC: ",
                  if (file.exists(dcf.path)) readLines(dcf.path) else "",
                  value = TRUE)
  rf.version <- if (length(rf.line)) {
    sub("^randomForestSRC: ", "", rf.line[1])
  } else {
    "unknown (not recorded when the model was fitted)"
  }
} else {
  rf.version <- as.character(packageVersion("randomForestSRC"))
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
    # M = 100, not 50: since boostmtree 2.0.13 a fixed seed no longer reuses
    # one subsample for every tree, and the honest cross-validated error is
    # still falling at 50. 100 gives an interior m.opt (88).
    M = 100,
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
    # boostmtree grows its trees with randomForestSRC, and a seed reproduces
    # a fit only under the same rfsrc version (3.9.0 and 3.10.0 gave a
    # different fit at every one of 50 seeds), so the version is part of the
    # provenance.
    paste0("randomForestSRC: ", rf.version),
    "Source: ehrlinger/boostmtree_src@v2.0.13-ccf (subdir = boostmtree)",
    paste0("Generated: ", format(Sys.Date())),
    paste0("R: ", R.version.string),
    "Call: simLong(n = 25, n.time = 4, rho = 0.8, model = 1,",
    "  family = 'continuous'); boostmtree(M = 100, cv.flag = TRUE,",
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
    "Multi-response effect fixtures: effect_{partial,marginal}_{ordinal,",
    "  nominal}.rds (covariate x1; three-level response, two components).",
    "  simLong(n = 20, n.time = 4, model = 1); boostmtree(M = 20,",
    "  control = boostmtree.control(seed = 19)); set.seed(19). Fits not",
    "  committed.",
    "",
    "BoostMLR fixture: boostmlr_grow.rds",
    paste0("  BoostMLR ", if (requireNamespace("BoostMLR", quietly = TRUE)) {
      as.character(utils::packageVersion("BoostMLR"))
    } else {
      "not installed"
    }, " (CRAN); simLong(n = 20, N = 3, rho = 0.8, model = 1,"),
    "  q_x = 2, q_y = 0); BoostMLR(M = 50, VarFlag = TRUE); set.seed(3)",
    "  BoostMLR records no optimal iteration, so gg_boost_error()'s",
    "  optimal column is all FALSE for this backend.",
    "  boostmlr_vimp.rds: predictBoostMLR(importance = TRUE,",
    "  setting_seed = TRUE, seed_value = 3) on it, keeping vimp, x_Names,",
    "  y_Names. boostmlr_partial.rds: boostmlr_partial(fit, c('x1', 'x2')).",
    "",
    "Predict fixture: boost_predict.rds, predict(fit, x = fit$x) keeping n.q,",
    "  q.set, id.unique, time and mu only (the full object is about 4.4 MB).",
    "",
    "Intercept-only fixture: boost_d0.rds, simLong(n = 20, n.time = 4,",
    "  model = 1); boostmtree(M = 15, d = 0, cv.flag = TRUE,",
    "  control = boostmtree.control(seed = 4)); set.seed(4). Only the fields",
    "  gg_boost_trajectory() reads, gamma.i.list included.",
    "",
    "Seed-defect fixture: boost_seed_defect.rds, FROZEN, not written by this",
    "  script. The same fields taken from boost_continuous.rds as fitted",
    "  with boostmtree 2.0.2 (M = 50, seed = 7; m.opt 19), before 2.0.13",
    "  drew a fresh subsample per tree: 16 of 25 subjects never out of bag."
  ),
  dcf.path
)

cat("wrote fixture, m.opt =", fit$m.opt, "\n")

## Slimmed predict fixture (calibration cohort curve).
##
## predict(fit, x = fit$x) on the committed fit is deterministic, but the full
## object is about 4.4 MB. Only the fields gg_boost_trajectory() reads are
## kept, with the class, which leaves under 1 KB.
pred <- predict(fit, x = fit$x)
pred.slim <- structure(
  pred[c("n.q", "q.set", "id.unique", "time", "mu")],
  class = class(pred)
)
saveRDS(pred.slim, file.path(here, "boost_predict.rds"), compress = "xz")
cat("wrote slimmed predict fixture\n")

## Intercept-only time design fixture (d = 0).
##
## With d = 0 every subject's fitted trajectory is flat by construction, which
## is not the out-of-bag defect gg_boost_trajectory() warns about. Every
## subject here is out of bag by m.opt. Only the fields the extractor reads
## are kept, with the class; gamma.i.list is the fit's own out-of-bag record.
set.seed(4)
sim.d0 <- simLong(n = 20, n.time = 4, model = 1)$data.list
fit.d0 <- boostmtree(
  x = sim.d0$features, tm = sim.d0$time, id = sim.d0$id, y = sim.d0$y,
  M = 15, d = 0, cv.flag = TRUE, verbose = FALSE,
  control = boostmtree.control(seed = 4)
)
saveRDS(
  structure(
    fit.d0[c("n.q", "q.set", "family", "id.unique", "time", "mu", "y.org",
             "cv.flag", "m.opt", "gamma.i.list")],
    class = class(fit.d0)
  ),
  file.path(here, "boost_d0.rds"),
  compress = "xz"
)
cat("wrote d = 0 fixture, m.opt =", fit.d0$m.opt, "\n")

## Interpretation fixtures (Phase 3).
##
## vimp() is cheap but partial.plot() costs seconds per variable, which is far
## too slow for R CMD check. All four are committed and read from disk.
##
## Two variables is enough: it exercises the per-variable list structure while
## keeping generation quick and the files small.
effect.vars <- c("x1", "x2")

## vimp() permutes, so it consumes RNG: two calls on the SAME fit differ unless
## seeded. partial.plot() and marginal.plot() are deterministic and need
## no seed.
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

cat("wrote interpretation fixtures for",
    paste(effect.vars, collapse = ", "), "\n")

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

## BoostMLR importance and partial-effect fixtures.
##
## Built from the COMMITTED grow fixture, so they stay consistent with it.
## BoostMLR computes importance inside prediction; the full predict object is
## large, so only the fields gg_boost_vimp() reads are kept, with the class.
## boostmlr_partial() is this package's own wrapper, hence load_all().
if (requireNamespace("BoostMLR", quietly = TRUE)) {
  pkgload::load_all(quiet = TRUE)
  mlr.fit <- readRDS(file.path(here, "boostmlr_grow.rds"))
  mlr.pred <- BoostMLR::predictBoostMLR(
    mlr.fit, x = mlr.fit$x, tm = mlr.fit$tm, id = mlr.fit$id, y = mlr.fit$y,
    importance = TRUE, setting_seed = TRUE, seed_value = 3L
  )
  saveRDS(
    structure(mlr.pred[c("vimp", "x_Names", "y_Names")],
              class = class(mlr.pred)),
    file.path(here, "boostmlr_vimp.rds"), compress = "xz"
  )
  saveRDS(
    boostmlr_partial(mlr.fit, c("x1", "x2")),
    file.path(here, "boostmlr_partial.rds"), compress = "xz"
  )
  cat("wrote BoostMLR importance and partial-effect fixtures\n")
}

## Multi-response effect fixtures (ordinal and nominal).
##
## n.q > 1 is reachable only for family = "ordinal" or "nominal". partial.plot()
## and marginal.plot() then nest $curves / $smooth one level deeper, as
## [[response]][[variable]], and label the outer level in $response.labels.
## A three-level response gives two components for either family. One
## variable keeps the files small. The fits are not committed.
set.seed(19)
mr.sim <- simLong(n = 20, n.time = 4, model = 1)$data.list
mr.cut <- cut(
  mr.sim$y, c(-Inf, quantile(mr.sim$y, c(1 / 3, 2 / 3)), Inf),
  labels = c("low", "mid", "high")
)
mr.fits <- list(
  ordinal = boostmtree(
    x = mr.sim$features, tm = mr.sim$time, id = mr.sim$id,
    y = as.integer(mr.cut), family = "ordinal", M = 20, verbose = FALSE,
    control = boostmtree.control(seed = 19)
  ),
  nominal = boostmtree(
    x = mr.sim$features, tm = mr.sim$time, id = mr.sim$id,
    y = mr.cut, family = "nominal", M = 20, verbose = FALSE,
    control = boostmtree.control(seed = 19)
  )
)
for (fam in names(mr.fits)) {
  saveRDS(
    partial.plot(
      mr.fits[[fam]], x.var.names = "x1", output = "data", verbose = FALSE
    ),
    file.path(here, paste0("effect_partial_", fam, ".rds")), compress = "xz"
  )
  saveRDS(
    marginal.plot(
      mr.fits[[fam]], x.var.names = "x1", output = "data", verbose = FALSE
    ),
    file.path(here, paste0("effect_marginal_", fam, ".rds")), compress = "xz"
  )
}

cat("wrote multi-response effect fixtures\n")
