CREATE TABLE tmp_points AS
SELECT
  id,
  ST_SetSRID(ST_MakePoint(pickup_longitude, pickup_latitude), 4326) as pickup
FROM uber_trips_staging;  

CREATE INDEX idx_tmp_points_pickup ON tmp_points USING gist (pickup);

CREATE TABLE tmp_pickups AS
SELECT t.id, n.gid
FROM tmp_points t, nyct2010 n
WHERE ST_Within(t.pickup, n.geom);

INSERT INTO trips
(cab_type_id, vendor_id, pickup_datetime, pickup_longitude, pickup_latitude, pickup, pickup_nyct2010_gid)
SELECT
  cab_types.id,
  base_code,
  pickup_datetime,
  CASE WHEN pickup_longitude != 0 THEN pickup_longitude END,
  CASE WHEN pickup_latitude != 0 THEN pickup_latitude END,
  CASE
    WHEN pickup_longitude != 0 AND pickup_latitude != 0
    THEN ST_SetSRID(ST_MakePoint(pickup_longitude, pickup_latitude), 4326)
  END,
  tmp_pickups.gid
FROM
  uber_trips_staging
    INNER JOIN cab_types ON cab_types.type = 'uber'
    LEFT JOIN tmp_pickups ON uber_trips_staging.id = tmp_pickups.id;

TRUNCATE TABLE uber_trips_staging;
DROP TABLE tmp_points;
DROP TABLE tmp_pickups;
