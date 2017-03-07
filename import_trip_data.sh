#!/bin/bash

year_month_regex="tripdata_([0-9]{4})-([0-9]{2})"

green_schema_pre_2015="(vendor_id,lpep_pickup_datetime,lpep_dropoff_datetime,store_and_fwd_flag,rate_code_id,pickup_longitude,pickup_latitude,dropoff_longitude,dropoff_latitude,passenger_count,trip_distance,fare_amount,extra,mta_tax,tip_amount,tolls_amount,ehail_fee,total_amount,payment_type,trip_type,junk1,junk2)"

green_schema_2015_h1="(vendor_id,lpep_pickup_datetime,lpep_dropoff_datetime,store_and_fwd_flag,rate_code_id,pickup_longitude,pickup_latitude,dropoff_longitude,dropoff_latitude,passenger_count,trip_distance,fare_amount,extra,mta_tax,tip_amount,tolls_amount,ehail_fee,improvement_surcharge,total_amount,payment_type,trip_type,junk1,junk2)"

green_schema_2015_h2_2016_h1="(vendor_id,lpep_pickup_datetime,lpep_dropoff_datetime,store_and_fwd_flag,rate_code_id,pickup_longitude,pickup_latitude,dropoff_longitude,dropoff_latitude,passenger_count,trip_distance,fare_amount,extra,mta_tax,tip_amount,tolls_amount,ehail_fee,improvement_surcharge,total_amount,payment_type,trip_type)"

green_schema_2016_h2="(vendor_id,lpep_pickup_datetime,lpep_dropoff_datetime,store_and_fwd_flag,rate_code_id,pickup_location_id,dropoff_location_id,passenger_count,trip_distance,fare_amount,extra,mta_tax,tip_amount,tolls_amount,ehail_fee,improvement_surcharge,total_amount,payment_type,trip_type,junk1,junk2)"

yellow_schema_pre_2015="(vendor_id,tpep_pickup_datetime,tpep_dropoff_datetime,passenger_count,trip_distance,pickup_longitude,pickup_latitude,rate_code_id,store_and_fwd_flag,dropoff_longitude,dropoff_latitude,payment_type,fare_amount,extra,mta_tax,tip_amount,tolls_amount,total_amount)"

yellow_schema_2015_2016_h1="(vendor_id,tpep_pickup_datetime,tpep_dropoff_datetime,passenger_count,trip_distance,pickup_longitude,pickup_latitude,rate_code_id,store_and_fwd_flag,dropoff_longitude,dropoff_latitude,payment_type,fare_amount,extra,mta_tax,tip_amount,tolls_amount,improvement_surcharge,total_amount)"

yellow_schema_2016_h2="(vendor_id,tpep_pickup_datetime,tpep_dropoff_datetime,passenger_count,trip_distance,rate_code_id,store_and_fwd_flag,pickup_location_id,dropoff_location_id,payment_type,fare_amount,extra,mta_tax,tip_amount,tolls_amount,improvement_surcharge,total_amount,junk1,junk2)"

# if 2010-02 and 2010-03 yellow files give errors about extra columns, remove offending rows:
# sed -E '/(.*,){18,}/d' data/yellow_tripdata_2010-02.csv > data/yellow_tripdata_2010-02.csv
# sed -E '/(.*,){18,}/d' data/yellow_tripdata_2010-03.csv > data/yellow_tripdata_2010-03.csv

for filename in data/green*.csv; do
  [[ $filename =~ $year_month_regex ]]
  year=${BASH_REMATCH[1]}
  month=$((10#${BASH_REMATCH[2]}))

  if [ $year -lt 2015 ]; then
    schema=$green_schema_pre_2015
  elif [ $year -eq 2015 ] && [ $month -lt 7 ]; then
    schema=$green_schema_2015_h1
  elif [ $year -eq 2015 ] || ([ $year -eq 2016 ] && [ $month -lt 7 ]); then
    schema=$green_schema_2015_h2_2016_h1
  else
    schema=$green_schema_2016_h2
  fi

  echo "`date`: beginning load for ${filename}"
  sed $'s/\r$//' $filename | sed '/^$/d' | psql nyc-taxi-data -c "COPY green_tripdata_staging ${schema} FROM stdin CSV HEADER;"
  echo "`date`: finished raw load for ${filename}"
  psql nyc-taxi-data -f populate_green_trips.sql
  echo "`date`: loaded trips for ${filename}"
done;

for filename in data/yellow*.csv; do
  [[ $filename =~ $year_month_regex ]]
  year=${BASH_REMATCH[1]}
  month=$((10#${BASH_REMATCH[2]}))

  if [ $year -lt 2015 ]; then
    schema=$yellow_schema_pre_2015
  elif [ $year -eq 2015 ] || ([ $year -eq 2016 ] && [ $month -lt 7 ]); then
    schema=$yellow_schema_2015_2016_h1
  else
    schema=$yellow_schema_2016_h2
  fi

  echo "`date`: beginning load for ${filename}"
  sed $'s/\r$//' $filename | sed '/^$/d' | psql nyc-taxi-data -c "COPY yellow_tripdata_staging ${schema} FROM stdin CSV HEADER;"
  echo "`date`: finished raw load for ${filename}"
  psql nyc-taxi-data -f populate_yellow_trips.sql
  echo "`date`: loaded trips for ${filename}"
done;
