CREATE TABLE tmp_points AS
SELECT
  id,
  ST_SetSRID(ST_MakePoint(pickup_longitude, pickup_latitude), 4326) as pickup
FROM uber_trips_2014;

CREATE INDEX ON tmp_points USING gist (pickup);

CREATE TABLE tmp_pickups AS
SELECT t.id, z.locationid
FROM tmp_points t, taxi_zones z
WHERE ST_Within(t.pickup, z.geom);

INSERT INTO fhv_trips
(dispatching_base_num, pickup_datetime, pickup_location_id)
SELECT
  base_code,
  pickup_datetime,
  tmp_pickups.locationid
FROM uber_trips_2014
  LEFT JOIN tmp_pickups ON uber_trips_2014.id = tmp_pickups.id;

DROP TABLE tmp_points;
DROP TABLE tmp_pickups;
