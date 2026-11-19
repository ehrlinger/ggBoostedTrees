* `Remotes:` installs `boostmtree` 2.0.13 from the CCF fork (`v2.0.13-ccf`).
  Before 2.0.13, a fixed `boostmtree.control(seed = )` drew the same
  subsample for every tree, so with `cv.flag = TRUE` about 60% of subjects
  were never out of bag and their fitted trajectory was a flat line at the
  mean response of the other subjects. The test fixtures are refitted with
  2.0.13; the reference fit now grows `M = 100`, because the honest
  cross-validated error was still falling at 50 (`m.opt` is 88).
* `gg_boost_trajectory()`, and so `gg_boost_calibration()`, warn when a
  cross-validated `boostmtree` fit records subjects that were never out of bag
  by `m.opt`, read from the fit's own out-of-bag record (`gamma.i.list`), and
  name the cause. A flat trajectory alone does not warn: a fit with an
  intercept-only time design (`d = 0`) is flat by construction. Both document
  that such a fit stores out-of-bag predictions in `mu`, not the in-sample fit.
