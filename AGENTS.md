# ggBoostedTrees

Graphics for longitudinal boosted-tree models. Constructors named
`gg_boost_*()` extract tidy, testable figure data; `autoplot()` methods render
that data. Keep extraction separate from rendering so another model backend
can be added without changing the plotting layer.

## Definition of done

- `devtools::test()` passes.
- `devtools::check()` has zero errors, warnings, and notes.
- `lintr::lint_package()` returns zero lints.
- Run `devtools::document()` after roxygen changes and commit generated `man/`
  and `NAMESPACE` changes.
- A plot change includes assertions on the extracted data, not only a smoke
  test that a ggplot object exists.

## Automated gates

The repository runs package checks on macOS, Windows, Ubuntu release, Ubuntu
devel, and Ubuntu oldrel. It also runs manual checks, coverage, lint, pkgdown,
and the family house-style check. The pkgdown site deploys from `main`; a
GitHub Release must not redeploy an older tagged site.

## Package rules

- `boostmtree` is the primary backend. `BoostMLR` support is deliberately
  partial and must remain explicit in documentation and method errors.
- Validate model-specific fields in extractors. Renderers consume the stable
  extracted object and must not reach back into a fitted model.
- Keep examples and tests synthetic. Do not add clinical data or identifiers.
- The `boostmtree` remote is pinned in `DESCRIPTION`; do not relax or remove
  that pin without verifying the supported object contract.

## Git and versioning

- Never push directly to `main`. Use a branch and pull request.
- Versions use three numeric components. Patch bumps are the default; minor
  and major bumps are maintainer decisions.
- A shipped change gets a `NEWS.md` entry. Name the version when preparing the
  release, not once per pull request.
- Do not force-push release tags. A GitHub Release must point at the tested
  commit already on `main`.

## Change discipline

Make the smallest change that satisfies the stated behavior. Avoid unrelated
refactoring, preserve the constructor/renderer boundary, and use tests as the
completion criterion.
