# Add shadow covariates before fitting

Append permuted copies of every covariate to a `boostmtree` design, so
that variable importance has a noise reference measured in the same fit.

## Usage

``` r
boost_shadow(x, id, k = 5)
```

## Arguments

- x:

  A `data.frame` of covariates, one row per observation, as passed to
  [`boostmtree`](https://rdrr.io/pkg/boostmtree/man/boostmtree.html).

- id:

  Subject identifier for each row of `x`.

- k:

  Number of shadow copies of each covariate. Defaults to 5.

## Value

`x` with `ncol(x) * k` shadow columns appended.

## Details

Variable importance from
[`vimp.boostmtree`](https://rdrr.io/pkg/boostmtree/man/vimp.boostmtree.html)
has no fixed scale. How much a covariate with no signal scores depends
on the fit: the more boosting, the more the trees lean on noise, and the
higher every importance climbs. A shadow is a copy of a covariate whose
values have been shuffled between subjects, so it keeps the covariate's
distribution but carries no information about the response. Fitted
alongside the real covariates, the shadows show what noise scores in
this fit.
[`autoplot.gg_boost_vimp`](https://ehrlinger.github.io/ggBoostedTrees/reference/autoplot.gg_boost_vimp.md)
draws the largest shadow importance as a band, and reads a covariate as
detectable only when it clears that band.

More shadows make the band stricter, because the largest of more noise
scores is higher. The band is a reference measured in the fit, not a
test with a known error rate. Each copy shuffles the subjects once for
every covariate, so the shadows keep the covariates' correlations with
each other; and a covariate with no effect of its own can clear the band
when it is correlated with one that has an effect. Each shadow widens
`x` by one column and slows the fit in proportion.

**A verdict near the band's edge needs repeated runs.** The band and the
importances both move from run to run, and a refit moves them as much as
a rerun of
[`vimp.boostmtree`](https://rdrr.io/pkg/boostmtree/man/vimp.boostmtree.html)
on the same fit. In one simulation (100 subjects, 5 shadow copies, 50
seeds), strong effects cleared the band in 98 to 100% of runs and true
nulls in 0 to 6%. Small or borderline effects cleared it in only 14 to
46%. That is one design at one sample size; other sizes were not
measured. Before reporting a covariate close to the band, refit and
rerun the importance under several seeds, and report how often it clears
the band.

Values are shuffled between subjects, not between rows, so each shadow
is constant within a subject, as a baseline covariate is. Covariates
must therefore be constant within subject; a time-varying covariate has
no subject-level value to shuffle and is refused.

Shadows are named `shadow1.<covariate>`, `shadow2.<covariate>`, and so
on;
[`gg_boost_vimp`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_vimp.md)
recognises them by that name. The shuffle uses R's random number
generator, so call [`set.seed()`](https://rdrr.io/r/base/Random.html)
first for a reproducible design.

## See also

[`gg_boost_vimp`](https://ehrlinger.github.io/ggBoostedTrees/reference/gg_boost_vimp.md),
[`autoplot.gg_boost_vimp`](https://ehrlinger.github.io/ggBoostedTrees/reference/autoplot.gg_boost_vimp.md)

## Examples

``` r
sim <- boostmtree::simLong(n = 25, n.time = 4, model = 1)$data.list
set.seed(1)
x <- boost_shadow(sim$features, sim$id, k = 2)
names(x)
#>  [1] "x1"         "x2"         "x3"         "x4"         "shadow1.x1"
#>  [6] "shadow1.x2" "shadow1.x3" "shadow1.x4" "shadow2.x1" "shadow2.x2"
#> [11] "shadow2.x3" "shadow2.x4"
```
