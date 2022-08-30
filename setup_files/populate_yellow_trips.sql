CREATE TABLE tmp_points AS
SELECT
  id,
  ST_SetSRID(ST_MakePoint(pickup_longitude, pickup_latitude), 4326) AS pickup,
  ST_SetSRID(ST_MakePoint(dropoff_longitude, dropoff_latitude), 4326) AS dropoff
FROM yellow_tripdata_staging
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
(cab_type_id, vendor_id, pickup_datetime, dropoff_datetime, passenger_count, trip_distance, pickup_longitude, pickup_latitude, rate_code_id, store_and_fwd_flag, dropoff_longitude, dropoff_latitude, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, congestion_surcharge, airport_fee, total_amount, pickup_nyct2010_gid, dropoff_nyct2010_gid, pickup_location_id, dropoff_location_id)
SELECT
  cab_types.id,
  CASE
    WHEN trim(vendor_id) IN ('1', '2') THEN vendor_id::integer
    WHEN trim(upper(vendor_id)) = 'CMT' THEN 1
    WHEN trim(upper(vendor_id)) = 'VTS' THEN 2
    WHEN trim(upper(vendor_id)) = 'DDS' THEN 3
  END,
  tpep_pickup_datetime,
  tpep_dropoff_datetime,
  passenger_count,
  trip_distance,
  CASE WHEN pickup_longitude != 0 THEN pickup_longitude END,
  CASE WHEN pickup_latitude != 0 THEN pickup_latitude END,
  CASE WHEN trim(rate_code_id) IN ('1', '2', '3', '4', '5', '6') THEN rate_code_id::integer END,
  CASE
    WHEN trim(upper(store_and_fwd_flag)) IN ('Y', '1', '1.0') THEN true
    WHEN trim(upper(store_and_fwd_flag)) IN ('N', '0', '0.0') THEN false
  END,
  CASE WHEN dropoff_longitude != 0 THEN dropoff_longitude END,
  CASE WHEN dropoff_latitude != 0 THEN dropoff_latitude END,
  CASE
    WHEN trim(replace(payment_type, '"', '')) IN ('1', '2', '3', '4', '5', '6') THEN payment_type::integer
    WHEN trim(lower(replace(payment_type, '"', ''))) IN ('credit', 'cre', 'crd') THEN 1
    WHEN trim(lower(replace(payment_type, '"', ''))) IN ('cash', 'cas', 'csh') THEN 2
    WHEN trim(lower(replace(payment_type, '"', ''))) IN ('no charge', 'no') THEN 3
    WHEN trim(lower(replace(payment_type, '"', ''))) IN ('dispute', 'dis') THEN 4
  END,
  fare_amount,
  extra,
  mta_tax,
  tip_amount,
  tolls_amount,
  improvement_surcharge,
  congestion_surcharge,
  airport_fee,
  total_amount,
  tmp_pickups.gid,
  tmp_dropoffs.gid,
  coalesce(pickup_location_id, map_pickups.taxi_zone_location_id),
  coalesce(dropoff_location_id, map_dropoffs.taxi_zone_location_id)
FROM yellow_tripdata_staging
  INNER JOIN cab_types ON cab_types.type = 'yellow'
  LEFT JOIN tmp_pickups ON yellow_tripdata_staging.id = tmp_pickups.id
    LEFT JOIN nyct2010_taxi_zones_mapping map_pickups ON tmp_pickups.gid = map_pickups.nyct2010_gid
  LEFT JOIN tmp_dropoffs ON yellow_tripdata_staging.id = tmp_dropoffs.id
    LEFT JOIN nyct2010_taxi_zones_mapping map_dropoffs ON tmp_dropoffs.gid = map_dropoffs.nyct2010_gid;

TRUNCATE TABLE yellow_tripdata_staging;
VACUUM ANALYZE yellow_tripdata_staging;

DROP TABLE tmp_points;
DROP TABLE tmp_pickups;
DROP TABLE tmp_dropoffs;
