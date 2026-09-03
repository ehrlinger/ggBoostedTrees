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

saveRDS(fit, file.path(here, "boost_continuous.rds"), compress = "xz")

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
    paste0("m.opt: ", fit$m.opt)
  ),
  file.path(here, "boost_continuous.dcf")
)

cat("wrote fixture, m.opt =", fit$m.opt, "\n")
