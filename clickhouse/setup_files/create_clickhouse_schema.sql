CREATE TABLE taxi_zones (
  location_id UInt16,
  zone String,
  borough String,
  subregion String
)
ENGINE = MergeTree
ORDER BY (location_id);

CREATE TABLE fhv_trips (
  hvfhs_license_num String,
  company String,
  dispatching_base_num Nullable(String),
  originating_base_num Nullable(String),
  request_datetime Nullable(DateTime('UTC')),
  on_scene_datetime Nullable(DateTime('UTC')),
  pickup_datetime DateTime('UTC'),
  dropoff_datetime DateTime('UTC'),
  pickup_location_id Nullable(UInt16),
  dropoff_location_id Nullable(UInt16),
  pickup_borough Nullable(String),
  dropoff_borough Nullable(String),
  trip_miles Nullable(Float64),
  trip_time Nullable(UInt32),
  base_passenger_fare Nullable(Float64),
  tolls Nullable(Float64),
  black_car_fund Nullable(Float64),
  sales_tax Nullable(Float64),
  congestion_surcharge Nullable(Float64),
  airport_fee Nullable(Float64),
  tips Nullable(Float64),
  driver_pay Nullable(Float64),
  shared_request Nullable(Bool),
  shared_match Nullable(Bool),
  access_a_ride Nullable(Bool),
  wav_request Nullable(Bool),
  wav_match Nullable(Bool),
  legacy_shared_ride Nullable(UInt16),
  filename String
)
ENGINE = MergeTree
ORDER BY (company, pickup_datetime);

CREATE TABLE taxi_trips (
  car_type String,
  vendor_id Nullable(UInt16),
  pickup_datetime DateTime('UTC'),
  dropoff_datetime DateTime('UTC'),
  pickup_location_id Nullable(UInt16),
  dropoff_location_id Nullable(UInt16),
  pickup_borough Nullable(String),
  dropoff_borough Nullable(String),
  passenger_count Nullable(UInt16),
  trip_distance Nullable(Float64),
  rate_code_id Nullable(UInt16),
  store_and_fwd_flag Nullable(Bool),
  payment_type Nullable(UInt16),
  fare_amount Nullable(Float64),
  extra Nullable(Float64),
  mta_tax Nullable(Float64),
  tip_amount Nullable(Float64),
  tolls_amount Nullable(Float64),
  improvement_surcharge Nullable(Float64),
  total_amount Nullable(Float64),
  congestion_surcharge Nullable(Float64),
  airport_fee Nullable(Float64),
  trip_type Nullable(UInt16),
  ehail_fee Nullable(Float64),
  filename String
)
ENGINE = MergeTree
ORDER BY (car_type, pickup_datetime);

CREATE OR REPLACE VIEW fhv_trips_expanded AS
SELECT
  *,
  trip_time / 60 AS trip_minutes,
  trip_miles / trip_time * 3600 AS mph,
  (
    trip_miles >= 0.2
    AND trip_miles < 100
    AND trip_time >= 60
    AND trip_time < 60 * 60 * 4
    AND mph >= 1
    AND mph < 100
    AND base_passenger_fare >= 2
    AND base_passenger_fare < 2000
    AND driver_pay >= 1
    AND driver_pay < 2000
  ) AS reasonable_time_distance_fare,
  (
    shared_request = false
    AND access_a_ride = false
    AND wav_request = false
  ) AS solo_non_special_request,
  coalesce(tolls, 0) +
    coalesce(black_car_fund, 0) +
    coalesce(sales_tax, 0) +
    coalesce(congestion_surcharge, 0) +
    coalesce(airport_fee, 0) AS extra_charges
FROM fhv_trips;

CREATE OR REPLACE VIEW taxi_trips_expanded AS
SELECT
  *,
  (dropoff_datetime - pickup_datetime) / 60 AS trip_minutes,
  trip_distance / (dropoff_datetime - pickup_datetime) * 3600 AS mph,
  (
    trip_distance >= 0.2
    AND trip_distance < 100
    AND trip_minutes >= 1
    AND trip_minutes < 240
    AND mph >= 1
    AND mph < 100
    AND fare_amount >= 2
    AND fare_amount < 2000
    AND total_amount >= 2
    AND total_amount < 2000
  ) AS reasonable_time_distance_fare,
  coalesce(extra, 0) +
    coalesce(mta_tax, 0) +
    coalesce(tolls_amount, 0) +
    coalesce(improvement_surcharge, 0) +
    coalesce(congestion_surcharge, 0) +
    coalesce(airport_fee, 0) +
    coalesce(ehail_fee, 0) AS extra_charges
FROM taxi_trips;
