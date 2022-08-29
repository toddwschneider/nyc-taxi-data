CREATE TABLE taxi_zones (
  location_id UInt16,
  zone String,
  borough String
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
