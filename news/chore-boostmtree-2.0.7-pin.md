* `Remotes:` installs `boostmtree` 2.0.7 from the CCF fork (`v2.0.7-ccf`), and
  the README's backend install line names that tag. 2.0.7 runs each forked
  cross-validation worker on one BLAS thread. On a server whose R links a
  multithreaded OpenBLAS, 2.0.6's workers each started a thread per CPU and
  overloaded the machine: at 1,000 subjects on 4 cores, 2.0.7 took 616 s
  where 2.0.6 took 1,488 s. The `Imports:` floor stays at 2.0.1.
