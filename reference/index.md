# Package index

## 

Extract — pull a data frame out of a fit

Start here. Each extractor takes a fitted model and returns a tidy data
frame with a documented column contract, so what a figure shows can be
read, tested and reshaped before anything is drawn.
[`gg_boost_error()`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_error.md)
needs a fit grown with `cv.flag = TRUE`; `boostmtree` records the error
path and the optimal iteration only when cross-validation ran.

- [`gg_boost_error()`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_error.md)
  : Boosting error trajectory data object
- [`gg_boost_path()`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_path.md)
  : Boosting parameter path data object

## 

Render — draw the extracted object

The `autoplot()` method for each extracted class, with
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) as its alias.
Rendering reads only the column contract above, which is what lets a new
modelling backend be added by writing extractor methods and nothing
else.

- [`autoplot(`*`<gg_boost_error>`*`)`](https://ehrlinger.github.io/ggBoostedTrees/reference/autoplot.gg_boost_error.md)
  [`plot(`*`<gg_boost_error>`*`)`](https://ehrlinger.github.io/ggBoostedTrees/reference/autoplot.gg_boost_error.md)
  :

  Plot a `gg_boost_error` object

- [`autoplot(`*`<gg_boost_path>`*`)`](https://ehrlinger.github.io/ggBoostedTrees/reference/autoplot.gg_boost_path.md)
  [`plot(`*`<gg_boost_path>`*`)`](https://ehrlinger.github.io/ggBoostedTrees/reference/autoplot.gg_boost_path.md)
  :

  Plot a `gg_boost_path` object

## 

Shortcut — straight from a fit

Skips the two steps for the one figure worth looking at first. Every
other figure is reached through its own extractor.

- [`autoplot(`*`<boostmtree>`*`)`](https://ehrlinger.github.io/ggBoostedTrees/reference/autoplot.boostmtree.md)
  : Plot a boostmtree fit

## Package overview

The two-step shape – extract, then render – and why the seam is where it
is.

- [`ggBoostedTrees`](https://ehrlinger.github.io/ggBoostedTrees/reference/ggBoostedTrees-package.md)
  [`ggBoostedTrees-package`](https://ehrlinger.github.io/ggBoostedTrees/reference/ggBoostedTrees-package.md)
  : ggBoostedTrees: Visually Exploring Boosted Tree Models
