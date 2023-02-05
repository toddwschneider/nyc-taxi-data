INSERT INTO fhv_trips (
  hvfhs_license_num, dispatching_base_num, originating_base_num, request_datetime,
  on_scene_datetime, pickup_datetime, dropoff_datetime, pickup_location_id,
  dropoff_location_id, trip_miles, trip_time, base_passenger_fare, tolls,
  black_car_fund, sales_tax, congestion_surcharge, airport_fee, tips,
  driver_pay, shared_request, shared_match, access_a_ride, wav_request, wav_match,
  legacy_shared_ride, affiliated_base_num
)
SELECT
  trim(upper(hvfhs_license_num)),
  trim(upper(dispatching_base_num)),
  trim(upper(originating_base_num)),
  request_datetime,
  on_scene_datetime,
  pickup_datetime,
  dropoff_datetime,
  pickup_location_id,
  dropoff_location_id,
  trip_miles,
  trip_time,
  base_passenger_fare,
  tolls,
  black_car_fund,
  sales_tax,
  congestion_surcharge,
  airport_fee,
  tips,
  driver_pay,
  CASE trim(upper(shared_request_flag)) WHEN 'Y' THEN true WHEN 'N' THEN false END,
  CASE trim(upper(shared_match_flag)) WHEN 'Y' THEN true WHEN 'N' THEN false END,
  CASE trim(upper(access_a_ride_flag)) WHEN 'Y' THEN true WHEN 'N' THEN false WHEN '' THEN false END,
  CASE trim(upper(wav_request_flag)) WHEN 'Y' THEN true WHEN 'N' THEN false END,
  CASE trim(upper(wav_match_flag)) WHEN 'Y' THEN true WHEN 'N' THEN false END,
  legacy_shared_ride_flag::integer,
  trim(upper(affiliated_base_num))
FROM fhv_trips_staging;

TRUNCATE TABLE fhv_trips_staging;
VACUUM ANALYZE fhv_trips_staging;
