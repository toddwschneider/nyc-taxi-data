DELETE FROM taxi_trips
WHERE filename = splitByChar('/', {filename:String})[-1];

INSERT INTO taxi_trips (
  car_type, vendor_id, pickup_datetime, dropoff_datetime, pickup_location_id,
  dropoff_location_id, pickup_borough, dropoff_borough, passenger_count,
  trip_distance, rate_code_id, store_and_fwd_flag, payment_type, fare_amount,
  extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge,
  total_amount, congestion_surcharge, cbd_congestion_fee, trip_type, ehail_fee,
  filename
)
SELECT
  'green',
  VendorID,
  lpep_pickup_datetime,
  lpep_dropoff_datetime,
  PULocationID,
  DOLocationID,
  multiIf(
    PULocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'Bronx'), 'Bronx',
    PULocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'Brooklyn'), 'Brooklyn',
    PULocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'Manhattan'), 'Manhattan',
    PULocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'Queens'), 'Queens',
    PULocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'Staten Island'), 'Staten Island',
    PULocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'EWR'), 'EWR',
    null
  ),
  multiIf(
    DOLocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'Bronx'), 'Bronx',
    DOLocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'Brooklyn'), 'Brooklyn',
    DOLocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'Manhattan'), 'Manhattan',
    DOLocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'Queens'), 'Queens',
    DOLocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'Staten Island'), 'Staten Island',
    DOLocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'EWR'), 'EWR',
    null
  ),
  passenger_count,
  trip_distance,
  RatecodeID,
  multiIf(store_and_fwd_flag = 'Y', true, store_and_fwd_flag = 'N', false, null),
  payment_type,
  fare_amount,
  extra,
  mta_tax,
  tip_amount,
  tolls_amount,
  improvement_surcharge,
  total_amount,
  congestion_surcharge,
  cbd_congestion_fee,
  trip_type,
  ehail_fee,
  splitByChar('/', {filename:String})[-1]
FROM input('
  VendorID Nullable(Int64),
  lpep_pickup_datetime Nullable(DateTime64(6)),
  lpep_dropoff_datetime Nullable(DateTime64(6)),
  store_and_fwd_flag Nullable(String),
  RatecodeID Nullable(Float64),
  PULocationID Nullable(Int64),
  DOLocationID Nullable(Int64),
  passenger_count Nullable(Float64),
  trip_distance Nullable(Float64),
  fare_amount Nullable(Float64),
  extra Nullable(Float64),
  mta_tax Nullable(Float64),
  tip_amount Nullable(Float64),
  tolls_amount Nullable(Float64),
  ehail_fee Nullable(Float64),
  improvement_surcharge Nullable(Float64),
  total_amount Nullable(Float64),
  payment_type Nullable(Float64),
  trip_type Nullable(Float64),
  congestion_surcharge Nullable(Float64),
  cbd_congestion_fee Nullable(Float64)
')
SETTINGS
  input_format_parquet_case_insensitive_column_matching = 1,
  input_format_parquet_allow_missing_columns = 1
FORMAT Parquet
