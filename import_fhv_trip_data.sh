#!/bin/bash

year_month_regex="tripdata_([0-9]{4})-([0-9]{2})"

fhv_schema_pre_2017="(dispatching_base_num,pickup_datetime,pickup_location_id)"
fhv_schema_2017_h1="(dispatching_base_num,pickup_datetime,dropoff_datetime,pickup_location_id,dropoff_location_id)"
fhv_schema_2017_h2="(dispatching_base_num,pickup_datetime,dropoff_datetime,pickup_location_id,dropoff_location_id,shared_ride)"
fhv_schema_2018="(pickup_datetime,dropoff_datetime,pickup_location_id,dropoff_location_id,shared_ride,dispatching_base_num,junk)"

for filename in data/fhv_tripdata*.csv; do
  [[ $filename =~ $year_month_regex ]]
  year=${BASH_REMATCH[1]}
  month=$((10#${BASH_REMATCH[2]}))

  if [ $year -lt 2017 ]; then
    schema=$fhv_schema_pre_2017
  elif [ $year -eq 2017 ] && [ $month -lt 7 ]; then
    schema=$fhv_schema_2017_h1
  elif [ $year -eq 2017 ]; then
    schema=$fhv_schema_2017_h2
  else
    schema=$fhv_schema_2018
  fi

  echo "`date`: beginning load for ${filename}"
  cat $filename | psql nyc-taxi-data -c "COPY fhv_trips_staging ${schema} FROM stdin CSV HEADER;"
  echo "`date`: finished raw load for ${filename}"
  psql nyc-taxi-data -f setup_files/populate_fhv_trips.sql
  echo "`date`: loaded trips for ${filename}"
done;

psql nyc-taxi-data -c "CREATE INDEX ON fhv_trips USING BRIN (pickup_datetime) WITH (pages_per_range = 32);"
