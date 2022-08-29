CREATE EXTENSION postgis;

CREATE TABLE green_tripdata_staging (
  id bigserial primary key,
  vendor_id integer,
  lpep_pickup_datetime timestamp without time zone,
  lpep_dropoff_datetime timestamp without time zone,
  store_and_fwd_flag text,
  rate_code_id integer,
  dropoff_location_id integer,
  congestion_surcharge numeric,
  passenger_count integer,
  trip_distance numeric,
  fare_amount numeric,
  extra numeric,
  mta_tax numeric,
  tip_amount numeric,
  tolls_amount numeric,
  ehail_fee numeric,
  improvement_surcharge numeric,
  total_amount numeric,
  payment_type integer,
  trip_type integer,
  pickup_location_id integer
)
WITH (
  autovacuum_enabled = false,
  toast.autovacuum_enabled = false
);

CREATE TABLE yellow_tripdata_staging (
  id bigserial primary key,
  vendor_id integer,
  tpep_pickup_datetime timestamp without time zone,
  tpep_dropoff_datetime timestamp without time zone,
  passenger_count integer,
  trip_distance numeric,
  pickup_longitude numeric,
  pickup_latitude numeric,
  rate_code_id integer,
  store_and_fwd_flag text,
  dropoff_longitude numeric,
  dropoff_latitude numeric,
  pickup_location_id integer,
  dropoff_location_id integer,
  payment_type integer,
  fare_amount numeric,
  extra numeric,
  mta_tax numeric,
  tip_amount numeric,
  tolls_amount numeric,
  improvement_surcharge numeric,
  total_amount numeric,
  congestion_surcharge numeric,
  airport_fee numeric
)
WITH (
  autovacuum_enabled = false,
  toast.autovacuum_enabled = false
);

CREATE TABLE uber_trips_2014 (
  id serial primary key,
  pickup_datetime timestamp without time zone,
  pickup_latitude numeric,
  pickup_longitude numeric,
  base_code text
);

CREATE TABLE fhv_trips_staging (
  hvfhs_license_num text,
  dispatching_base_num text,
  originating_base_num text,
  request_datetime timestamp without time zone,
  on_scene_datetime timestamp without time zone,
  pickup_datetime timestamp without time zone,
  dropoff_datetime timestamp without time zone,
  pickup_location_id integer,
  dropoff_location_id integer,
  trip_miles numeric,
  trip_time numeric,
  base_passenger_fare numeric,
  tolls numeric,
  black_car_fund numeric,
  sales_tax numeric,
  congestion_surcharge numeric,
  airport_fee numeric,
  tips numeric,
  driver_pay numeric,
  shared_request_flag text,
  shared_match_flag text,
  access_a_ride_flag text,
  wav_request_flag text,
  wav_match_flag text,
  shared_ride_flag text,
  affiliated_base_num text,
  legacy_shared_ride_flag text
)
WITH (
  autovacuum_enabled = false,
  toast.autovacuum_enabled = false
);

CREATE TABLE fhv_trips (
  id bigserial primary key,
  hvfhs_license_num text,
  dispatching_base_num text,
  originating_base_num text,
  request_datetime timestamp without time zone,
  on_scene_datetime timestamp without time zone,
  pickup_datetime timestamp without time zone,
  dropoff_datetime timestamp without time zone,
  pickup_location_id integer,
  dropoff_location_id integer,
  trip_miles numeric,
  trip_time numeric,
  base_passenger_fare numeric,
  tolls numeric,
  black_car_fund numeric,
  sales_tax numeric,
  congestion_surcharge numeric,
  airport_fee numeric,
  tips numeric,
  driver_pay numeric,
  shared_request boolean,
  shared_match boolean,
  access_a_ride boolean,
  wav_request boolean,
  wav_match boolean,
  legacy_shared_ride integer,
  affiliated_base_num text
);

CREATE TABLE fhv_bases (
  base_number text primary key,
  base_name text,
  dba text,
  dba_category text
);

CREATE INDEX ON fhv_bases (dba_category);

CREATE TABLE hvfhs_licenses (
  license_number text primary key,
  company_name text
);

INSERT INTO hvfhs_licenses
VALUES ('HV0002', 'juno'),
       ('HV0003', 'uber'),
       ('HV0004', 'via'),
       ('HV0005', 'lyft');

CREATE TABLE cab_types (
  id serial primary key,
  type text
);

INSERT INTO cab_types (type) VALUES ('yellow'), ('green');

CREATE TABLE trips (
  id bigserial primary key,
  cab_type_id integer,
  vendor_id integer,
  pickup_datetime timestamp without time zone,
  dropoff_datetime timestamp without time zone,
  store_and_fwd_flag boolean,
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
  payment_type integer,
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
