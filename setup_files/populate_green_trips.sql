INSERT INTO trips
(cab_type_id, vendor_id, pickup_datetime, dropoff_datetime, store_and_fwd_flag, rate_code_id, passenger_count, trip_distance, fare_amount, extra, mta_tax, tip_amount, tolls_amount, ehail_fee, improvement_surcharge, congestion_surcharge, total_amount, payment_type, trip_type, pickup_location_id, dropoff_location_id)
SELECT
  cab_types.id,
  vendor_id,
  lpep_pickup_datetime,
  lpep_dropoff_datetime,
  CASE upper(store_and_fwd_flag) WHEN 'Y' THEN true WHEN 'N' THEN false END,
  rate_code_id,
  passenger_count,
  trip_distance,
  fare_amount,
  extra,
  mta_tax,
  tip_amount,
  tolls_amount,
  ehail_fee,
  improvement_surcharge,
  congestion_surcharge,
  total_amount,
  payment_type,
  trip_type,
  pickup_location_id,
  dropoff_location_id
FROM green_tripdata_staging
  INNER JOIN cab_types ON cab_types.type = 'green';

TRUNCATE TABLE green_tripdata_staging;
VACUUM ANALYZE green_tripdata_staging;
