CREATE TABLE tmp_points AS
SELECT
  id,
  ST_SetSRID(ST_MakePoint(pickup_longitude, pickup_latitude), 4326) as pickup,
  ST_SetSRID(ST_MakePoint(dropoff_longitude, dropoff_latitude), 4326) as dropoff
FROM green_tripdata_staging;  

CREATE INDEX idx_tmp_points_pickup ON tmp_points USING gist (pickup);
CREATE INDEX idx_tmp_points_dropoff ON tmp_points USING gist (dropoff);

CREATE TABLE tmp_pickups AS
SELECT t.id, n.gid
FROM tmp_points t, nyct2010 n
WHERE ST_Within(t.pickup, n.geom);

CREATE TABLE tmp_dropoffs AS
SELECT t.id, n.gid
FROM tmp_points t, nyct2010 n
WHERE ST_Within(t.dropoff, n.geom);

INSERT INTO trips
(cab_type_id, vendor_id, pickup_datetime, dropoff_datetime, store_and_fwd_flag, rate_code_id, pickup_longitude, pickup_latitude, dropoff_longitude, dropoff_latitude, passenger_count, trip_distance, fare_amount, extra, mta_tax, tip_amount, tolls_amount, ehail_fee, improvement_surcharge, total_amount, payment_type, trip_type, pickup, dropoff, pickup_nyct2010_gid, dropoff_nyct2010_gid)
SELECT
  cab_types.id,
  vendor_id,
  lpep_pickup_datetime::timestamp,
  lpep_dropoff_datetime::timestamp,
  store_and_fwd_flag,
  rate_code_id::integer,
  CASE WHEN pickup_longitude != 0 THEN pickup_longitude END,
  CASE WHEN pickup_latitude != 0 THEN pickup_latitude END,
  CASE WHEN dropoff_longitude != 0 THEN dropoff_longitude END,
  CASE WHEN dropoff_latitude != 0 THEN dropoff_latitude END,
  passenger_count::integer,
  trip_distance::numeric,
  fare_amount::numeric,
  extra::numeric,
  mta_tax::numeric,
  tip_amount::numeric,
  tolls_amount::numeric,
  ehail_fee::numeric,
  improvement_surcharge::numeric,
  total_amount::numeric,
  payment_type,
  trip_type::integer,
  CASE
    WHEN pickup_longitude != 0 AND pickup_latitude != 0
    THEN ST_SetSRID(ST_MakePoint(pickup_longitude, pickup_latitude), 4326)
  END,
  CASE
    WHEN dropoff_longitude != 0 AND dropoff_latitude != 0
    THEN ST_SetSRID(ST_MakePoint(dropoff_longitude, dropoff_latitude), 4326)
  END,
  tmp_pickups.gid,
  tmp_dropoffs.gid
FROM
  green_tripdata_staging
    INNER JOIN cab_types ON cab_types.type = 'green'
    LEFT JOIN tmp_pickups ON green_tripdata_staging.id = tmp_pickups.id
    LEFT JOIN tmp_dropoffs ON green_tripdata_staging.id = tmp_dropoffs.id;

TRUNCATE TABLE green_tripdata_staging;
DROP TABLE tmp_points;
DROP TABLE tmp_pickups;
DROP TABLE tmp_dropoffs;
