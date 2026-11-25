* `boost_shadow()` accepts labeled covariates. It compared each column with
  its subject-level values attributes and all, and subsetting drops a column's
  `label`, so every labeled column, as study data read from SAS carries, was
  refused as varying within subject. It now compares the values only.
