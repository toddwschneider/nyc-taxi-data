required_packages = c("arrow", "tidyverse", "glue")

installed_packages = rownames(installed.packages())
packages_to_install = required_packages[!(required_packages %in% installed_packages)]

if (length(packages_to_install) > 0) {
  install.packages(
    packages_to_install,
    dependencies = TRUE,
    repos = "https://cloud.r-project.org",
  )
}

suppressPackageStartupMessages({
  library(arrow)
  library(tidyverse)
  library(glue)
})
