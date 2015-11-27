# Unified New York City Taxi and Uber data

Code in support of this post: [Analyzing 1.1 Billion NYC Taxi and Uber Trips, with a Vengeance](http://toddwschneider.com/posts/analyzing-1-1-billion-nyc-taxi-and-uber-trips-with-a-vengeance/)

This repo provides scripts to download, process, and analyze data for over 1.1 billion taxi and Uber trips originating in New York City. The data is stored in a [PostgreSQL](http://www.postgresql.org/) database, and uses [PostGIS](http://postgis.net/) for spatial calculations, in particular mapping latitude/longitude coordinates to census tracts.

The [yellow and green taxi data](http://www.nyc.gov/html/tlc/html/about/trip_record_data.shtml) comes from the NYC Taxi & Limousine Commission, and [Uber data](https://github.com/fivethirtyeight/uber-tlc-foil-response) comes via FiveThirtyEight, who obtained it via a FOIL request.

## Instructions

Your mileage may vary, but on my MacBook Air, this process took about 3 days to complete. The unindexed database takes up 267 GB on disk. Adding indexes for improved query performance increases total disk usage to 375 GB.

##### 1. Install [PostgreSQL](http://www.postgresql.org/download/) and [PostGIS](http://postgis.net/install)

Both are available via [Homebrew](http://brew.sh/) on Mac OS X

##### 2. Download raw taxi data

`./download_raw_data.sh`

##### 3. Initialize database and set up schema

`./initialize_database.sh`

##### 4. Import taxi data into database and map to census tracts

`./import_trip_data.sh`

##### 5. Optional: download and import Uber data from FiveThirtyEight's GitHub repository

`./download_raw_uber_data.sh`
<br>
`./import_uber_trip_data.sh`

##### 6. Analysis

Additional Postgres and [R](https://www.r-project.org/) scripts for analysis are in the <code>analysis/</code> folder, or you can do your own!

## Schema

- `trips` table contains all yellow and green taxi trips, plus Uber pickups from April 2014 through September 2014. Each trip has a `cab_type_id`, which references the `cab_types` table and refers to one of `yellow`, `green`, or `uber`. Each trip maps to a census tract for pickup and dropoff
- `nyct2010` table contains NYC census tracts, plus a fake census tract for the Newark Airport. It also maps census tracts to NYC's official neighborhood tabulation areas
- `uber_trips_2015` table contains Uber pickups from January 2015 through June, 2015. These are kept in a separate table because they don't have specific latitude/longitude coordinates, only location IDs. The location IDs are stored in the `uber_taxi_zone_lookups` table, which also maps them (approximately) to neighborhood tabulation areas
- `central_park_weather_observations` has summary weather data by date

## Other data sources

These are bundled with the repository, so no need to download separately, but:

- Shapefile for NYC census tracts and neighborhood tabulation areas comes from [Bytes of the Big Apple](http://www.nyc.gov/html/dcp/html/bytes/districts_download_metadata.shtml)
- Central Park weather data comes from the [National Climatic Data Center](http://www.ncdc.noaa.gov/)

## Data issues encountered

- Remove carriage returns and empty lines from TLC data before passing to Postgres `COPY` command
- `green` taxi raw data files have extra columns with empty data, had to create dummy columns `junk1` and `junk2` to absorb them
- Two of the `yellow` taxi raw data files had a small number of rows containing extra columns. I discarded these rows
- The official NYC neighborhood tabulation areas (NTAs) included in the shapefile are not exactly what I would have expected. Some of them are bizarrely large and contain more than one neighborhood, e.g. "Hudson Yards-Chelsea-Flat Iron-Union Square", while others are confusingly named, e.g. "North Site-South Side" for what I'd call "Williamsburg", and "Williamsburg" for what I'd call "South Williamsburg". In a few instances I modified NTA names, but I kept the NTA geographic definitions
- The shapefile includes only NYC census tracts. Trips to New Jersey, Long Island, Westchester, and Connecticut are not mapped to census tracts, with the exception of the Newark Airport, for which I manually added a fake census tract
- The Uber 2015 data uses location IDs instead of latitude/longitude. The location IDs do not exactly overlap with the NYC neighborhood tabulation areas (NTAs) or census tracts, but I did my best to map Uber location IDs to NYC NTAs

## Why not use BigQuery or Redshift?

[Google BigQuery](https://cloud.google.com/bigquery/) and [Amazon Redshift](https://aws.amazon.com/redshift/) would probably provide significant performance improvements over PostgreSQL. A lot of the data is already available on BigQuery, but in scattered tables, and each trip has only by latitude and longitude coordinates, not census tracts and neighborhoods. PostGIS seemed like the easiest way to map coordinates to census tracts. Once the mapping is complete, it might make sense to load the data back into BigQuery or Redshift to make the analysis faster. Note that BigQuery and Redshift cost some amount of money, while PostgreSQL and PostGIS are free.

## Questions/issues/contact

todd@toddwschneider.com, or open a GitHub issue
