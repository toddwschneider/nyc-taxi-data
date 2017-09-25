INSERT INTO taxi_citibike_trips
SELECT
  'taxi',
  id,
  pickup_location_id,
  dropoff_location_id,
  pickup_datetime,
  dropoff_datetime,
  extract(epoch FROM dropoff_datetime - pickup_datetime),
  date(pickup_datetime),
  extract(dow FROM pickup_datetime),
  extract(hour FROM pickup_datetime),
  trip_distance
FROM trips
WHERE cab_type_id IN (1, 2)
  AND pickup_datetime >= '2013-07-01 00:00:00'
  AND pickup_datetime < '2017-07-01'
  AND dropoff_datetime < '2017-07-01 02:00:00'
  AND pickup_location_id IS NOT NULL
  AND dropoff_location_id IS NOT NULL
  AND extract(epoch FROM dropoff_datetime - pickup_datetime) BETWEEN 120 AND 7200;
