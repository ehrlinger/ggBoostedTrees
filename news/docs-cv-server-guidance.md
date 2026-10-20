* The README's section on what `cv.flag = TRUE` costs gains timings and peak
  memory from a server, by subjects and cores, and says that memory, not speed,
  limits the cores on a large fit: the parallel share levels off near 80%. It
  drops the claim that the share keeps rising with the number of subjects,
  which the server measurements did not bear out past about 1,000, and
  corrects the simulated data's visits per subject from 5 to about 9.
