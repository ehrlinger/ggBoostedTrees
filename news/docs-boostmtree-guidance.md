* The help pages and vignettes now say how to use `boostmtree` correctly,
  drawing on a 50-seed simulation (100 subjects, `M = 400`, `nu = 0.25`,
  `randomForestSRC` 3.9.0 and 3.10.0). Documentation only; no behaviour
  changes.
  - `gg_boost_error()` and `autoplot.gg_boost_error()`: more iterations can
    overfit, unlike `ntree` in a random forest, and a curve that turns back
    up shows it. `m.opt` is one draw on a flat curve (156 to 400 across the
    seeds), so read the flattening and the error level instead.
  - A seed reproduces a fit only within one `randomForestSRC` version. Pin
    it (with `renv`) along with `set.seed()`, and set a seed before
    `vimp.boostmtree()`, and before `predict()` and `partial.plot()` under
    `na.action = "na.impute"`.
  - `boost_shadow()` and `gg_boost_vimp()`: a borderline importance verdict
    needs repeated runs, and refitting moves it as much as rerunning
    `vimp.boostmtree()`. The article's figure B section now advises refits,
    not reruns alone.
