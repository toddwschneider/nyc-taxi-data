#!/bin/bash

createdb nyc-taxi-data

psql nyc-taxi-data -f create_nyc_taxi_schema.sql

shp2pgsql -s 2263:4326 nyct2010_15b/nyct2010.shp | psql -d nyc-taxi-data
psql nyc-taxi-data -f add_newark_airport.sql

psql nyc-taxi-data -c "CREATE INDEX index_nyct_on_geom ON nyct2010 USING gist (geom);"
psql nyc-taxi-data -c "CREATE INDEX index_nyct_on_ntacode ON nyct2010 (ntacode);"
psql nyc-taxi-data -c "VACUUM ANALYZE nyct2010;"

cat data/central_park_weather.csv | psql nyc-taxi-data -c "COPY central_park_weather_observations_raw FROM stdin WITH CSV HEADER;"
