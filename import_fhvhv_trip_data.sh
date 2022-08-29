#!/bin/bash

fhvhv_schema="(hvfhs_license_num, dispatching_base_num, originating_base_num, request_datetime, on_scene_datetime, pickup_datetime, dropoff_datetime, pickup_location_id, dropoff_location_id, trip_miles, trip_time, base_passenger_fare, tolls, black_car_fund, sales_tax, congestion_surcharge, airport_fee, tips, driver_pay, shared_request_flag, shared_match_flag, access_a_ride_flag, wav_request_flag, wav_match_flag)"

for parquet_filename in data/fhvhv_tripdata*.parquet; do
  echo "`date`: converting ${parquet_filename} to csv"
  ./setup_files/convert_parquet_to_csv.R ${parquet_filename}

  csv_filename=${parquet_filename/.parquet/.csv}
  cat $csv_filename | psql nyc-taxi-data -c "COPY fhv_trips_staging ${fhvhv_schema} FROM stdin CSV HEADER;"
  echo "`date`: finished raw load for ${csv_filename}"

  psql nyc-taxi-data -f setup_files/populate_fhv_trips.sql
  echo "`date`: loaded trips for ${csv_filename}"

  rm -f $csv_filename
  echo "`date`: deleted ${csv_filename}"
done;
