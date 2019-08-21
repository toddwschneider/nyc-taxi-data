CREATE EXTENSION postgis;

CREATE TABLE green_tripdata_staging (
  id serial primary key,
  vendor_id text,
  lpep_pickup_datetime text,
  lpep_dropoff_datetime text,
  store_and_fwd_flag text,
  rate_code_id text,
  pickup_longitude numeric,
  pickup_latitude numeric,
  dropoff_longitude numeric,
  dropoff_latitude numeric,
  passenger_count text,
  trip_distance text,
  fare_amount text,
  extra text,
  mta_tax text,
  tip_amount text,
  tolls_amount text,
  ehail_fee text,
  improvement_surcharge text,
  total_amount text,
  payment_type text,
  trip_type text,
  pickup_location_id text,
  dropoff_location_id text,
  congestion_surcharge text,
  junk1 text,
  junk2 text
);
/*
N.B. junk columns are there because some tripdata file headers are
inconsistent with the actual data, e.g. header says 20 or 21 columns per row,
but data actually has 22 or 23 columns per row, which COPY doesn't like.
junk1 and junk2 should always be null
*/

CREATE TABLE yellow_tripdata_staging (
  id serial primary key,
  vendor_id text,
  tpep_pickup_datetime text,
  tpep_dropoff_datetime text,
  passenger_count text,
  trip_distance text,
  pickup_longitude numeric,
  pickup_latitude numeric,
  rate_code_id text,
  store_and_fwd_flag text,
  dropoff_longitude numeric,
  dropoff_latitude numeric,
  payment_type text,
  fare_amount text,
  extra text,
  mta_tax text,
  tip_amount text,
  tolls_amount text,
  improvement_surcharge text,
  total_amount text,
  pickup_location_id text,
  dropoff_location_id text,
  congestion_surcharge text,
  junk1 text,
  junk2 text
);

CREATE TABLE uber_trips_2014 (
  id serial primary key,
  pickup_datetime timestamp without time zone,
  pickup_latitude numeric,
  pickup_longitude numeric,
  base_code text
);

CREATE TABLE fhv_trips_staging (
  dispatching_base_num text,
  pickup_datetime text,
  dropoff_datetime text,
  pickup_location_id text,
  dropoff_location_id text,
  shared_ride text,
  junk text
);

CREATE TABLE fhv_trips (
  id serial primary key,
  dispatching_base_num text,
  pickup_datetime timestamp without time zone,
  dropoff_datetime timestamp without time zone,
  pickup_location_id integer,
  dropoff_location_id integer,
  shared_ride integer
);

CREATE TABLE fhv_bases (
  base_number text primary key,
  base_name text,
  dba text,
  dba_category text
);

CREATE INDEX ON fhv_bases (dba_category);

CREATE TABLE cab_types (
  id serial primary key,
  type text
);

INSERT INTO cab_types (type) SELECT 'yellow';
INSERT INTO cab_types (type) SELECT 'green';

CREATE TABLE trips (
  id serial primary key,
  cab_type_id integer,
  vendor_id text,
  pickup_datetime timestamp without time zone,
  dropoff_datetime timestamp without time zone,
  store_and_fwd_flag text,
  rate_code_id integer,
  pickup_longitude numeric,
  pickup_latitude numeric,
  dropoff_longitude numeric,
  dropoff_latitude numeric,
  passenger_count integer,
  trip_distance numeric,
  fare_amount numeric,
  extra numeric,
  mta_tax numeric,
  tip_amount numeric,
  tolls_amount numeric,
  ehail_fee numeric,
  improvement_surcharge numeric,
  congestion_surcharge numeric,
  total_amount numeric,
  payment_type text,
  trip_type integer,
  pickup_nyct2010_gid integer,
  dropoff_nyct2010_gid integer,
  pickup_location_id integer,
  dropoff_location_id integer
);

CREATE TABLE central_park_weather_observations (
  station_id text,
  station_name text,
  date date primary key,
  precipitation numeric,
  snow_depth numeric,
  snowfall numeric,
  max_temperature numeric,
  min_temperature numeric,
  average_wind_speed numeric
);
