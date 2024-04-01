#!/bin/bash

parent_path=$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd -P)
cd "$parent_path"

clickhouse-client -q "CREATE DATABASE nyc_tlc_data;"
clickhouse-client --database=nyc_tlc_data --queries-file=setup_files/create_clickhouse_schema.sql --progress

cat setup_files/taxi_zone_location_ids.csv | clickhouse-client --database=nyc_tlc_data -q "INSERT INTO taxi_zones (location_id, zone, borough, subregion) FORMAT CSV"
