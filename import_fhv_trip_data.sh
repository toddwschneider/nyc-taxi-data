#!/bin/bash

for filename in data/fhv*.csv; do
  echo "`date`: beginning load for $filename"
  cat $filename | psql nyc-taxi-data -c "COPY fhv_trips (dispatching_base_num, pickup_datetime, location_id) FROM stdin CSV HEADER;"
  echo "`date`: loaded trips for $filename"
done;

psql nyc-taxi-data -c "UPDATE fhv_trips SET dispatching_base_num = trim(upper(dispatching_base_num)) WHERE dispatching_base_num != trim(upper(dispatching_base_num));"
psql nyc-taxi-data -c "VACUUM FULL ANALYZE fhv_trips;"

psql nyc-taxi-data -c "CREATE INDEX index_fhv_on_location ON fhv_trips (location_id);"
