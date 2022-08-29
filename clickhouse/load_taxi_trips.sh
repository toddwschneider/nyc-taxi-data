#!/bin/bash

parent_path=$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd -P)
cd "$parent_path"

for filename in ../data/yellow_tripdata*.parquet; do
  echo "`date`: beginning load for ${filename}"
  clickhouse-client --database=nyc_tlc_data --param_filename=${filename} --queries-file=setup_files/load_yellow_trips.sql --progress
  echo "`date`: done load for ${filename}"
done;

for filename in ../data/green_tripdata*.parquet; do
  echo "`date`: beginning load for ${filename}"
  clickhouse-client --database=nyc_tlc_data --param_filename=${filename} --queries-file=setup_files/load_green_trips.sql --progress
  echo "`date`: done load for ${filename}"
done;
