#!/bin/bash

year_month_regex="tripdata_([0-9]{4})-([0-9]{2})"

fhv_schema_pre_2017_06="(dispatching_base_num,pickup_datetime,pickup_location_id)"
fhv_schema_2017_06="(dispatching_base_num,pickup_datetime,dropoff_datetime,pickup_location_id,dropoff_location_id)"

for filename in data/fhv*.csv; do
  [[ $filename =~ $year_month_regex ]]
  year=${BASH_REMATCH[1]}
  month=$((10#${BASH_REMATCH[2]}))

  if [ $year -lt 2017 ] || [ $month -lt 6 ]; then
    schema=$fhv_schema_pre_2017_06
  else
    schema=$fhv_schema_2017_06
  fi

  echo "`date`: beginning load for $filename"
  cat $filename | psql nyc-taxi-data -c "COPY fhv_trips ${schema} FROM stdin CSV HEADER;"
  echo "`date`: loaded trips for $filename"
done;

psql nyc-taxi-data -c "UPDATE fhv_trips SET dispatching_base_num = trim(upper(dispatching_base_num)) WHERE dispatching_base_num != trim(upper(dispatching_base_num));"
psql nyc-taxi-data -c "VACUUM FULL ANALYZE fhv_trips;"

psql nyc-taxi-data -c "CREATE INDEX index_fhv_on_pickup_location ON fhv_trips (pickup_location_id);"
psql nyc-taxi-data -c "CREATE INDEX index_fhv_on_pickup_datetime_brin ON fhv_trips USING BRIN (pickup_datetime) WITH (pages_per_range = 32);"
