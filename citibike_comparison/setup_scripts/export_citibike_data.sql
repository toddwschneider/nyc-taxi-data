CREATE TEMP TABLE trips_to_export AS
SELECT
  'citibike'::varchar AS type,
  t.id AS external_id,
  sstz.locationid AS start_taxi_zone_id,
  estz.locationid AS end_taxi_zone_id,
  t.start_time AS start_time,
  t.stop_time AS end_time,
  extract(epoch FROM t.stop_time - t.start_time) AS duration_in_seconds,
  date(t.start_time) AS date,
  extract(dow FROM t.start_time) AS day_of_week,
  extract(hour FROM t.start_time) AS hour_of_day
FROM trips t
  INNER JOIN stations ss ON t.start_station_id = ss.id
    INNER JOIN taxi_zones sstz ON ss.taxi_zone_gid = sstz.gid
  INNER JOIN stations es ON t.end_station_id = es.id
    INNER JOIN taxi_zones estz ON es.taxi_zone_gid = estz.gid
WHERE t.start_station_id != t.end_station_id
  AND t.start_time >= '2013-07-01'
  AND t.start_time < '2017-07-01'
  AND t.stop_time < '2017-07-01 02:00:00'
  AND t.user_type = 'Subscriber'
  AND extract(epoch FROM t.stop_time - t.start_time) BETWEEN 120 AND 7200;

\copy (SELECT * FROM trips_to_export) TO 'data/citibike_trips_for_comparison.csv' CSV HEADER;
