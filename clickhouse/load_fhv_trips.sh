#!/bin/bash

parent_path=$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd -P)
cd "$parent_path"

for filename in ../data/fhv_tripdata*.parquet; do
  echo "`date`: beginning load for ${filename}"
  clickhouse-client --database=nyc_tlc_data --param_filename=${filename} --queries-file=setup_files/load_fhv_trips.sql --progress
  echo "`date`: done load for ${filename}"
done;

for filename in ../data/fhvhv_tripdata*.parquet; do
  echo "`date`: beginning load for ${filename}"
  clickhouse-client --database=nyc_tlc_data --param_filename=${filename} --queries-file=setup_files/load_fhvhv_trips.sql --progress
  echo "`date`: done load for ${filename}"
done;
