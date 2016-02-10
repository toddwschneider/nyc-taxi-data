#!/bin/bash

# load 2014 Uber data into unified `trips` table
for filename in data/uber*14.csv; do
  echo "`date`: beginning load for $filename"
  cat $filename | psql nyc-taxi-data -c "COPY uber_trips_staging (pickup_datetime, pickup_latitude, pickup_longitude, base_code) FROM stdin CSV HEADER;"
  echo "`date`: finished raw load for $filename"
  psql nyc-taxi-data -f populate_uber_trips.sql
  echo "`date`: loaded trips for $filename"
done;

# load 2015 Uber data into its own separate table due to schema difference
unzip data/uber-raw-data-janjune-15.csv.zip -d data/
cat data/taxi-zone-lookup-with-ntacode.csv | psql nyc-taxi-data -c "COPY uber_taxi_zone_lookups FROM stdin CSV HEADER;"
cat data/uber-raw-data-janjune-15.csv | psql nyc-taxi-data -c "COPY uber_trips_2015 (dispatching_base_num, pickup_datetime, affiliated_base_num, location_id) FROM stdin CSV HEADER;"
psql nyc-taxi-data -c "CREATE INDEX index_uber_on_location ON uber_trips_2015 (location_id);"
psql nyc-taxi-data -f add_ntacodes_to_uber_trips_2015.sql
psql nyc-taxi-data -c "CREATE INDEX index_uber_on_nta ON uber_trips_2015 (nyct2010_ntacode);"
psql nyc-taxi-data -c "VACUUM FULL ANALYZE uber_trips_2015;"
