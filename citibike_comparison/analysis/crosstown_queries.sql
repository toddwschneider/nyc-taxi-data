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

CREATE TABLE taxi_zone_distances AS
SELECT
  z1.gid AS from_gid,
  z2.gid AS to_gid,
  ST_Distance(z1.rotated_geom, z2.rotated_geom) AS distance,
  ST_Distance(
    z1.rotated_geom,
    ST_SetSRID(ST_MakePoint(z2.rotated_x, z1.rotated_y), 2263)
  ) AS distance_crosstown,
  ST_Distance(
    z1.rotated_geom,
    ST_SetSRID(ST_MakePoint(z1.rotated_x, z2.rotated_y), 2263)
  ) AS distance_uptown
FROM rotated_taxi_zones z1
  CROSS JOIN rotated_taxi_zones z2
WHERE z1.gid != z2.gid
ORDER BY z1.gid, z2.gid;
CREATE UNIQUE INDEX idx_tz_distances ON taxi_zone_distances (from_gid, to_gid);
