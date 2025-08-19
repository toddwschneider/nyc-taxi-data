#!/bin/bash

# Set PostgreSQL connection parameters
export PGPASSWORD=password
PG_HOST="db_url"
PG_PORT=5432
PG_DB="db"
PG_USER="username"
PG_CONN="-h $PG_HOST -p $PG_PORT -d $PG_DB -U $PG_USER"

# load 2014 Uber data into `fhv_trips` table
for filename in data/uber-raw-data*14.csv; do
  echo "`date`: beginning load for $filename"
  cat $filename | psql $PG_CONN -c "SET datestyle = 'ISO, MDY'; COPY uber_trips_2014 (pickup_datetime, pickup_latitude, pickup_longitude, base_code) FROM stdin CSV HEADER;"
  echo "`date`: finished raw load for $filename"
done;

psql $PG_CONN -f setup_files/populate_2014_uber_trips.sql
