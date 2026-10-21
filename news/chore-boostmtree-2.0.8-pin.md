* `Remotes:` installs `boostmtree` 2.0.8 from the CCF fork (`v2.0.8-ccf`), and
  the README's backend install line names that tag. 2.0.7 runs each forked
  cross-validation worker on one BLAS thread: on a server whose R links a
  multithreaded OpenBLAS, 2.0.6's workers each started a thread per CPU and
  overloaded the machine, and at 1,000 subjects on 4 cores 2.0.7 took 616 s
  where 2.0.6 took 1,488 s. 2.0.8 makes partial effects walk the boosting steps
  one at a time instead of holding every step for every subject at once: on a
  synthetic ordinal fit, one `partial.plot()` call fell from 87 s and 4.5 GB to
  2.4 s and 0.4 GB, with results unchanged. It also adds a `progress` callback
  to `boostmtree()` and `partial.plot()`. The `Imports:` floor stays at 2.0.1.
