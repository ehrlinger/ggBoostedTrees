* The test fixtures' provenance file (`boost_continuous.dcf`) records the
  `randomForestSRC` version they were fitted under (3.10.0), and
  `make-fixtures.R` writes it. `boostmtree` grows its trees with
  `randomForestSRC`, and a seeded fit is reproduced only under the same
  version: 3.9.0 and 3.10.0 gave a different fit at every one of 50 seeds.
