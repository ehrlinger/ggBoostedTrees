* `Remotes:` installs `boostmtree` 2.0.4 from the CCF fork (`v2.0.4-ccf`), and
  the README's backend install line names that tag. 2.0.4 adds
  `boostmtree.control(cv.cores = )`, which runs the cross-validated fit's
  out-of-bag update on several cores, and is about 30% faster on one core;
  the fit is identical to 2.0.3's. The `Imports:` floor stays at 2.0.1,
  because nothing in this package uses the new argument.
