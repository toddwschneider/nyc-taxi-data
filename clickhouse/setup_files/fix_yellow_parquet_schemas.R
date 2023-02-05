#!/usr/bin/env Rscript --vanilla

source("setup_files/install_and_load_packages.R")

file_names = dir(
  path = "../data",
  pattern = "yellow_tripdata",
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
      improvement_surcharge = as.numeric(improvement_surcharge),
      congestion_surcharge = as.numeric(congestion_surcharge),
      airport_fee = as.numeric(airport_fee)
    ) %>%
    write_parquet(f)
}
