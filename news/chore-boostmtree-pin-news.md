* `Remotes:` installs `boostmtree` 2.0.8 from the CCF fork (`v2.0.8-ccf`), and
  the README's backend install line names that tag. The `Imports:` floor stays
  at 2.0.1. Since 2.0.4, the fork's releases have made long fits faster and
  smaller without changing their results:
  - 2.0.5 makes an ordinal fit's cross-validation about 23% faster (600
    subjects, 4 cores).
  - 2.0.6 stores the cross-validation state as one vector per subject, so each
    forked worker holds about a quarter of the memory it did: on a server at
    4,000 subjects, 8 and 16 cores now finish where 2.0.4 ran out of memory.
  - 2.0.7 runs each forked worker on one BLAS thread. On a server whose R
    links a multithreaded OpenBLAS, 2.0.6's workers each started a thread per
    CPU and overloaded the machine: at 1,000 subjects on 4 cores, 2.0.7 took
    616 s where 2.0.6 took 1,488 s.
  - 2.0.8 makes partial effects walk the boosting steps one at a time instead
    of holding every step for every subject at once. On a synthetic ordinal
    fit one `partial.plot()` call fell from 87 s and 4.5 GB to 2.4 s and
    0.4 GB, and it adds a `progress` callback to `boostmtree()` and
    `partial.plot()`.
