* `Remotes:` installs `boostmtree` 2.0.11 from the CCF fork (`v2.0.11-ccf`),
  and the README's backend install line names that tag. The `Imports:` floor
  stays at 2.0.1. The fork's releases since 2.0.8:
  - 2.0.9 holds about 60% to 70% less memory per boosting step in a fitted
    object.
  - 2.0.10 fixes `predict()` and `partial.plot()` stopping with "subscript out
    of bounds" on a fit with `na.action = "na.omit"` when a row of `x` has a
    missing covariate, and rejects a bad `boostmtree.control(cv.cores = )`
    before the first tree.
  - 2.0.11 makes `partial.plot()` predict only at the time points it plots,
    and walks each step's out-of-bag list once in a cross-validated
    prediction instead of scanning it for every subject. Results match 2.0.10.
