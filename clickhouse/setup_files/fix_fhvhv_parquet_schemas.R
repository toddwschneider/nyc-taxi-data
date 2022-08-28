#!/usr/bin/env Rscript --vanilla

source("setup_files/install_and_load_packages.R")

file_names = dir(
  path = "../data",
  pattern = "fhvhv_tripdata",
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
    mutate(
      airport_fee = as.numeric(airport_fee),
      wav_match_flag = as.character(wav_match_flag)
    ) %>%
    write_parquet(f)
}
