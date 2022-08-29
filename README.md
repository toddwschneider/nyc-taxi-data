# New York City Taxi and For-Hire Vehicle Data

Scripts to download, process, and analyze data from 3+ billion taxi and for-hire vehicle (Uber, Lyft, etc.) trips originating in New York City since 2009. There are separate sets of scripts for storing data in either a [PostgreSQL](https://www.postgresql.org/) or [ClickHouse](https://clickhouse.com/) database.

Most of the [raw data](https://www1.nyc.gov/site/tlc/about/tlc-trip-record-data.page) comes from the NYC Taxi & Limousine Commission.

The repo was created originally in support of this post: [Analyzing 1.1 Billion NYC Taxi and Uber Trips, with a Vengeance](https://toddwschneider.com/posts/analyzing-1-1-billion-nyc-taxi-and-uber-trips-with-a-vengeance/)

## TLC 2022 Parquet Format Update

The TLC changed the raw data format from CSV to Apache Parquet in May 2022, including a full replacement of all historical files. This repo is now updated to handle the Parquet files in one of two ways:

1. The "old" Postgres-based code still works, by adding an intermediate step that converts each Parquet file into a CSV before using the Postgres `COPY` command
2. A [separate set of scripts](https://github.com/toddwschneider/nyc-taxi-data/tree/master/clickhouse) loads the Parquet files directly into a ClickHouse database

As part of the May 2022 update, the TLC added several new columns to the High Volume For-Hire Vehicle (Uber, Lyft) trip files, including information about passenger fares, driver pay, and time spent waiting for passengers. These new fields are available back to February 2019.

This repo no longer works with the old CSV files provided by the TLC. Those files are no longer available to download from the TLC's website, but if you happen to have them lying around and want to use this repo, you should look at [this older verion of the code](https://github.com/toddwschneider/nyc-taxi-data/tree/2e805ab0f1bf362f890c6b6f227526c575f73b67) from before the Parquet file format change.

## ClickHouse Instructions

See the [`clickhouse`](https://github.com/toddwschneider/nyc-taxi-data/tree/master/clickhouse) directory

## PostgreSQL Instructions

##### 1. Install [PostgreSQL](https://www.postgresql.org/download/) and [PostGIS](https://postgis.net/install)

Both are available via [Homebrew](https://brew.sh/) on Mac

##### 2. Install [R](https://www.r-project.org/)

From [CRAN](https://cloud.r-project.org/)

Note that R used to be optional for this repo, but is required starting with the 2022 file format change. The scripts use R to convert Parquet files to CSV before loading into Postgres. There are other ways to convert from Parquet to CSV that wouldn't require R, but I found that R's `arrow` package was faster than some of the other CLI tools I tried

##### 3. Download raw data

`./download_raw_data.sh`

##### 4. Initialize database and set up schema

`./initialize_database.sh`

##### 5. Import taxi and FHV data

`./import_yellow_taxi_trip_data.sh`
<br>
`./import_green_taxi_trip_data.sh`
<br>
`./import_fhv_taxi_trip_data.sh`
<br>
`./import_fhvhv_trip_data.sh`

Note that the full import process might take several hours or possibly even over a day depending on computing power

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
- Central Park weather data comes from the [National Climatic Data Center](https://www.ncdc.noaa.gov/cdo-web/datasets/GHCND/stations/GHCND:USW00094728/detail)

## See Also

Mark Litwintschik has used the taxi dataset to benchmark performance of many different technology stacks, including PostgreSQL and ClickHouse. His summary is here: http://tech.marksblogg.com/benchmarks.html

## TLC summary statistics

There's a Ruby script in the `tlc_statistics/` folder to import data from the TLC's [summary statistics reports](https://www1.nyc.gov/site/tlc/about/aggregated-reports.page):

`ruby import_statistics_data.rb`

These summary statistics are used in the [NYC Taxi & Ridehailing Stats](https://toddwschneider.com/dashboards/nyc-taxi-ridehailing-uber-lyft-data/) dashboard

## Taxi vs. Citi Bike comparison

Code in support of the post [When Are Citi Bikes Faster Than Taxis in New York City?](https://toddwschneider.com/posts/taxi-vs-citi-bike-nyc/) lives in the `citibike_comparison/` folder

## 2017 update

Code in support of the [2017 update](https://toddwschneider.com/posts/analyzing-1-1-billion-nyc-taxi-and-uber-trips-with-a-vengeance/#update-2017) to the original post lives in the `analysis/2017_update/` folder

## Questions/issues/contact

todd@toddwschneider.com, or open a GitHub issue
