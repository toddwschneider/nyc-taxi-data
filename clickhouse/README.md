# ClickHouse Instructions

##### 1. Install [ClickHouse](https://clickhouse.com/)

- [Quick Start documentation](https://clickhouse.com/docs/en/quick-start/)
- [Homebrew Tap](https://altinity.com/blog/altinity-introduces-macos-homebrew-tap-for-clickhouse)

##### 2. Install [R](https://www.r-project.org/)

From [CRAN](https://cloud.r-project.org/)

R is required to fix some of the historical Parquet files that are missing column types

##### 3. Download raw data

From the project root directory, not the `clickhouse/` directory

`./download_raw_data.sh`

##### 4. Fix some Parquet files

Some of the older Parquet files provided by the TLC have a few columns with `null` types, which causes errors when trying to import into ClickHouse. The following script iterates through all of the downloaded files and set types if necessary

`./clickhouse/fix_parquet_files.sh`

##### 5. Initialize database and set up schema

`./clickhouse/initialize_clickhouse_database.sh`

##### 6. Import taxi and FHV data

`./clickhouse/load_fhv_trips.sh`
<br>
`./clickhouse/load_taxi_trips.sh`

##### 7. Optional: backfill yellow taxi data from 2009 and 2010

The yellow taxi Parquet files from 2009 and 2010 have columns for lat/lon coordinates instead of location IDs, which makes them incompatible with the ClickHouse `taxi_trips` table schema. As a workaround, there is a Parquet file available from a Requester Pays AWS S3 bucket here:

https://nyc-yellow-taxi-tripdata-backfill.s3.amazonaws.com/backfill_yellow_tripdata_2009_2010.parquet

It contains all yellow taxi trips from 2009 and 2010, including location IDs instead of lat/lon coordinates. [See here](https://docs.aws.amazon.com/AmazonS3/latest/userguide/ObjectsinRequesterPaysBuckets.html) for info on how to download files from Requester Pays S3 buckets. Once you've downloaded the file to the `data/` directory, run:

`./clickhouse/backfill_yellow_taxi_2009_2010_trips.sh`

If you want to reproduce the backfill file on your own instead of downloading from S3, you can:

1. Run the Postgres-based scripts in this repo to load 2009/2010 yellow taxi files, which will map coordinates to location IDs
2. Generate a Parquet file of 2009/2010 trips that conforms to the same schema as the 2011- files
3. Import the Parquet file into ClickHouse using the `backfill_yellow_taxi_2009_2010_trips.sh` script

## Schema

- `fhv_trips` table contains all for-hire vehicle trip records, including ride-hailing apps Uber, Lyft, Via, and Juno
- `taxi_trips` table contains all yellow and green taxi trips
- `taxi_zones` table maps pickup and dropoff location IDs to neighborhood and borough names
