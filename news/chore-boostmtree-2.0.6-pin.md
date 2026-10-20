* `Remotes:` installs `boostmtree` 2.0.6 from the CCF fork (`v2.0.6-ccf`), and
  the README's backend install line names that tag. 2.0.6 stores the
  cross-validation state as one vector per subject, so each forked worker
  holds about a quarter of the memory it did, and a fit can use more cores in
  the same memory: on a server at 4,000 subjects, 8 and 16 cores now finish
  where 2.0.4 ran out of memory. The fit is unchanged. The `Imports:` floor
  stays at 2.0.1.
