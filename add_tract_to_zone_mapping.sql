CREATE TABLE nyct2010_taxi_zones_mapping AS
SELECT
  ct.gid AS nyct2010_gid,
  tz.locationid AS taxi_zone_location_id,
  ST_Area(ST_Intersection(ct.geom, tz.geom)) / ST_Area(ct.geom) AS overlap
FROM nyct2010 ct, taxi_zones tz
WHERE ST_Intersects(ct.geom, tz.geom)
  AND ST_Area(ST_Intersection(ct.geom, tz.geom)) / ST_Area(ct.geom) > 0.5;

CREATE UNIQUE INDEX index_mapping_on_tract_unique ON nyct2010_taxi_zones_mapping (nyct2010_gid);
CREATE INDEX index_mapping_on_tract_and_zone ON nyct2010_taxi_zones_mapping (nyct2010_gid, taxi_zone_location_id);
