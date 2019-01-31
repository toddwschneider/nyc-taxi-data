-- pickups by geography
CREATE TABLE daily_pickups_taxi AS
SELECT
 cab_type_id,
 date(pickup_datetime) AS date,
 pickup_location_id,
 COUNT(*) AS trips
FROM trips
GROUP BY cab_type_id, date(pickup_datetime), pickup_location_id
ORDER BY cab_type_id, date(pickup_datetime), pickup_location_id;

CREATE TABLE daily_pickups_fhv AS
SELECT
  dba_category,
  date(pickup_datetime) AS date,
  pickup_location_id,
  COUNT(*) AS trips
FROM fhv_trips t, fhv_bases b
WHERE t.dispatching_base_num = b.base_number
GROUP BY dba_category, date(pickup_datetime), pickup_location_id
ORDER BY dba_category, date(pickup_datetime), pickup_location_id;

CREATE TABLE daily_with_locations (
  car_type text,
  date date,
  pickup_location_id integer,
  trips integer
);
CREATE UNIQUE INDEX idx_daily_with_locations ON daily_with_locations (car_type, date, pickup_location_id);

INSERT INTO daily_with_locations
SELECT
  CASE cab_type_id WHEN 1 THEN 'yellow' WHEN 2 THEN 'green' WHEN 3 THEN 'uber' END,
  date,
  pickup_location_id,
  trips
FROM daily_pickups_taxi
WHERE date BETWEEN '2009-01-01' AND '2017-12-31'
ORDER BY cab_type_id, date, pickup_location_id;

INSERT INTO daily_with_locations
SELECT *
FROM daily_pickups_fhv
WHERE date BETWEEN '2009-01-01' AND '2017-12-31'
ORDER BY dba_category, date, pickup_location_id;

\copy (SELECT * FROM daily_with_locations) TO 'data/daily_trips_with_location_id.csv' CSV HEADER;
\copy (SELECT locationid, zone, borough FROM taxi_zones ORDER BY locationid) TO 'data/taxi_zones_simple.csv' CSV HEADER;

CREATE TABLE taxi_zone_centroids AS
SELECT
  gid,
  ST_Centroid(ST_Transform(geom, 2263)) AS geom
FROM taxi_zones;
ALTER TABLE taxi_zone_centroids ADD PRIMARY KEY (gid);

CREATE TABLE manhattan_centroid AS
SELECT
  ST_Centroid(ST_Union(ST_Transform(geom, 2263))) AS geom
FROM taxi_zones
WHERE borough = 'Manhattan';

/* see http://www.charlespetzold.com/etc/AvenuesOfManhattan/ */
CREATE TABLE rotated_taxi_zones AS
SELECT
  t.gid,
  ST_Rotate(t.geom, 29 * 2 * pi() / 360, m.geom) AS rotated_geom,
  ST_X(ST_Rotate(t.geom, 29 * 2 * pi() / 360, m.geom)) AS rotated_x,
  ST_Y(ST_Rotate(t.geom, 29 * 2 * pi() / 360, m.geom)) AS rotated_y
FROM taxi_zone_centroids t, manhattan_centroid m;
ALTER TABLE rotated_taxi_zones ADD PRIMARY KEY (gid);

CREATE TABLE hub_zones AS
SELECT z.gid, z.locationid, z.zone, z.borough
FROM taxi_zones z, rotated_taxi_zones r
WHERE z.gid = r.gid
  AND z.borough = 'Manhattan'
  AND z.zone NOT LIKE 'Governor''s Island%'
  AND r.rotated_y <= 216968
ORDER BY r.rotated_y DESC;
CREATE UNIQUE INDEX idx_hub ON hub_zones (gid);

CREATE TABLE daily_trips AS
SELECT
  car_type,
  date,
  SUM(trips) AS trips,
  'total'::text AS geo
FROM daily_with_locations
GROUP BY car_type, date
ORDER BY car_type, date;

CREATE TABLE daily_manhattan AS
SELECT
  car_type,
  date,
  SUM(trips) AS trips,
  'manhattan'::text AS geo
FROM daily_with_locations
WHERE pickup_location_id IN (SELECT locationid FROM taxi_zones WHERE borough = 'Manhattan')
GROUP BY car_type, date
ORDER BY car_type, date;

CREATE TABLE daily_manhattan_hub AS
SELECT
  car_type,
  date,
  SUM(trips) AS trips,
  'manhattan_hub'::text AS geo
FROM daily_with_locations
WHERE pickup_location_id IN (SELECT locationid FROM hub_zones)
GROUP BY car_type, date
ORDER BY car_type, date;

-- JFK = 132, LGA = 138
CREATE TABLE daily_airports AS
SELECT
  car_type,
  date,
  SUM(trips) AS trips,
  'airports'::text AS geo
FROM daily_with_locations
WHERE pickup_location_id IN (132, 138)
GROUP BY car_type, date
ORDER BY car_type, date;

CREATE TABLE daily_outer_boroughs_ex_airports AS
SELECT
  car_type,
  date,
  SUM(trips) AS trips,
  'outer_boroughs_ex_airports'::text AS geo
FROM daily_with_locations
WHERE pickup_location_id IN (
  SELECT locationid
  FROM taxi_zones
  WHERE borough IN ('Bronx', 'Brooklyn', 'Queens', 'Staten Island')
    AND locationid NOT IN (132, 138)
)
GROUP BY car_type, date
ORDER BY car_type, date;



-- JFK protest / #DeleteUber analysis
-- JFK airport = location 132
CREATE TABLE jfk_hourly_pickups_taxi AS
SELECT
 cab_type_id,
 date_trunc('hour', pickup_datetime) AS pickup_hour,
 pickup_location_id,
 COUNT(*) AS trips
FROM trips
WHERE pickup_location_id = 132
GROUP BY cab_type_id, pickup_hour, pickup_location_id
ORDER BY cab_type_id, pickup_hour, pickup_location_id;

CREATE TABLE jfk_hourly_pickups_fhv AS
SELECT
  dba_category,
  date_trunc('hour', pickup_datetime) AS pickup_hour,
  pickup_location_id,
  COUNT(*) AS trips
FROM fhv_trips t, fhv_bases b
WHERE t.dispatching_base_num = b.base_number
  AND t.pickup_location_id = 132
GROUP BY dba_category, pickup_hour, pickup_location_id
ORDER BY dba_category, pickup_hour, pickup_location_id;

-- Uber vs. Lyft
CREATE TABLE uber_vs_lyft AS
SELECT
  CASE
    WHEN date BETWEEN '2016-01-01' AND '2016-12-31' THEN '2016'
    WHEN date BETWEEN '2017-01-01' AND '2017-01-28' THEN 'pre_strike'
    WHEN date BETWEEN '2017-01-29' AND '2017-02-04' THEN 'post_strike'
    WHEN date BETWEEN '2017-02-05' AND '2017-12-31' THEN 'rest_of_2017'
  END AS era,
  pickup_location_id,
  SUM(CASE WHEN car_type = 'uber' THEN trips END) / SUM(trips)::numeric AS uber_share,
  SUM(CASE WHEN car_type = 'lyft' THEN trips END) / SUM(trips)::numeric AS lyft_share,
  SUM(CASE WHEN car_type = 'uber' THEN trips END) AS uber_trips,
  SUM(CASE WHEN car_type = 'lyft' THEN trips END) AS lyft_trips,
  SUM(trips) AS total_trips,
  COUNT(DISTINCT date) AS days
FROM daily_with_locations
WHERE car_type IN ('uber', 'lyft')
  AND date >= '2016-01-01'
  AND date < '2018-01-01'
GROUP BY era, pickup_location_id
ORDER BY pickup_location_id, era;

CREATE TABLE uber_vs_lyft_carto_data AS
SELECT
  *,
  ROUND(lyft_share_change * 100) || '%' AS lyft_share_change_pct,
  ROUND(pre_strike_lyft_share * 100) || '%' AS pre_strike_lyft_share_pct,
  ROUND(post_strike_lyft_share * 100) || '%' AS post_strike_lyft_share_pct,
  ROUND(rest_of_2017_lyft_share * 100) || '%' AS rest_of_2017_lyft_share_pct,
  ROUND(lyft_share_2016 * 100) || '%' AS lyft_share_2016_pct
FROM (
  SELECT
    z.locationid,
    z.zone,
    z.borough,
    SUM(CASE era WHEN 'post_strike' THEN lyft_share WHEN 'pre_strike' THEN -lyft_share END) AS lyft_share_change,
    SUM(CASE era WHEN 'pre_strike' THEN lyft_share END) AS pre_strike_lyft_share,
    SUM(CASE era WHEN 'post_strike' THEN lyft_share END) AS post_strike_lyft_share,
    SUM(CASE era WHEN 'rest_of_2017' THEN lyft_share END) AS rest_of_2017_lyft_share,
    SUM(CASE era WHEN '2016' THEN lyft_share END) AS lyft_share_2016
  FROM uber_vs_lyft ul
    INNER JOIN taxi_zones z ON ul.pickup_location_id = z.locationid
  GROUP BY z.locationid, z.zone, z.borough
  HAVING SUM(CASE WHEN era = 'pre_strike' THEN total_trips END) > 250
) q
ORDER BY lyft_share_change DESC;

\copy (SELECT * FROM uber_vs_lyft_carto_data) TO 'data/uber_vs_lyft_carto_data.csv' CSV HEADER;

-- 2016 election data
CREATE TABLE election_results_raw (
  ad text,
  ed text,
  county text,
  edad_status text,
  event text,
  party text,
  office text,
  district_key text,
  vote_for integer,
  unit_name text,
  tally_as_text text
);

-- NYC Board of Elections
-- http://vote.nyc.ny.us/html/results/2016.shtml
COPY election_results_raw FROM PROGRAM 'curl "http://vote.nyc.ny.us/downloads/csv/election_results/2016/20161108General%20Election/00000100000Citywide%20President%20Vice%20President%20Citywide%20EDLevel.csv"' CSV HEADER;

CREATE TABLE election_results AS
SELECT
  *,
  (ad || ed)::int AS election_district,
  replace(tally_as_text, ',', '')::int AS tally,
  trim(regexp_replace(unit_name, E'\\(.+?\\)', '')) AS candidate
FROM election_results_raw;

ALTER TABLE election_results DROP COLUMN tally_as_text;
DROP TABLE election_results_raw;

CREATE TABLE votes_by_district AS
SELECT
  election_district,
  candidate,
  SUM(tally) AS votes
FROM election_results
WHERE candidate LIKE 'Hillary Clinton%'
  OR candidate LIKE 'Donald J. Trump%'
  OR candidate LIKE 'Jill Stein%'
  OR candidate LIKE 'Gary Johnson%'
GROUP BY election_district, candidate
ORDER BY election_district, votes DESC;

/*
the following query requires you to download and load the NYC election districts shapefile

download URL:
https://data.cityofnewyork.us/api/geospatial/h2n3-98hq?method=export&format=Shapefile

command to import:
shp2pgsql -s 4326 -I ElectionDistricts/geo_export_5e20ee11-fdae-4798-b593-1bc530f23ca9.shp election_districts | psql -d nyc-taxi-data
*/

-- election districts and taxi zones do not align; estimate based on geographic overlap
CREATE TABLE election_districts_to_taxi_zones AS
SELECT
  ed.elect_dist,
  tz.locationid AS taxi_zone_location_id,
  ST_Area(
    ST_Intersection(
      ST_MakeValid(ed.geom),
      tz.geom
    )
  ) / ST_Area(ed.geom) AS overlap
FROM election_districts ed, taxi_zones tz
WHERE ST_Intersects(ed.geom, tz.geom);
DELETE FROM election_districts_to_taxi_zones WHERE overlap < 0.001;

CREATE TABLE votes_by_taxi_zone AS
SELECT
  z.locationid,
  z.zone,
  z.borough,
  v.candidate,
  SUM(v.votes * map.overlap) AS estimated_votes
FROM votes_by_district v
  INNER JOIN election_districts_to_taxi_zones map ON v.election_district = map.elect_dist
  INNER JOIN taxi_zones z ON map.taxi_zone_location_id = z.locationid
GROUP BY z.locationid, z.zone, z.borough, v.candidate;

CREATE TABLE election_results_by_taxi_zone AS
SELECT
  locationid,
  zone,
  borough,
  ROUND(SUM(estimated_votes)::numeric) AS estimated_total_votes,
  SUM(CASE WHEN candidate LIKE 'Donald J. Trump%' THEN estimated_votes END) / SUM(estimated_votes) AS trump,
  SUM(CASE WHEN candidate LIKE 'Hillary Clinton%' THEN estimated_votes END) / SUM(estimated_votes) AS clinton,
  SUM(CASE WHEN candidate LIKE 'Gary Johnson%' THEN estimated_votes END) / SUM(estimated_votes) AS johnson,
  SUM(CASE WHEN candidate LIKE 'Jill Stein%' THEN estimated_votes END) / SUM(estimated_votes) AS stein
FROM votes_by_taxi_zone
GROUP BY locationid, zone, borough
HAVING SUM(estimated_votes) > 0
ORDER BY locationid;

\copy (SELECT * FROM election_results_by_taxi_zone) TO 'data/election_results_by_taxi_zone.csv' CSV HEADER;
