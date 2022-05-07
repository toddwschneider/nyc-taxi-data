CREATE TABLE tmp_points AS
SELECT
  id,
  ST_SetSRID(ST_MakePoint(pickup_longitude, pickup_latitude), 4326) AS pickup,
  ST_SetSRID(ST_MakePoint(dropoff_longitude, dropoff_latitude), 4326) AS dropoff
FROM green_tripdata_staging
WHERE pickup_longitude IS NOT NULL OR dropoff_longitude IS NOT NULL;

CREATE INDEX ON tmp_points USING gist (pickup);
CREATE INDEX ON tmp_points USING gist (dropoff);

CREATE TABLE tmp_pickups AS
SELECT t.id, n.gid
FROM tmp_points t, nyct2010 n
WHERE ST_Within(t.pickup, n.geom);

CREATE TABLE tmp_dropoffs AS
SELECT t.id, n.gid
FROM tmp_points t, nyct2010 n
WHERE ST_Within(t.dropoff, n.geom);

INSERT INTO trips
(cab_type_id, vendor_id, pickup_datetime, dropoff_datetime, store_and_fwd_flag, rate_code_id, pickup_longitude, pickup_latitude, dropoff_longitude, dropoff_latitude, passenger_count, trip_distance, fare_amount, extra, mta_tax, tip_amount, tolls_amount, ehail_fee, improvement_surcharge, congestion_surcharge, total_amount, payment_type, trip_type, pickup_nyct2010_gid, dropoff_nyct2010_gid, pickup_location_id, dropoff_location_id)
SELECT
  cab_types.id,
  vendor_id,
  lpep_pickup_datetime::timestamp,
  lpep_dropoff_datetime::timestamp,
  store_and_fwd_flag,
  rate_code_id::numeric::integer,
  CASE WHEN pickup_longitude != 0 THEN pickup_longitude END,
  CASE WHEN pickup_latitude != 0 THEN pickup_latitude END,
  CASE WHEN dropoff_longitude != 0 THEN dropoff_longitude END,
  CASE WHEN dropoff_latitude != 0 THEN dropoff_latitude END,
  passenger_count::numeric::integer,
  trip_distance::numeric,
  fare_amount::numeric,
  extra::numeric,
  mta_tax::numeric,
  tip_amount::numeric,
  tolls_amount::numeric,
  ehail_fee::numeric,
  improvement_surcharge::numeric,
  congestion_surcharge::numeric,
  total_amount::numeric,
  payment_type,
  trip_type::numeric::integer,
  tmp_pickups.gid,
  tmp_dropoffs.gid,
  COALESCE(pickup_location_id::integer, map_pickups.taxi_zone_location_id),
  COALESCE(dropoff_location_id::integer, map_dropoffs.taxi_zone_location_id)
FROM
  green_tripdata_staging
    INNER JOIN cab_types ON cab_types.type = 'green'
    LEFT JOIN tmp_pickups ON green_tripdata_staging.id = tmp_pickups.id
      LEFT JOIN nyct2010_taxi_zones_mapping map_pickups ON tmp_pickups.gid = map_pickups.nyct2010_gid
    LEFT JOIN tmp_dropoffs ON green_tripdata_staging.id = tmp_dropoffs.id
      LEFT JOIN nyct2010_taxi_zones_mapping map_dropoffs ON tmp_dropoffs.gid = map_dropoffs.nyct2010_gid;

TRUNCATE TABLE green_tripdata_staging;
VACUUM ANALYZE green_tripdata_staging;

DROP TABLE tmp_points;
DROP TABLE tmp_pickups;
DROP TABLE tmp_dropoffs;
