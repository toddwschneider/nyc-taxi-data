UPDATE uber_trips_2015
SET nyct2010_ntacode = taxi_zone_lookups.nyct2010_ntacode
FROM taxi_zone_lookups
WHERE uber_trips_2015.location_id = taxi_zone_lookups.location_id;
