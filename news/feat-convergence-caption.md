* The `gg_boost_error()` plot's caption now reports convergence: the optimal
  iteration against the number grown, and the error's relative change over
  the last quarter of the iterations. An optimum at the last iteration with
  a change of a percent or so means the curve has flattened; a steep fall
  means refit with more iterations or a larger learning rate. Turn it off
  with `convergence = FALSE`.
