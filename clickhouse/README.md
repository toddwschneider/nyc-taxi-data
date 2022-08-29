# ClickHouse Instructions

##### 1. Install [ClickHouse](https://clickhouse.com/)

- [Quick Start documentation](https://clickhouse.com/docs/en/quick-start/)
- [Homebrew Tap](https://altinity.com/blog/altinity-introduces-macos-homebrew-tap-for-clickhouse)

##### 2. Install [R](https://www.r-project.org/)

From [CRAN](https://cloud.r-project.org/)

R is required to fix some of the historical Parquet files that are missing column types

##### 2. Download raw data

From the project root directory, not the `clickhouse/` directory

`./download_raw_data.sh`

##### 3. Fix some Parquet files

Some of the older Parquet files provided by the TLC have a few columns with `null` types, which causes errors when trying to import into ClickHouse. The following script iterates through all of the downloaded files and set types if necessary

`./clickhouse/fix_parquet_files.sh`

##### 4. Initialize database and set up schema

`./clickhouse/initialize_clickhouse_database.sh`

##### 5. Import taxi and FHV data

`./clickhouse/load_fhv_trips.sh`
<br>
`./clickhouse/load_taxi_trips.sh`

## Schema

- `fhv_trips` table contains all for-hire vehicle trip records, including ride-hailing apps Uber, Lyft, Via, and Juno
- `taxi_trips` table contains all yellow and green taxi trips
- `taxi_zones` table maps pickup and dropoff location IDs to neighborhood and borough names
