#!/bin/bash

# Set PostgreSQL connection parameters
export PGPASSWORD=password
PG_HOST="db_url"
PG_PORT=5432
PG_DB="db"
PG_USER="username"
PG_CONN="-h $PG_HOST -p $PG_PORT -d $PG_DB -U $PG_USER"

# Create schema and tables
psql $PG_CONN -f setup_files/create_nyc_taxi_schema.sql

# Import taxi zones with PostGIS
shp2pgsql -s 2263:4326 -I shapefiles/taxi_zones/taxi_zones.shp | psql $PG_CONN
psql $PG_CONN -c "CREATE INDEX ON taxi_zones (locationid);"
psql $PG_CONN -c "VACUUM ANALYZE taxi_zones;"

# Import neighborhood tabulation areas with PostGIS
shp2pgsql -s 2263:4326 -I shapefiles/nyct2010_15b/nyct2010.shp | psql $PG_CONN
psql $PG_CONN -f setup_files/add_newark_airport.sql
psql $PG_CONN -c "CREATE INDEX ON nyct2010 (ntacode);"
psql $PG_CONN -c "VACUUM ANALYZE nyct2010;"

psql $PG_CONN -f setup_files/add_tract_to_zone_mapping.sql

# Import FHV bases and weather data
cat data/fhv_bases.csv | psql $PG_CONN -c "COPY fhv_bases FROM stdin WITH CSV HEADER;"
weather_schema="station_id, station_name, date, average_wind_speed, precipitation, snowfall, snow_depth, max_temperature, min_temperature"
cat data/central_park_weather.csv | psql $PG_CONN -c "COPY central_park_weather_observations (${weather_schema}) FROM stdin WITH CSV HEADER;"
psql $PG_CONN -c "UPDATE central_park_weather_observations SET average_wind_speed = NULL WHERE average_wind_speed = -9999;"
