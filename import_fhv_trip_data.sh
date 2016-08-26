#!/bin/bash

for filename in data/fhv*.csv; do
  echo "`date`: beginning load for $filename"
  cat $filename | psql nyc-taxi-data -c "COPY fhv_trips (dispatching_base_num, pickup_datetime, location_id) FROM stdin CSV HEADER;"
  echo "`date`: loaded trips for $filename"
done;

psql nyc-taxi-data -c "CREATE INDEX index_fhv_on_location ON fhv_trips (location_id);"
