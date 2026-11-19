* New `boost_shadow(x, id, k = 5)` appends `k` shadow copies of every
  covariate, each shuffled between subjects, to give variable importance a
  noise reference measured in the fit itself. `gg_boost_vimp()` gains a
  logical `shadow` column that flags them by name.

* The `gg_boost_vimp()` plot's noise band now comes from the shadows: in
  each panel it runs up to the largest importance any shadow reached (or
  zero). Shadows set the band but are not drawn. The band from the largest
  negative importance is gone: with every tree drawing its own subsample,
  simulations showed negatives become rare as boosting increases while a
  pure-noise covariate scored as high as 0.57, so that band marked noise as
  detectable. A fit without shadows now draws no band and no
  detectable-or-not verdict, and the caption says so.

* The article *Four Figures From One boostmtree Fit* is refit with shadows,
  seeds set with `set.seed()` rather than `boostmtree.control(seed = )`, and
  a learning rate at which the error path flattens. It gains a section on
  reading the error path for convergence before the figures, and says that
  a verdict near the edge of the band can change between runs of
  `vimp.boostmtree()`.
