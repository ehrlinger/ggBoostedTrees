* `gg_boost_vimp()` pools importance runs. Pass a list of
  `vimp.boostmtree()` results, repeated runs on one fit or one run on each
  of several refits, and it returns a `gg_boost_vimp_pool` frame: for each
  covariate and panel, the share of runs in which it cleared that run's own
  shadow band, with percentiles of its margin over the band. The per-run
  bands and margins travel as the `runs` attribute. A run without shadow
  covariates, or on different covariates, stops with an error naming it. A
  single importance object behaves as before.
* `autoplot()` draws a pooled object as a box per covariate of the margin
  over the band (box 25th to 75th percentile, whiskers 15th to 85th), with
  each run as a point and the count of runs that cleared the band. The
  article's figure B section shows five pooled runs.
