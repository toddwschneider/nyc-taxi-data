CREATE TABLE monthly_taxi_travel_times AS
SELECT
  pickup_location_id,
  dropoff_location_id,
  date(date_trunc('month', pickup_datetime)) AS month,
  extract(dow FROM pickup_datetime) IN (1, 2, 3, 4, 5) AS weekday,
  w.precipitation > 0.1 AS date_with_precipitation,
  CASE
    WHEN extract(hour FROM pickup_datetime) IN (8, 9, 10) THEN 'morning'
    WHEN extract(hour FROM pickup_datetime) IN (11, 12, 13, 14, 15) THEN 'midday'
    WHEN extract(hour FROM pickup_datetime) IN (16, 17, 18) THEN 'afternoon'
    WHEN extract(hour FROM pickup_datetime) IN (19, 20, 21) THEN 'evening'
    ELSE 'other'
  END AS time_bucket,
  COUNT(*) AS trips,
  AVG(extract(epoch FROM dropoff_datetime - pickup_datetime)) AS avg_duration,
  AVG(trip_distance) AS avg_distance,
  SUM(trip_distance) / (SUM(extract(epoch FROM dropoff_datetime - pickup_datetime)) / 3600) AS avg_mph
FROM trips t
  INNER JOIN central_park_weather_observations w ON date(t.pickup_datetime) = w.date
WHERE cab_type_id IN (1, 2)
  AND pickup_location_id IS NOT NULL
  AND dropoff_location_id IS NOT NULL
  AND extract(epoch FROM dropoff_datetime - pickup_datetime) BETWEEN 120 AND 7200
  AND trip_distance BETWEEN 0.1 AND 100
  AND date(pickup_datetime) NOT IN (SELECT date FROM holidays)
GROUP BY
  pickup_location_id,
  dropoff_location_id,
  month,
  weekday,
  date_with_precipitation,
  time_bucket
ORDER BY
  pickup_location_id,
  dropoff_location_id,
  month,
  weekday,
  date_with_precipitation,
  time_bucket;

CREATE TABLE avg_trip_distances AS
SELECT
  start_taxi_zone_id,
  end_taxi_zone_id,
  AVG(trip_distance) AS avg_distance,
  COUNT(*) AS count
FROM taxi_citibike_trips
WHERE trip_distance IS NOT NULL
  AND trip_distance BETWEEN 0.1 AND 100
GROUP BY start_taxi_zone_id, end_taxi_zone_id;

CREATE TABLE weekday_taxi_trips_by_pickup_and_dropoff AS
SELECT
  pickup_location_id,
  dropoff_location_id,
  COUNT(*)
FROM trips
WHERE cab_type_id IN (1, 2)
  AND pickup_datetime >= '2016-07-01'
  AND pickup_datetime < '2017-07-01'
  AND extract(dow FROM pickup_datetime) IN (1, 2, 3, 4, 5)
GROUP BY pickup_location_id, dropoff_location_id
ORDER BY pickup_location_id, dropoff_location_id;

CREATE TABLE citibike_zones AS
SELECT DISTINCT start_taxi_zone_id AS zone_id
FROM total_trips_by_start_zone
WHERE type = 'citibike'
ORDER BY zone_id;

/* 79% of weekday taxi trips start and end within zones that have Citi Bike stations */
WITH q AS (
  SELECT
    SUM(count) AS total,
    SUM(
      CASE
      WHEN pickup_location_id IN (SELECT zone_id FROM citibike_zones)
        AND dropoff_location_id IN (SELECT zone_id FROM citibike_zones)
      THEN count
      END
    ) AS within_citibike_zones
  FROM weekday_taxi_trips_by_pickup_and_dropoff
)
SELECT *, within_citibike_zones / total FROM q;

/*
airports (LGA, JFK, EWR) account for 32% of weekday taxi trips
that start or end in zones that don't have Citi Bike stations
*/
WITH q AS (
  SELECT
    SUM(count) AS count,
    SUM(
      CASE
      WHEN pickup_location_id IN (1, 132, 138)
        OR dropoff_location_id IN (1, 132, 138)
      THEN count
      END
    ) AS to_or_from_airport
  FROM weekday_taxi_trips_by_pickup_and_dropoff
  WHERE pickup_location_id NOT IN (SELECT zone_id FROM citibike_zones)
    OR dropoff_location_id NOT IN (SELECT zone_id FROM citibike_zones)
)
SELECT *, to_or_from_airport / count FROM q;

WITH q AS (
  SELECT
    pickup_location_id,
    SUM(count) AS count
  FROM weekday_taxi_trips_by_pickup_and_dropoff
  WHERE pickup_location_id NOT IN (SELECT zone_id FROM citibike_zones)
    OR dropoff_location_id NOT IN (SELECT zone_id FROM citibike_zones)
  GROUP BY pickup_location_id
  ORDER BY count DESC
)
SELECT q.*, z.zone
FROM q LEFT JOIN taxi_zones z ON q.pickup_location_id = z.locationid;

WITH q AS (
  SELECT
    dropoff_location_id,
    SUM(count) AS count
  FROM weekday_taxi_trips_by_pickup_and_dropoff
  WHERE pickup_location_id NOT IN (SELECT zone_id FROM citibike_zones)
    OR dropoff_location_id NOT IN (SELECT zone_id FROM citibike_zones)
  GROUP BY dropoff_location_id
  ORDER BY count DESC
)
SELECT q.*, z.zone
FROM q LEFT JOIN taxi_zones z ON q.dropoff_location_id = z.locationid;

/*
-- NB this query has to be run from the nyc-citibike-data database, not nyc-taxi-data

CREATE TABLE monthly_citibike_travel_times AS
SELECT
  sstz.locationid AS start_location_id,
  estz.locationid AS end_location_id,
  date(date_trunc('month', t.start_time)) AS month,
  extract(dow FROM t.start_time) IN (1, 2, 3, 4, 5) AS weekday,
  CASE
    WHEN extract(hour FROM t.start_time) IN (8, 9, 10) THEN 'morning'
    WHEN extract(hour FROM t.start_time) IN (11, 12, 13, 14, 15) THEN 'midday'
    WHEN extract(hour FROM t.start_time) IN (16, 17, 18) THEN 'afternoon'
    WHEN extract(hour FROM t.start_time) IN (19, 20, 21) THEN 'evening'
    ELSE 'other'
  END AS time_bucket,
  w.precipitation > 0.1 AS date_with_precipitation,
  COUNT(*) AS trips,
  AVG(extract(epoch FROM t.stop_time - t.start_time)) AS avg_duration
FROM trips t
  INNER JOIN stations ss ON t.start_station_id = ss.id
    INNER JOIN taxi_zones sstz ON ss.taxi_zone_gid = sstz.gid
  INNER JOIN stations es ON t.end_station_id = es.id
    INNER JOIN taxi_zones estz ON es.taxi_zone_gid = estz.gid
  INNER JOIN central_park_weather_observations w ON date(t.start_time) = w.date
WHERE t.start_station_id != t.end_station_id
  AND t.start_time >= '2013-07-01'
  AND t.start_time < '2017-07-01'
  AND t.stop_time < '2017-07-01 02:00:00'
  AND t.user_type = 'Subscriber'
  AND extract(epoch FROM t.stop_time - t.start_time) BETWEEN 120 AND 7200
GROUP BY
  start_location_id,
  end_location_id,
  month,
  weekday,
  date_with_precipitation,
  time_bucket
ORDER BY
  start_location_id,
  end_location_id,
  month,
  weekday,
  date_with_precipitation,
  time_bucket;
*/
