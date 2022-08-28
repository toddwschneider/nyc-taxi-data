#!/usr/bin/env Rscript --vanilla

source("setup_files/install_and_load_packages.R")

file_names = dir(
  path = "../data",
  pattern = "fhv_tripdata",
  full.names = TRUE
)

for (f in file_names) {
  print(glue("Checking schema for {f}"))

  trips = read_parquet(f)

  col_types = trips %>%
    purrr::map(class) %>%
    unlist()

  if (all(col_types != "vctrs_unspecified")) {
    print(glue("No changes needed"))
    next
  }

  print(glue("Updating schema…"))

  trips %>%
    mutate(SR_Flag = as.numeric(SR_Flag)) %>%
    write_parquet(f)
}
