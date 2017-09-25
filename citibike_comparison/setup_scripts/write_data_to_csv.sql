/*
adapted from https://stackoverflow.com/a/43311325
and https://stackoverflow.com/a/29000817
*/

SET vars.pwd TO :'PWD';

DO
$do$
DECLARE
  _start_taxi_zone_id int;
  _pwd varchar := current_setting('vars.pwd');
BEGIN
  FOR _start_taxi_zone_id IN (
    SELECT start_taxi_zone_id
    FROM total_trips_by_start_zone
    GROUP BY start_taxi_zone_id
    HAVING SUM(CASE WHEN type = 'taxi' THEN count ELSE 0 END) >= 100
      AND SUM(CASE WHEN type = 'citibike' THEN count ELSE 0 END) >= 100
    ORDER BY start_taxi_zone_id
  )
  LOOP
    EXECUTE format('COPY (
      SELECT
        type,
        end_taxi_zone_id,
        duration_in_seconds,
        date,
        hour_of_day
      FROM taxi_citibike_trips
      WHERE start_taxi_zone_id = %L
        AND end_taxi_zone_id != start_taxi_zone_id
        AND day_of_week IN (1, 2, 3, 4, 5)
        AND date NOT IN (SELECT date FROM holidays)
    ) TO %L CSV HEADER',
    _start_taxi_zone_id,
    _pwd || '/data/weekday_trips_start_zone_' || _start_taxi_zone_id || '.csv');
  END LOOP;
END
$do$;
