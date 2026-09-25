#!/bin/bash

parent_path=$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd -P)
cd "$parent_path"

for filename in ../data/fhv_tripdata_*.parquet; do
  echo "`date`: beginning load for ${filename}"
  clickhouse client --database=nyc_tlc_data --param_filename="${filename}" --queries-file=setup_files/load_fhv_trips.sql --progress < "${filename}"
  echo "`date`: done load for ${filename}"
done;

for filename in ../data/fhvhv_tripdata_*.parquet; do
  echo "`date`: beginning load for ${filename}"
  clickhouse client --database=nyc_tlc_data --param_filename="${filename}" --queries-file=setup_files/load_fhvhv_trips.sql --progress < "${filename}"
  echo "`date`: done load for ${filename}"
done;
