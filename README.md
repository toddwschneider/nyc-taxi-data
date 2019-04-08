# New York City Taxi and For-Hire Vehicle Data

Code originally in support of this post: ["Analyzing 1.1 Billion NYC Taxi and Uber Trips, with a Vengeance"](https://toddwschneider.com/posts/analyzing-1-1-billion-nyc-taxi-and-uber-trips-with-a-vengeance/)

This repo provides scripts to download, process, and analyze data for billions of taxi and for-hire vehicle (Uber, Lyft, etc.) trips originating in New York City since 2009. Most of the [raw data](https://www1.nyc.gov/site/tlc/about/tlc-trip-record-data.page) comes from the NYC Taxi & Limousine Commission.

The data is stored in a [PostgreSQL](https://www.postgresql.org/) database, and uses [PostGIS](https://postgis.net/) for spatial calculations.

Statistics through December 31, 2018:

- 2.26 billion total trips
  - 1.6 billion taxi
  - 655 million for-hire vehicle
- 267 GB of raw data
- Database takes up 366 GB on disk with minimal indexes

## Instructions

##### 1. Install [PostgreSQL](https://www.postgresql.org/download/) and [PostGIS](https://postgis.net/install)

Both are available via [Homebrew](https://brew.sh/) on Mac

##### 2. Download raw data

`./download_raw_data.sh && ./remove_bad_rows.sh`

The `remove_bad_rows.sh` script fixes two particular files that have a few rows with too many columns. See the "data issues" section below for more.

Note that the raw data is hundreds of GB, so it will take a while to download.

##### 3. Initialize database and set up schema

`./initialize_database.sh`

##### 4. Import taxi and FHV data

`./import_trip_data.sh`
<br>
`./import_fhv_trip_data.sh`

The full import process takes ~36 hours on a 2013 MacBook Pro with 16 GB of RAM.

##### 5. Optional: download and import 2014 Uber data

The [FiveThirtyEight Uber dataset](https://github.com/fivethirtyeight/uber-tlc-foil-response) contains Uber trip records from Apr–Sep 2014. Uber and other FHV (Lyft, Juno, Via, etc.) data is available since Jan 2015 in the TLC's data.

`./download_raw_2014_uber_data.sh`
<br>
`./import_2014_uber_trip_data.sh`

##### 6. Analysis

Additional Postgres and [R](https://www.r-project.org/) scripts for analysis are in the `analysis/` folder, or you can do your own!

## Schema

- `trips` table contains all yellow and green taxi trips. Each trip has a `cab_type_id`, which references the `cab_types` table and refers to one of `yellow` or `green`
- `fhv_trips` table contains all for-hire vehicle trip records, including ride-hailing apps Uber, Lyft, Via, and Juno
- `fhv_bases` maps `fhv_trips` to base names and "doing business as" labels, which include ride-hailing app names
- `nyct2010` table contains NYC census tracts plus the Newark Airport. It also maps census tracts to NYC's official neighborhood tabulation areas
- `taxi_zones` table contains the TLC's official taxi zone boundaries. Starting in July 2016, the TLC no longer provides pickup and dropoff coordinates. Instead, each trip comes with taxi zone pickup and dropoff location IDs
- `central_park_weather_observations` has summary weather data by date

## Other data sources

These are bundled with the repository, so no need to download separately, but:

- Shapefile for NYC census tracts and neighborhood tabulation areas comes from [Bytes of the Big Apple](https://www1.nyc.gov/site/planning/data-maps/open-data/districts-download-metadata.page)
- Shapefile for taxi zone locations comes from the TLC
- Mapping of FHV base numbers to names comes from [the TLC](https://data.cityofnewyork.us/Transportation/FHV-Base-Aggregate-Report/2v9c-2k7f)
- Central Park weather data comes from the [National Climatic Data Center](https://www.ncdc.noaa.gov/)

## Data issues encountered

- Remove carriage returns and empty lines from TLC data before passing to Postgres `COPY` command
- Some raw data files have extra columns with empty data, had to create dummy columns `junk1` and `junk2` to absorb them
- Two of the `yellow` taxi raw data files had a small number of rows containing extra columns. I discarded these rows
- The official NYC neighborhood tabulation areas (NTAs) included in the census tracts shapefile are not exactly what I would have expected. Some of them are bizarrely large and contain more than one neighborhood, e.g. "Hudson Yards-Chelsea-Flat Iron-Union Square", while others are confusingly named, e.g. "North Side-South Side" for what I'd call "Williamsburg", and "Williamsburg" for what I'd call "South Williamsburg". In a few instances I modified NTA names, but I kept the NTA geographic definitions
- The shapefile includes only NYC census tracts. Trips to New Jersey, Long Island, Westchester, and Connecticut are not mapped to census tracts, with the exception of the Newark Airport

## Why not use BigQuery or Redshift?

[Google BigQuery](https://cloud.google.com/bigquery/) and [Amazon Redshift](https://aws.amazon.com/redshift/) would probably provide significant performance improvements over PostgreSQL. A lot of the data is already available on BigQuery, but in scattered tables, and each trip has only latitude and longitude coordinates, not census tracts and neighborhoods. PostGIS seemed like the easiest way to map coordinates to census tracts. Once the mapping is complete, it might make sense to load the data back into BigQuery or Redshift to make the analysis faster. Note that BigQuery and Redshift cost some amount of money, while PostgreSQL and PostGIS are free.

Mark Litwintschik has used the taxi dataset to benchmark performance of many different technology stacks, his summary is here: http://tech.marksblogg.com/benchmarks.html

## TLC summary statistics

There's a Ruby script in the `tlc_statistics/` folder to import data from the TLC's [summary statistics reports](https://www1.nyc.gov/site/tlc/about/aggregated-reports.page):

`ruby import_statistics_data.rb`

These summary statistics are used in the [NYC Taxi & Ridehailing Stats](https://toddwschneider.com/dashboards/nyc-taxi-ridehailing-uber-lyft-data/) dashboard

## Taxi vs. Citi Bike comparison

Code in support of the post ["When Are Citi Bikes Faster Than Taxis in New York City?"](https://toddwschneider.com/posts/taxi-vs-citi-bike-nyc/) lives in the `citibike_comparison/` folder

## 2017 update

Code in support of the [2017 update](https://toddwschneider.com/posts/analyzing-1-1-billion-nyc-taxi-and-uber-trips-with-a-vengeance/#update-2017) to the original post lives in the `analysis/2017_update/` folder

## Questions/issues/contact

todd@toddwschneider.com, or open a GitHub issue
