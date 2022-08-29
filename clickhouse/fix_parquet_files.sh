#!/bin/bash

parent_path=$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd -P)
cd "$parent_path"

./setup_files/fix_fhv_parquet_schemas.R
./setup_files/fix_fhvhv_parquet_schemas.R
./setup_files/fix_green_parquet_schemas.R
./setup_files/fix_yellow_parquet_schemas.R
