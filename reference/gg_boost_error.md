# Boosting error trajectory data object

Extract the error path of a boosted multivariate tree fit as a function
of the boosting iteration, together with the optimal iteration selected
by cross-validation.

## Usage

``` r
gg_boost_error(object, use.rmse = TRUE, ...)
```

## Arguments

- object:

  A fitted
  [`boostmtree`](https://rdrr.io/pkg/boostmtree/man/boostmtree.html)
  object, or a fitted `BoostMLR` object.

- use.rmse:

  Logical. When `TRUE` (default) return the standardized `l2` error;
  when `FALSE` return the unstandardized squared error.

- ...:

  Not used; present for S3 consistency.

## Value

A `gg_boost_error` `data.frame` with columns:

- iteration:

  Integer boosting iteration, from 1.

- value:

  Numeric error at that iteration.

- response:

  Factor naming the response.

- optimal:

  Logical, `TRUE` at the cross-validated optimal iteration.

## Details

**The fit must have been grown with `cv.flag = TRUE`.** `boostmtree`
records `err.rate` and `m.opt` only when cross-validation ran; a default
fit carries neither, and there is no error path to extract. If this
function reports that the fit has no error path, refit with
`cv.flag = TRUE`.

**More iterations can overfit.** In a random forest, more trees never
hurt: `ntree` only steadies the average. Boosting is different. Each
iteration moves the fit closer to the training data, so the number of
iterations `M` and the learning rate `nu` together set how closely the
model fits. Too many, or too large a `nu`, and it fits the noise. The
cross-validated error path is where you see that: an error that falls,
flattens, and then turns back up has overfit past its minimum.

**`m.opt` is one draw, not a property of the data.** `m.opt` is the
iteration with the lowest cross-validated error. When the error is flat
over a long stretch, that minimum can land anywhere along it, and a
refit with another seed moves it. In one simulation (100 subjects,
`M = 400`, `nu = 0.25`, 50 seeds), `m.opt` ran from 156 to 400, with a
median near 385. That is one design at one sample size; how the spread
changes with more subjects was not measured. Read whether the curve has
flattened, and the error level it reaches, rather than the exact
`m.opt`. The caption of
[`autoplot.gg_boost_error`](https://ehrlinger.github.io/ggBoostedTrees/reference/autoplot.gg_boost_error.md)
reports the flattening.

**A seed reproduces a fit only within one randomForestSRC version.**
`boostmtree` grows its trees with `randomForestSRC`, and a new
`randomForestSRC` release can change the random stream. In the same
simulation, none of the 50 seeds gave an identical fit under
`randomForestSRC` 3.9.0 and 3.10.0, though the spread of fits matched.
To reproduce a fit, call
[`set.seed()`](https://rdrr.io/r/base/Random.html) and record and pin
the `randomForestSRC` version, with `renv` for example.

`boostmtree` stores the error on the standardized response scale in the
`l2` column. `use.rmse = FALSE` returns `(l2 * y.sd)^2`, the squared
error on the original scale.

This figure also accepts a `BoostMLR` *grow* fit (predict objects are
not supported – see below). `BoostMLR` records `Error_Rate` as an
M-by-response matrix already on a single scale, so there is no
`use.rmse` argument for that backend; `use.rmse = FALSE` is refused,
while `TRUE`, the default, names the scale it already returns.
`BoostMLR` grow objects also select no optimal iteration anywhere in the
object – `partial.BoostMLR()` takes `Mopt` as a user-supplied argument
instead – so `optimal` is `FALSE` for every row; deriving an argmin here
would report a choice the backend never made.

A `BoostMLR` **predict** object is refused outright, even though it
shares the `"BoostMLR"` class and also carries an `Error_Rate`. Its
`Error_Rate` is test error rather than the training path documented
above, and it records a real `Mopt` that this extractor would otherwise
silently discard and overwrite with `optimal = FALSE`.

## See also

[`plot.gg_boost_error`](https://ehrlinger.github.io/ggBoostedTrees/reference/autoplot.gg_boost_error.md),
[`gg_boost_path`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_path.md)

## Examples

``` r
# \donttest{
sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
fit <- boostmtree::boostmtree(
  x = sim$features, tm = sim$time, id = sim$id, y = sim$y,
  M = 50, cv.flag = TRUE, verbose = FALSE
)
gg_dta <- gg_boost_error(fit)
plot(gg_dta)

# }
```
