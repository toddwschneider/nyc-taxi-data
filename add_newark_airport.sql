INSERT INTO nyct2010
(boroname, ntaname, ntacode, geom)
SELECT
  'New Jersey',
  'Newark Airport',
  'NJ01',
  ST_GeomFromText('MULTIPOLYGON(((-74.1795837 40.6697509,
                                  -74.1972654 40.6774568,
                                  -74.1922779 40.6900883,
                                  -74.1804249 40.7077294,
                                  -74.1518226 40.7072984,
                                  -74.1795837 40.6697509)))', 4326);
