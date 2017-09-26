CREATE UNIQUE INDEX idx_taxi_citibike_trips_uniq ON taxi_citibike_trips (type, external_id);
CREATE INDEX idx_taxi_citibike_trips_on_start_zone ON taxi_citibike_trips (start_taxi_zone_id);

CREATE TABLE total_trips_by_start_zone AS
SELECT
  type,
  start_taxi_zone_id,
  COUNT(*) AS count
FROM taxi_citibike_trips
GROUP BY type, start_taxi_zone_id;
