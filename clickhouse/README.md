# ClickHouse Instructions

##### 1. Install [ClickHouse](https://clickhouse.com/)

- [Quick Start documentation](https://clickhouse.com/docs/en/quick-start/)

The scripts in this folder assume a single `clickhouse` binary installation, invoked as `clickhouse client`, with a server running locally (e.g. via `clickhouse server`)

##### 2. Download raw data

From the project root directory, not the `clickhouse/` directory

`./download_raw_data.sh`

##### 3. Initialize database and set up schema

`./clickhouse/initialize_clickhouse_database.sh`

##### 4. Import taxi and FHV data

`./clickhouse/load_fhv_trips.sh`
<br>
`./clickhouse/load_taxi_trips.sh`

The load scripts stream the Parquet files from the `data/` directory through `clickhouse client`, so the files do not need to be copied into the ClickHouse server's `user_files` directory. Some of the older Parquet files provided by the TLC have inconsistent schemas: columns with `null` types, missing columns, and inconsistent column name capitalization. The load queries handle these by providing explicit schemas to the [`input()`](https://clickhouse.com/docs/en/sql-reference/table-functions/input) table function, along with the `input_format_parquet_case_insensitive_column_matching` and `input_format_parquet_allow_missing_columns` settings

##### 5. Optional: backfill yellow taxi data from 2009 and 2010

The yellow taxi Parquet files from 2009 and 2010 have columns for lat/lon coordinates instead of location IDs, which makes them incompatible with the ClickHouse `taxi_trips` table schema. As a workaround, there is a Parquet file available from a Requester Pays AWS S3 bucket here:

https://nyc-yellow-taxi-tripdata-backfill.s3.amazonaws.com/backfill_yellow_tripdata_2009_2010.parquet

It contains all yellow taxi trips from 2009 and 2010, including location IDs instead of lat/lon coordinates. [See here](https://docs.aws.amazon.com/AmazonS3/latest/userguide/ObjectsinRequesterPaysBuckets.html) for info on how to download files from Requester Pays S3 buckets. Once you've downloaded the file to the `data/` directory, run:

`./clickhouse/backfill_yellow_taxi_2009_2010_trips.sh`

If you want to reproduce the backfill file on your own instead of downloading from S3, you can:

1. Run the Postgres-based scripts in this repo to load 2009/2010 yellow taxi files, which will map coordinates to location IDs
2. Generate a Parquet file of 2009/2010 trips that conforms to the same schema as the 2011- files
3. Import the Parquet file into ClickHouse using the `backfill_yellow_taxi_2009_2010_trips.sh` script

## Testing

`./clickhouse/test_load_trips.sh` loads one file from each known TLC parquet schema variant (inconsistent column name capitalization, missing columns, all-null columns) into a scratch database, verifies row counts against the parquet file metadata along with expected column values, then drops the scratch database. Useful after changing the load queries or table schemas, or when adding a newly observed schema variant to the list. Requires the relevant files to be present in the `data/` directory; files that have not been downloaded are skipped

## Schema

- `fhv_trips` table contains all for-hire vehicle trip records, including ride-hailing apps Uber, Lyft, Via, and Juno
- `taxi_trips` table contains all yellow and green taxi trips
- `taxi_zones` table maps pickup and dropoff location IDs to neighborhood and borough names
