#!/bin/bash

yellow_schema="(vendor_id, tpep_pickup_datetime, tpep_dropoff_datetime, passenger_count, trip_distance, rate_code_id, store_and_fwd_flag, pickup_location_id, dropoff_location_id, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount, congestion_surcharge, airport_fee)"

for parquet_filename in data/yellow_tripdata*.parquet; do
  echo "`date`: converting ${parquet_filename} to csv"
  ./setup_files/convert_parquet_to_csv.R ${parquet_filename}

  csv_filename=${parquet_filename/.parquet/.csv}
  cat $csv_filename | psql nyc-taxi-data -c "COPY yellow_tripdata_staging ${yellow_schema} FROM stdin CSV HEADER;"
  echo "`date`: finished raw load for ${csv_filename}"

  psql nyc-taxi-data -f setup_files/populate_yellow_trips.sql
  echo "`date`: loaded trips for ${csv_filename}"

  rm -f $csv_filename
  echo "`date`: deleted ${csv_filename}"
done;
