INSERT INTO nyct2010
(boroname, ntaname, ntacode, geom)
SELECT
  'New Jersey',
  'Newark Airport',
  'NJ01',
  (SELECT geom FROM taxi_zones WHERE zone = 'Newark Airport');
