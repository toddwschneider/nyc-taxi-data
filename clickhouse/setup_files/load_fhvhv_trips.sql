ALTER TABLE fhv_trips
DELETE WHERE filename = splitByChar('/', {filename:String})[-1];

INSERT INTO fhv_trips (
  hvfhs_license_num, company, dispatching_base_num, originating_base_num,
  request_datetime, on_scene_datetime, pickup_datetime, dropoff_datetime,
  pickup_location_id, dropoff_location_id, pickup_borough, dropoff_borough,
  trip_miles, trip_time, base_passenger_fare, tolls, black_car_fund, sales_tax,
  congestion_surcharge, airport_fee, tips, driver_pay, shared_request,
  shared_match, access_a_ride, wav_request, wav_match, filename
)
SELECT
  hvfhs_license_num,
  multiIf(
    hvfhs_license_num = 'HV0002', 'juno',
    hvfhs_license_num = 'HV0003', 'uber',
    hvfhs_license_num = 'HV0004', 'via',
    hvfhs_license_num = 'HV0005', 'lyft',
    null
  ) AS company,
  trimBoth(upper(dispatching_base_num)),
  trimBoth(upper(originating_base_num)),
  request_datetime,
  on_scene_datetime,
  pickup_datetime,
  dropoff_datetime,
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
  trip_miles,
  trip_time,
  base_passenger_fare,
  tolls,
  bcf,
  sales_tax,
  congestion_surcharge,
  airport_fee,
  tips,
  driver_pay,
  multiIf(shared_request_flag = 'Y', true, shared_request_flag = 'N', false, null),
  multiIf(shared_match_flag = 'Y', true, shared_match_flag = 'N', false, null),
  multiIf(access_a_ride_flag = 'Y', true, access_a_ride_flag = 'N', false, null),
  multiIf(wav_request_flag = 'Y', true, wav_request_flag = 'N', false, null),
  multiIf(wav_match_flag = 'Y', true, wav_match_flag = 'N', false, null),
  splitByChar('/', {filename:String})[-1]
FROM file({filename:String});
