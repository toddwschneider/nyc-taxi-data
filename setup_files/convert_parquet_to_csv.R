#!/usr/bin/env Rscript

# Set environment variable so that arrow is built with all optional features (including gzip support)
Sys.setenv(LIBARROW_MINIMAL = "false")

required_packages <- c(
  "arrow",
  "tidyverse",
  "glue"
)

# Define a personal library path
user_lib <- "~/R/libs"
if (!dir.exists(user_lib)) {
  dir.create(user_lib, recursive = TRUE)
}

# Prepend the user_lib to the existing .libPaths
.libPaths(c(user_lib, .libPaths()))

# Loop over each required package and install only if it isn't already available.
for(pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg,
                     dependencies = TRUE,
                     repos = "https://cloud.r-project.org",
                     lib = user_lib)
  }
}

suppressPackageStartupMessages({
  library(arrow)
  library(tidyverse)
  library(glue)
})

command_args <- commandArgs(trailingOnly = TRUE)
parquet_filename <- command_args[1]
csv_filename <- str_replace(parquet_filename, ".parquet$", ".csv")

rows <- read_parquet(parquet_filename)
print(glue("Read {nrow(rows)} rows from {parquet_filename}"))

if ("__index_level_0__" %in% names(rows)) {
  rows <- select(rows, -"__index_level_0__")
}

write_csv(rows, csv_filename, na = "")
print(glue("Wrote {nrow(rows)} rows to {csv_filename}"))
