#!/bin/bash

parent_path=$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd -P)
cd "$parent_path"

# See the ClickHouse README for more info
filename="../data/backfill_yellow_tripdata_2009_2010.parquet"

echo "`date`: beginning load for ${filename}"
clickhouse-client --database=nyc_tlc_data --param_filename=${filename} --queries-file=setup_files/load_yellow_trips.sql --progress
echo "`date`: done load for ${filename}"
