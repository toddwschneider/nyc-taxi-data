/*
Note:

This script was originally written in November 2015 and has not been
maintained as the dataset schema has evolved. In particular, the
uber_trips_2015 table has been replaced by the fhv_trips table, and there
might be other small breaking changes.

See https://github.com/toddwschneider/nyc-taxi-data/tree/f7ebdd7c0b9604ef76959ef2f13dea7b1a990f67
for the code/schema as it was at the time this script was written
*/

CREATE TABLE nyct2010_centroids AS
SELECT
  gid,
  ST_X(ST_Centroid(geom)) AS long,
  ST_Y(ST_Centroid(geom)) AS lat
FROM nyct2010;
ALTER TABLE nyct2010_centroids ADD PRIMARY KEY (gid);

CREATE TABLE neighborhood_centroids AS
SELECT
  ntacode,
  ntaname,
  boroname,
  ST_Union(geom) AS geom,
  ST_X(ST_Centroid(ST_Union(geom))) AS long,
  ST_Y(ST_Centroid(ST_Union(geom))) AS lat
FROM nyct2010
GROUP BY ntacode, ntaname, boroname;

/*
OPTIONAL: created indexes on trips table
indexing helps query performance, but each index on the trips table takes up an additional 24 GB of disk space
if you have disk space available, uncomment these CREATE INDEX lines
*/

-- CREATE INDEX index_trips_on_cab_type ON trips (cab_type_id);
-- CREATE INDEX index_trips_on_pickup_gid ON trips (pickup_nyct2010_gid);
-- CREATE INDEX index_trips_on_dropoff_gid ON trips (dropoff_nyct2010_gid);

CREATE TABLE hourly_pickups AS
SELECT
  date_trunc('hour', pickup_datetime) AS pickup_hour,
  cab_type_id,
  pickup_nyct2010_gid,
  COUNT(*)
FROM trips
WHERE pickup_nyct2010_gid IS NOT NULL
GROUP BY pickup_hour, cab_type_id, pickup_nyct2010_gid;

CREATE TABLE hourly_dropoffs AS
SELECT
  date_trunc('hour', dropoff_datetime) AS dropoff_hour,
  cab_type_id,
  dropoff_nyct2010_gid,
  COUNT(*)
FROM trips
WHERE dropoff_nyct2010_gid IS NOT NULL
  AND dropoff_datetime IS NOT NULL
  AND dropoff_datetime > '2008-12-31'
  AND dropoff_datetime < '2016-01-02'
GROUP BY dropoff_hour, cab_type_id, dropoff_nyct2010_gid;

CREATE TABLE hourly_uber_2015_pickups AS
SELECT
  date_trunc('hour', pickup_datetime) AS pickup_hour,
  u.nyct2010_ntacode,
  l.borough,
  COUNT(*)
FROM uber_trips_2015 u, taxi_zone_lookups l
WHERE u.location_id = l.location_id
GROUP BY pickup_hour, u.nyct2010_ntacode, l.borough;

CREATE INDEX index_hourly_pickups ON hourly_pickups (pickup_nyct2010_gid);
CREATE INDEX index_hourly_pickups_on_date ON hourly_pickups (date(pickup_hour));
CREATE INDEX index_hourly_dropoffs ON hourly_dropoffs (dropoff_nyct2010_gid);
CREATE INDEX index_hourly_uber_pickups ON hourly_uber_2015_pickups (nyct2010_ntacode);

CREATE TABLE daily_pickups_by_borough_and_type AS
SELECT
  date(pickup_hour) AS date,
  boroname,
  cab_types.type,
  SUM(count) AS trips
FROM hourly_pickups, nyct2010, cab_types
WHERE hourly_pickups.pickup_nyct2010_gid = nyct2010.gid
  AND hourly_pickups.cab_type_id = cab_types.id
GROUP BY date, boroname, cab_types.type;

WITH ntacode_to_boroname AS (
  SELECT DISTINCT ntacode, boroname FROM nyct2010
)
INSERT INTO daily_pickups_by_borough_and_type
SELECT
  date(pickup_hour) AS date,
  n.boroname,
  'uber' AS type,
  SUM(count) AS trips
FROM hourly_uber_2015_pickups u, ntacode_to_boroname n
WHERE u.nyct2010_ntacode = n.ntacode
GROUP BY date, n.boroname, type;

CREATE INDEX index_daily_pickups_by_borough_and_type ON daily_pickups_by_borough_and_type (date, type);

CREATE TABLE daily_dropoffs_by_borough AS
SELECT
  date(dropoff_hour) AS date,
  boroname,
  cab_types.type,
  SUM(count) AS trips
FROM hourly_dropoffs, nyct2010, cab_types
WHERE hourly_dropoffs.dropoff_nyct2010_gid = nyct2010.gid
  AND hourly_dropoffs.cab_type_id = cab_types.id
GROUP BY date, boroname, cab_types.type
ORDER BY date, boroname;

CREATE TABLE pickups_comparison AS
SELECT
  pickup_nyct2010_gid,
  ntacode,
  cab_type_id,
  CASE WHEN pickup_hour >= '2009-07-01' AND pickup_hour < '2010-07-01' THEN 0 ELSE 1 END AS period,
  SUM(count) AS pickups
FROM hourly_pickups, nyct2010
WHERE pickup_nyct2010_gid = gid
  AND cab_type_id IN (1, 2)
  AND (   (pickup_hour >= '2009-07-01' AND pickup_hour < '2010-07-01')
       OR (pickup_hour >= '2014-07-01' AND pickup_hour < '2015-07-01'))
GROUP BY pickup_nyct2010_gid, ntacode, cab_type_id, period
ORDER BY pickup_nyct2010_gid, ntacode, cab_type_id, period;

CREATE TABLE census_tract_pickup_growth_2009_2015 AS
WITH aggregates AS (
  SELECT
    pickup_nyct2010_gid,
    period,
    SUM(pickups) AS total,
    SUM(CASE WHEN cab_type_id = 1 THEN pickups ELSE 0 END) AS yellow,
    SUM(CASE WHEN cab_type_id = 2 THEN pickups ELSE 0 END) AS green
  FROM pickups_comparison
  GROUP BY pickup_nyct2010_gid, period
),
wide_format AS (
  SELECT
    pickup_nyct2010_gid,
    SUM(CASE WHEN period = 0 THEN total ELSE 0 END) AS total_0,
    SUM(CASE WHEN period = 1 THEN total ELSE 0 END) AS total_1,
    SUM(CASE WHEN period = 0 THEN yellow ELSE 0 END) AS yellow_0,
    SUM(CASE WHEN period = 1 THEN yellow ELSE 0 END) AS yellow_1,
    SUM(CASE WHEN period = 0 THEN green ELSE 0 END) AS green_0,
    SUM(CASE WHEN period = 1 THEN green ELSE 0 END) AS green_1
  FROM aggregates
  GROUP BY pickup_nyct2010_gid
)
SELECT
  gid,
  boroname,
  ntaname,
  total_1,
  total_0,
  yellow_1,
  yellow_0,
  green_1,
  green_0
FROM wide_format, nyct2010
WHERE pickup_nyct2010_gid = gid
  AND (total_0 > 100000 OR total_1 > 100000);

-- daily pickups with weather data
CREATE TABLE pickups_and_weather AS
WITH daily_pickups AS (
  SELECT
    date,
    SUM(CASE WHEN type IN ('yellow', 'green') THEN trips ELSE 0 END) AS taxi,
    SUM(CASE WHEN type = 'uber' THEN trips ELSE 0 END) AS uber
  FROM daily_pickups_by_borough_and_type
  WHERE boroname != 'New Jersey'
  GROUP BY date
)
SELECT
  d.*,
  w.precipitation,
  w.snow_depth,
  w.snowfall,
  w.max_temperature,
  w.min_temperature,
  w.average_wind_speed,
  EXTRACT(dow FROM d.date) AS dow,
  CASE WHEN EXTRACT(dow FROM d.date) BETWEEN 1 AND 5 THEN 'weekday' ELSE 'weekend' END AS dow_type,
  EXTRACT(year FROM d.date) AS year,
  EXTRACT(month FROM d.date) AS month,
  CASE
    WHEN EXTRACT(month FROM d.date) IN (12, 1, 2) THEN 'winter'
    WHEN EXTRACT(month FROM d.date) IN (3, 4, 5) THEN 'spring'
    WHEN EXTRACT(month FROM d.date) IN (6, 7, 8) THEN 'summer'
    WHEN EXTRACT(month FROM d.date) IN (9, 10, 11) THEN 'fall'
  END AS season
FROM
  daily_pickups d,
  central_park_weather_observations w
WHERE d.date = w.date
ORDER BY d.date;

-- see: http://gis.stackexchange.com/questions/8650/how-to-measure-the-accuracy-of-latitude-and-longitude
CREATE TABLE trips_by_lat_long_cab_type AS
SELECT
  cab_type_id,
  ROUND(pickup_longitude, 4) AS pickup_long,
  ROUND(pickup_latitude, 4) AS pickup_lat,
  COUNT(*) AS count
FROM trips
WHERE pickup_nyct2010_gid IS NOT NULL
  AND cab_type_id IN (1, 2)
GROUP BY cab_type_id, pickup_long, pickup_lat
ORDER BY cab_type_id, count;

CREATE TABLE dropoff_by_lat_long_cab_type AS
SELECT
  cab_type_id,
  ROUND(dropoff_longitude, 4) AS dropoff_long,
  ROUND(dropoff_latitude, 4) AS dropoff_lat,
  COUNT(*) AS count
FROM trips
WHERE dropoff_nyct2010_gid IS NOT NULL
GROUP BY cab_type_id, dropoff_long, dropoff_lat
ORDER BY cab_type_id, count;

-- census tract nightlife index
CREATE TABLE census_tract_pickups_by_hour AS
WITH nightlife_stats AS (
  SELECT
    pickup_nyct2010_gid,
    SUM(count) AS total_pickups,
    SUM(CASE WHEN EXTRACT(hour FROM pickup_hour) BETWEEN 5 AND 10 THEN count ELSE 0 END) AS morning,
    SUM(CASE WHEN EXTRACT(hour FROM pickup_hour) BETWEEN 11 AND 15 THEN count ELSE 0 END) AS afternoon,
    SUM(CASE WHEN EXTRACT(hour FROM pickup_hour) BETWEEN 16 AND 21 THEN count ELSE 0 END) AS evening,
    SUM(CASE WHEN EXTRACT(hour FROM pickup_hour) IN (22, 23, 0, 1, 2, 3, 4) THEN count ELSE 0 END) AS late_night,
    SUM(CASE WHEN EXTRACT(dow FROM pickup_hour) IN (0, 6) THEN count ELSE 0 END) AS weekend
  FROM hourly_pickups
  GROUP BY pickup_nyct2010_gid
)
SELECT
  nightlife_stats.*,
  nyct2010.ntaname,
  nyct2010.ntacode,
  nyct2010.boroname,
  nyct2010.boroct2010,
  nyct2010.ctlabel
FROM nightlife_stats, nyct2010
WHERE nightlife_stats.pickup_nyct2010_gid = nyct2010.gid;

-- dropoffs at airports
CREATE TABLE airport_trips AS
SELECT
  id,
  cab_type_id,
  pickup_datetime,
  dropoff_datetime,
  pickup_longitude,
  pickup_latitude,
  dropoff_longitude,
  dropoff_latitude,
  total_amount,
  payment_type,
  pickup_nyct2010_gid,
  dropoff_nyct2010_gid,
  CASE
    WHEN dropoff_nyct2010_gid = 1840 THEN 'LGA'
    WHEN dropoff_nyct2010_gid = 2056 THEN 'JFK'
    WHEN dropoff_nyct2010_gid = 2167 THEN 'EWR'
  END AS airport_code,
  EXTRACT(YEAR FROM pickup_datetime) AS year,
  EXTRACT(DOW FROM pickup_datetime) AS dow,
  EXTRACT(HOUR FROM pickup_datetime) AS hour,
  CASE
    WHEN EXTRACT(EPOCH FROM dropoff_datetime - pickup_datetime) / 60 BETWEEN 0.1 AND 240
    THEN EXTRACT(EPOCH FROM dropoff_datetime - pickup_datetime) / 60
  END AS duration_in_minutes
FROM trips
WHERE dropoff_nyct2010_gid IN (1840, 2056, 2167);

CREATE INDEX index_airport_trips ON airport_trips (pickup_nyct2010_gid);

CREATE TABLE airport_trips_summary AS
SELECT
  airport_code,
  n.ntacode,
  n.boroname,
  n.ntaname,
  CASE WHEN dow IN (0, 6) THEN 'weekend' ELSE 'weekday' END AS day_of_week,
  hour,
  COUNT(*) AS trips_count,
  AVG(duration_in_minutes) AS mean,
  percentile_cont(0.1) WITHIN GROUP (ORDER BY duration_in_minutes) AS pct10,
  percentile_cont(0.25) WITHIN GROUP (ORDER BY duration_in_minutes) AS pct25,
  percentile_cont(0.5) WITHIN GROUP (ORDER BY duration_in_minutes) AS pct50,
  percentile_cont(0.75) WITHIN GROUP (ORDER BY duration_in_minutes) AS pct75,
  percentile_cont(0.9) WITHIN GROUP (ORDER BY duration_in_minutes) AS pct90
FROM airport_trips t
  INNER JOIN nyct2010 n ON t.pickup_nyct2010_gid = n.gid
WHERE t.duration_in_minutes IS NOT NULL
GROUP BY airport_code, n.ntacode, n.boroname, n.ntaname, day_of_week, hour
ORDER BY trips_count DESC;

-- pickups at airports
CREATE TABLE airport_pickups AS
SELECT
  id,
  cab_type_id,
  pickup_datetime,
  dropoff_datetime,
  pickup_longitude,
  pickup_latitude,
  dropoff_longitude,
  dropoff_latitude,
  total_amount,
  payment_type,
  pickup_nyct2010_gid,
  dropoff_nyct2010_gid,
  CASE
    WHEN pickup_nyct2010_gid = 1840 THEN 'LGA'
    WHEN pickup_nyct2010_gid = 2056 THEN 'JFK'
    WHEN pickup_nyct2010_gid = 2167 THEN 'EWR'
  END AS airport_code,
  EXTRACT(YEAR FROM pickup_datetime) AS year,
  EXTRACT(DOW FROM pickup_datetime) AS dow,
  EXTRACT(HOUR FROM pickup_datetime) AS hour,
  CASE
    WHEN EXTRACT(EPOCH FROM dropoff_datetime - pickup_datetime) / 60 BETWEEN 0.1 AND 240
    THEN EXTRACT(EPOCH FROM dropoff_datetime - pickup_datetime) / 60
  END AS duration_in_minutes
FROM trips
WHERE pickup_nyct2010_gid IN (1840, 2056, 2167);

INSERT INTO airport_pickups
(id, cab_type_id, pickup_datetime, pickup_nyct2010_gid, airport_code, year, dow, hour)
SELECT
  uber_trips_2015.id,
  cab_types.id,
  pickup_datetime,
  CASE location_id
    WHEN 1 THEN 2167
    WHEN 132 THEN 2056
    WHEN 138 THEN 1840
  END,
  CASE location_id
    WHEN 1 THEN 'EWR'
    WHEN 132 THEN 'JFK'
    WHEN 138 THEN 'LGA'
  END,
  EXTRACT(YEAR FROM pickup_datetime) AS year,
  EXTRACT(DOW FROM pickup_datetime) AS dow,
  EXTRACT(HOUR FROM pickup_datetime) AS hour
FROM uber_trips_2015, cab_types
WHERE cab_types.type = 'uber'
  AND location_id IN (1, 132, 138);

CREATE TABLE airport_pickups_by_type AS
SELECT
  date(date_trunc('day', pickup_datetime)) AS date,
  airport_code,
  cab_types.type,
  COUNT(*) AS pickups
FROM airport_pickups, cab_types
WHERE airport_code IN ('LGA', 'JFK')
  AND cab_type_id = cab_types.id
GROUP BY date, airport_code, cab_types.type;

-- Bridge and Tunnel
CREATE TABLE bridge_and_tunnel AS
SELECT *
FROM trips
WHERE pickup_nyct2010_gid IN (899, 1895)
  AND EXTRACT(dow FROM pickup_datetime) = 6
  AND EXTRACT(hour FROM pickup_datetime) >= 18;

CREATE INDEX index_bridge_and_tunnel ON bridge_and_tunnel (dropoff_nyct2010_gid);

-- Northside Williamsburg
CREATE TABLE northside_pickups AS
SELECT
  id, pickup_datetime, pickup_longitude, pickup_latitude, pickup_nyct2010_gid,
  date(date_trunc('month', pickup_datetime)) AS month
FROM trips
WHERE pickup_nyct2010_gid IN (1100, 275, 251, 1215, 267);

CREATE TABLE northside_dropoffs AS
SELECT * FROM trips
WHERE dropoff_nyct2010_gid = 1100;

-- Custom queries
CREATE TABLE custom_geometries (
  name varchar
);
SELECT AddGeometryColumn('custom_geometries', 'geom', 4326, 'POLYGON', 2);

-- NB: these are approximate, but close enough
INSERT INTO custom_geometries
VALUES
('Hamptons', ST_GeomFromText('POLYGON((-72.5614955 40.8257501,
                                       -72.5614955 40.9253558,
                                       -71.9083121 41.2297656,
                                       -71.7730478 40.7332663,
                                       -72.5614955 40.8257501))', 4326)),
('Greenwich', ST_GeomFromText('POLYGON((-73.6608053 40.9892874,
                                        -73.7293878 41.1004968,
                                        -73.5657974 41.1751049,
                                        -73.547673 40.9980165,
                                        -73.6608053 40.9892874))', 4326)),
('Goldman Sachs', ST_GeomFromText('POLYGON((-74.0141012 40.7152191,
                                            -74.013777 40.7152275,
                                            -74.0141027 40.7138745,
                                            -74.0144185 40.7140753,
                                            -74.0141012 40.7152191))', 4326)),
('Citigroup', ST_GeomFromText('POLYGON((-74.011869 40.7217236,
                                        -74.009867 40.721493,
                                        -74.010140 40.720053,
                                        -74.012083 40.720267,
                                        -74.011869 40.7217236))', 4326));

CREATE INDEX index_custom_geoms ON custom_geometries USING gist (geom);

CREATE TABLE goldman_sachs_dropoffs AS
SELECT trips.*
FROM trips, custom_geometries
WHERE
  custom_geometries.name = 'Goldman Sachs'
  AND dropoff_nyct2010_gid = 2100
  AND ST_Within(dropoff, custom_geometries.geom);

WITH aggregates AS (
  SELECT
    pickup_nyct2010_gid,
    COUNT(*) AS count
  FROM goldman_sachs_dropoffs
  WHERE EXTRACT(DOW FROM dropoff_datetime) BETWEEN 1 AND 5
    AND EXTRACT(HOUR FROM dropoff_datetime) BETWEEN 5 AND 8
    AND pickup_nyct2010_gid IS NOT NULL
  GROUP BY pickup_nyct2010_gid
  ORDER BY count DESC
)
SELECT
  n.ntaname, SUM(count) AS count
FROM aggregates a, nyct2010 n
WHERE a.pickup_nyct2010_gid = n.gid
GROUP BY n.ntaname
ORDER BY count DESC;

CREATE TABLE citigroup_dropoffs AS
SELECT trips.*
FROM trips, custom_geometries
WHERE
  custom_geometries.name = 'Citigroup'
  AND dropoff_nyct2010_gid = 1806
  AND ST_Within(dropoff, custom_geometries.geom);

CREATE TABLE greenwich_hamptons_dropoffs AS
WITH greenwich AS (SELECT * FROM custom_geometries WHERE name = 'Greenwich'),
     hamptons AS (SELECT * FROM custom_geometries WHERE name = 'Hamptons')
SELECT *,
  ST_Within(dropoff, (SELECT geom FROM greenwich)) AS greenwich,
  ST_Within(dropoff, (SELECT geom FROM hamptons)) AS hamptons
FROM trips
WHERE
  dropoff_nyct2010_gid IS NULL
  AND (ST_Within(dropoff, (SELECT geom FROM greenwich))
       OR ST_Within(dropoff, (SELECT geom FROM hamptons)));

CREATE TABLE die_hard_3 AS
SELECT
  *,
  EXTRACT(YEAR FROM pickup_datetime) AS year,
  EXTRACT(DOW FROM pickup_datetime) AS dow,
  EXTRACT(HOUR FROM pickup_datetime) AS hour,
  CASE
    WHEN EXTRACT(EPOCH FROM dropoff_datetime - pickup_datetime) / 60 BETWEEN 0.1 AND 240
    THEN EXTRACT(EPOCH FROM dropoff_datetime - pickup_datetime) / 60
  END AS duration_in_minutes
FROM trips
WHERE pickup_nyct2010_gid IN (1946, 1301)
  AND dropoff_nyct2010_gid = 1791;

-- cash vs. credit
CREATE TABLE payment_types AS
SELECT
  date_trunc('month', pickup_datetime) AS month,
  FLOOR(total_amount / 10) * 10 AS total_amount_bucket,
  payment_type,
  COUNT(*) AS count
FROM trips
GROUP BY month, total_amount_bucket, payment_type;

WITH pt AS (
SELECT
  date(month) AS month,
  CASE
    WHEN LOWER(payment_type) IN ('2', 'csh', 'cash', 'cas') THEN 'cash'
    WHEN LOWER(payment_type) IN ('1', 'crd', 'credit', 'cre') THEN 'credit'
  END AS payment_type,
  SUM(count) AS trips
FROM payment_types
GROUP BY month, payment_type
)
SELECT
  month,
  SUM(CASE WHEN payment_type = 'credit' THEN trips ELSE 0 END) / SUM(trips) AS frac_credit
FROM pt
GROUP BY month
ORDER BY month;
