#!/bin/bash

# Set PostgreSQL connection parameters
export PGPASSWORD=password
PG_HOST="db_url"
PG_PORT=5432
PG_DB="db"
PG_USER="username"
PG_CONN="-h $PG_HOST -p $PG_PORT -d $PG_DB -U $PG_USER"

green_schema="(vendor_id, lpep_pickup_datetime, lpep_dropoff_datetime, store_and_fwd_flag, rate_code_id, pickup_location_id, dropoff_location_id, passenger_count, trip_distance, fare_amount, extra, mta_tax, tip_amount, tolls_amount, ehail_fee, improvement_surcharge, total_amount, payment_type, trip_type, congestion_surcharge)"

for parquet_filename in data/green_tripdata*.parquet; do
  echo "`date`: converting ${parquet_filename} to csv"
  Rscript --vanilla ./setup_files/convert_parquet_to_csv.R ${parquet_filename}

  csv_filename=${parquet_filename/.parquet/.csv}
  cat $csv_filename | psql $PG_CONN -c "COPY green_tripdata_staging ${green_schema} FROM stdin CSV HEADER;"
  echo "`date`: finished raw load for ${csv_filename}"

  psql $PG_CONN -f setup_files/populate_green_trips.sql
  echo "`date`: loaded trips for ${csv_filename}"

  rm -f $csv_filename
  echo "`date`: deleted ${csv_filename}"
done;
