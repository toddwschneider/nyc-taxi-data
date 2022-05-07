INSERT INTO fhv_trips (
  dispatching_base_num, pickup_datetime, dropoff_datetime, pickup_location_id,
  dropoff_location_id, shared_ride, hvfhs_license_num, affiliated_base_num
)
SELECT
  trim(upper(dispatching_base_num)),
  pickup_datetime::timestamp without time zone,
  dropoff_datetime::timestamp without time zone,
  NULLIF(pickup_location_id, '')::numeric::integer,
  NULLIF(dropoff_location_id, '')::numeric::integer,
  NULLIF(shared_ride, '')::numeric::integer,
  trim(upper(hvfhs_license_num)),
  trim(upper(affiliated_base_num))
FROM fhv_trips_staging;

TRUNCATE TABLE fhv_trips_staging;
VACUUM ANALYZE fhv_trips_staging;
