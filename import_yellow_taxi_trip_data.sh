#!/bin/bash

year_month_regex="tripdata_([0-9]{4})-([0-9]{2})"

yellow_schema="(vendor_id, tpep_pickup_datetime, tpep_dropoff_datetime, passenger_count, trip_distance, rate_code_id, store_and_fwd_flag, pickup_location_id, dropoff_location_id, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount, congestion_surcharge, airport_fee)"

yellow_schema_pre_2011="(vendor_id, tpep_pickup_datetime, tpep_dropoff_datetime, passenger_count, trip_distance, pickup_longitude, pickup_latitude, rate_code_id, store_and_fwd_flag, dropoff_longitude, dropoff_latitude, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, total_amount)"

for parquet_filename in data/yellow_tripdata*.parquet; do
  [[ $parquet_filename =~ $year_month_regex ]]
  year=${BASH_REMATCH[1]}

  if [ $year -lt 2011 ]; then
    schema=$yellow_schema_pre_2011
  else
    schema=$yellow_schema
  fi

  echo "`date`: converting ${parquet_filename} to csv"
  ./setup_files/convert_parquet_to_csv.R ${parquet_filename}

  csv_filename=${parquet_filename/.parquet/.csv}
  cat $csv_filename | psql nyc-taxi-data -c "COPY yellow_tripdata_staging ${schema} FROM stdin CSV HEADER;"
  echo "`date`: finished raw load for ${csv_filename}"

  psql nyc-taxi-data -f setup_files/populate_yellow_trips.sql
  echo "`date`: loaded trips for ${csv_filename}"

  rm -f $csv_filename
  echo "`date`: deleted ${csv_filename}"
done;
