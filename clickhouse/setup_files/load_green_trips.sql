ALTER TABLE taxi_trips
DELETE WHERE filename = splitByChar('/', {filename:String})[-1];

INSERT INTO taxi_trips (
  car_type, vendor_id, pickup_datetime, dropoff_datetime, pickup_location_id,
  dropoff_location_id, pickup_borough, dropoff_borough, passenger_count,
  trip_distance, rate_code_id, store_and_fwd_flag, payment_type, fare_amount,
  extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge,
  total_amount, congestion_surcharge, trip_type, ehail_fee, filename
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
  trip_type,
  ehail_fee,
  splitByChar('/', {filename:String})[-1]
FROM file({filename:String});
