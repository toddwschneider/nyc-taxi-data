#!/bin/bash

parent_path=$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd -P)
cd "$parent_path"

year_month_regex="tripdata_([0-9]{4})-([0-9]{2})"

for filename in ../data/yellow_tripdata*.parquet; do
  [[ $filename =~ $year_month_regex ]]
  year=${BASH_REMATCH[1]}

  # Yellow taxi files from 2009 and 2010 still have lat/lon instead of location IDs
  # See the ClickHouse README for more info
  if [ $year -lt 2011 ]; then
    continue
  fi

  echo "`date`: beginning load for ${filename}"
  clickhouse-client --database=nyc_tlc_data --param_filename=${filename} --queries-file=setup_files/load_yellow_trips.sql --progress
  echo "`date`: done load for ${filename}"
done;

for filename in ../data/green_tripdata*.parquet; do
  echo "`date`: beginning load for ${filename}"
  clickhouse-client --database=nyc_tlc_data --param_filename=${filename} --queries-file=setup_files/load_green_trips.sql --progress
  echo "`date`: done load for ${filename}"
done;
