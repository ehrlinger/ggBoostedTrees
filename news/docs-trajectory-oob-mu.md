* `gg_boost_trajectory()` and `gg_boost_calibration()` now document that a
  `boostmtree` fit grown with `cv.flag = TRUE` stores out-of-bag predictions
  in `mu`, and that `boostmtree` 2.0.x with a fixed `control$seed` leaves about
  60% of subjects with a flat fitted trajectory. Until the fork draws a fresh
  subsample at each iteration, grow with `control$seed = NULL` after
  `set.seed()`.
