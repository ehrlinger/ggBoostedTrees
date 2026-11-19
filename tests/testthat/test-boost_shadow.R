shadow_data <- function() {
  x <- data.frame(
    a = c(1, 1, 2, 2, 2, 3),
    g = factor(c("u", "u", "v", "v", "v", "w"))
  )
  list(x = x, id = c(10, 10, 20, 20, 20, 30))
}

test_that("k shadow copies of every covariate are appended, named by copy", {
  d <- shadow_data()
  set.seed(1)
  out <- boost_shadow(d$x, d$id, k = 2)

  expect_identical(
    names(out),
    c("a", "g", "shadow1.a", "shadow1.g", "shadow2.a", "shadow2.g")
  )
  expect_identical(nrow(out), nrow(d$x))
  expect_identical(out[, c("a", "g")], d$x)
})

test_that("a shadow is constant within subject and keeps the values", {
  d <- shadow_data()
  set.seed(2)
  out <- boost_shadow(d$x, d$id, k = 3)

  for (col in grep("^shadow", names(out), value = TRUE)) {
    per_subject <- tapply(as.character(out[[col]]), d$id,
                          function(v) length(unique(v)))
    expect_true(all(per_subject == 1L))
    # A subject-level shuffle: the same multiset of subject values.
    first <- !duplicated(d$id)
    base <- sub("^shadow[0-9]+\\.", "", col)
    expect_identical(sort(as.character(out[[col]][first])),
                     sort(as.character(d$x[[base]][first])))
  }
  expect_s3_class(out$shadow1.g, "factor")
})

test_that("shadows are shuffled independently of each other", {
  set.seed(3)
  x <- data.frame(a = seq_len(40))
  out <- boost_shadow(x, seq_len(40), k = 2)

  expect_false(identical(out$shadow1.a, out$shadow2.a))
  expect_false(identical(out$shadow1.a, x$a))
})

test_that("the default is five copies", {
  d <- shadow_data()
  expect_identical(ncol(boost_shadow(d$x, d$id)), 2L + 2L * 5L)
})

test_that("a covariate that varies within subject is refused", {
  d <- shadow_data()
  d$x$a[2] <- 9

  expect_error(boost_shadow(d$x, d$id), "'a' vary within subject")
})

test_that("bad inputs are refused", {
  d <- shadow_data()

  expect_error(boost_shadow(as.matrix(d$x), d$id), "must be a data.frame")
  expect_error(boost_shadow(d$x, d$id[-1]), "'id' has 5")
  expect_error(boost_shadow(d$x, d$id, k = 0), "positive whole number")
  expect_error(boost_shadow(d$x, d$id, k = 1.5), "positive whole number")
  expect_error(boost_shadow(boost_shadow(d$x, d$id, k = 1), d$id),
               "already has shadow-named")
})

test_that("gg_boost_vimp recognises the shadows boost_shadow names", {
  set.seed(4)
  out <- boost_shadow(data.frame(x1 = 1:3), 1:3, k = 2)

  expect_identical(.is_shadow(names(out)), c(FALSE, TRUE, TRUE))
})
