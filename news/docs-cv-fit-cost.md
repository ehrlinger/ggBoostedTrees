* The README and the getting-started vignette say what `cv.flag = TRUE`
  costs: cross-validation's time grows with the square of the number of
  subjects, with measured timings, and `boostmtree` 2.0.4's
  `boostmtree.control(cv.cores = )` runs it on several cores without changing
  the fit.
