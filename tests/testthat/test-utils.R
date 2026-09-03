test_that("%||% returns the left side unless it is NULL", {
  expect_identical(1L %||% 2L, 1L)
  expect_identical(NULL %||% 2L, 2L)
})

test_that(".boost_check_grow rejects non-boostmtree objects", {
  expect_error(
    .boost_check_grow(data.frame(x = 1), "gg_boost_error"),
    "gg_boost_error"
  )
})

test_that(".boost_response_labels falls back to y when q.set is NA", {
  obj <- structure(list(n.q = 1L, q.set = NA), class = "boostmtree")
  expect_identical(.boost_response_labels(obj), "y")
})

test_that(".boost_response_labels uses q.set when it is populated", {
  obj <- structure(list(n.q = 2L, q.set = c("lo", "hi")), class = "boostmtree")
  expect_identical(.boost_response_labels(obj), c("lo", "hi"))
})
