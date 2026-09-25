#!/bin/bash

# Loads one file from each known TLC parquet schema era into a scratch
# database, then verifies row counts and expected column values. The TLC's
# parquet files have varied over the years (inconsistent column name
# capitalization, missing columns, all-null columns with unhelpful types), so
# each file below represents one distinct schema variant observed in the data.
#
# Looks for each file in data/ and then data/loaded/, since the import scripts
# move files to data/loaded/ once they have been loaded; files that are in
# neither are skipped. Exits non-zero if any check fails, or if no check ran.

parent_path=$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd -P)
cd "$parent_path"

test_db="nyc_tlc_test"
failures=0
skipped=0
checks_run=0

test_files=(
  "load_yellow_trips.sql ../data/yellow_tripdata_2011-01.parquet"  # all-null INT32 congestion_surcharge/airport_fee
  "load_yellow_trips.sql ../data/yellow_tripdata_2018-09.parquet"  # DOUBLE passenger_count/RatecodeID
  "load_yellow_trips.sql ../data/yellow_tripdata_2023-02.parquet"  # Airport_fee with capital A, INT32 VendorID/location IDs
  "load_yellow_trips.sql ../data/yellow_tripdata_2025-01.parquet"  # adds cbd_congestion_fee
  "load_green_trips.sql ../data/green_tripdata_2014-02.parquet"    # all-null INT32 improvement_surcharge, INT32 ehail_fee
  "load_green_trips.sql ../data/green_tripdata_2019-01.parquet"    # DOUBLE ehail_fee/payment_type/trip_type
  "load_green_trips.sql ../data/green_tripdata_2025-01.parquet"    # adds cbd_congestion_fee
  "load_fhv_trips.sql ../data/fhv_tripdata_2015-01.parquet"        # all-null INT32 SR_Flag, DOUBLE location IDs
  "load_fhv_trips.sql ../data/fhv_tripdata_2017-05.parquet"        # DOUBLE SR_Flag with real values
  "load_fhv_trips.sql ../data/fhv_tripdata_2023-02.parquet"        # INT64 SR_Flag/location IDs
  "load_fhvhv_trips.sql ../data/fhvhv_tripdata_2019-02.parquet"    # all-null INT32 wav_match_flag
  "load_fhvhv_trips.sql ../data/fhvhv_tripdata_2023-02.parquet"    # INT32 location IDs
  "load_fhvhv_trips.sql ../data/fhvhv_tripdata_2025-01.parquet"    # adds cbd_congestion_fee
)

# files are moved from data/ to data/loaded/ once imported, so accept either;
# prints the path that exists, or nothing if the file has not been downloaded
resolve_file () {
  local path=$1 dir base
  dir=$(dirname "${path}")
  base=$(basename "${path}")
  if [ -f "${dir}/${base}" ]; then
    echo "${dir}/${base}"
  elif [ -f "${dir}/loaded/${base}" ]; then
    echo "${dir}/loaded/${base}"
  fi
}

check () {
  local description=$1 query=$2
  checks_run=$((checks_run + 1))
  local result=$(clickhouse client --database=${test_db} -q "${query}")
  if [ "${result}" == "1" ]; then
    echo "PASS: ${description}"
  else
    echo "FAIL: ${description}"
    failures=$((failures + 1))
  fi
}

echo "`date`: creating scratch database ${test_db}"
clickhouse client -q "DROP DATABASE IF EXISTS ${test_db}; CREATE DATABASE ${test_db};"
clickhouse client --database=${test_db} --queries-file=setup_files/create_clickhouse_schema.sql
cat setup_files/taxi_zone_location_ids.csv | clickhouse client --database=${test_db} -q "INSERT INTO taxi_zones (location_id, zone, borough, subregion) FORMAT CSV"

for test_file in "${test_files[@]}"; do
  read -r sql filename <<< "${test_file}"

  resolved=$(resolve_file "${filename}")
  if [ -z "${resolved}" ]; then
    echo "SKIP: $(basename "${filename}") not downloaded"
    skipped=$((skipped + 1))
    continue
  fi
  filename=${resolved}

  echo "`date`: loading ${filename}"
  if ! clickhouse client --database=${test_db} --param_filename="${filename}" --queries-file="setup_files/${sql}" < "${filename}"; then
    echo "FAIL: load ${filename}"
    failures=$((failures + 1))
    checks_run=$((checks_run + 1))
    continue
  fi

  base=$(basename "${filename}")
  expected=$(clickhouse local -q "SELECT num_rows FROM file('${filename}', ParquetMetadata)")
  if [[ "${base}" == fhv* ]]; then table="fhv_trips"; else table="taxi_trips"; fi
  check "row count for ${base} matches parquet metadata (${expected})" \
    "SELECT count(*) = ${expected} FROM ${table} WHERE filename = '${base}'"
done

# Column value checks: these catch silent failures that row counts cannot,
# e.g. if case-insensitive column matching broke, Airport_fee would load as
# all NULLs while row counts still matched
value_checks=(
  "yellow 2023-02 Airport_fee matched case-insensitively|../data/yellow_tripdata_2023-02.parquet|SELECT countIf(airport_fee IS NOT NULL) > 0 FROM taxi_trips WHERE filename = 'yellow_tripdata_2023-02.parquet'"
  "yellow 2025-01 cbd_congestion_fee loaded|../data/yellow_tripdata_2025-01.parquet|SELECT countIf(cbd_congestion_fee IS NOT NULL) > 0 FROM taxi_trips WHERE filename = 'yellow_tripdata_2025-01.parquet'"
  "yellow 2023-02 cbd_congestion_fee filled with NULLs|../data/yellow_tripdata_2023-02.parquet|SELECT countIf(cbd_congestion_fee IS NOT NULL) = 0 FROM taxi_trips WHERE filename = 'yellow_tripdata_2023-02.parquet'"
  "green 2025-01 cbd_congestion_fee loaded|../data/green_tripdata_2025-01.parquet|SELECT countIf(cbd_congestion_fee IS NOT NULL) > 0 FROM taxi_trips WHERE filename = 'green_tripdata_2025-01.parquet'"
  "fhv 2017-05 SR_Flag loaded|../data/fhv_tripdata_2017-05.parquet|SELECT countIf(legacy_shared_ride IS NOT NULL) > 0 FROM fhv_trips WHERE filename = 'fhv_tripdata_2017-05.parquet'"
  "fhvhv 2019-02 all-null wav_match_flag loaded as NULLs|../data/fhvhv_tripdata_2019-02.parquet|SELECT countIf(wav_match IS NOT NULL) = 0 FROM fhv_trips WHERE filename = 'fhvhv_tripdata_2019-02.parquet'"
  "fhvhv 2023-02 wav_match loaded|../data/fhvhv_tripdata_2023-02.parquet|SELECT countIf(wav_match IS NOT NULL) > 0 FROM fhv_trips WHERE filename = 'fhvhv_tripdata_2023-02.parquet'"
  "fhvhv 2025-01 cbd_congestion_fee loaded|../data/fhvhv_tripdata_2025-01.parquet|SELECT countIf(cbd_congestion_fee IS NOT NULL) > 0 FROM fhv_trips WHERE filename = 'fhvhv_tripdata_2025-01.parquet'"
  "yellow boroughs populated from taxi_zones|../data/yellow_tripdata_2023-02.parquet|SELECT countIf(pickup_borough IS NOT NULL) > 0 FROM taxi_trips WHERE filename = 'yellow_tripdata_2023-02.parquet'"
  "fhvhv company mapped from license number|../data/fhvhv_tripdata_2023-02.parquet|SELECT countIf(company IN ('uber', 'lyft')) > 0 FROM fhv_trips WHERE filename = 'fhvhv_tripdata_2023-02.parquet'"
)

for value_check in "${value_checks[@]}"; do
  IFS='|' read -r description filename query <<< "${value_check}"
  if [ -z "$(resolve_file "${filename}")" ]; then
    echo "SKIP: ${description} (file not downloaded)"
    skipped=$((skipped + 1))
    continue
  fi
  check "${description}" "${query}"
done

# Reloading the same file must not create duplicate rows
dedup_file=$(resolve_file "../data/green_tripdata_2014-02.parquet")
if [ -n "${dedup_file}" ]; then
  echo "`date`: reloading ${dedup_file} to test dedup"
  clickhouse client --database=${test_db} --param_filename="${dedup_file}" --queries-file=setup_files/load_green_trips.sql < "${dedup_file}"
  expected=$(clickhouse local -q "SELECT num_rows FROM file('${dedup_file}', ParquetMetadata)")
  check "reloading green 2014-02 does not duplicate rows" \
    "SELECT count(*) = ${expected} FROM taxi_trips WHERE filename = 'green_tripdata_2014-02.parquet'"
fi

clickhouse client -q "DROP DATABASE ${test_db};"

echo
if [ ${checks_run} -eq 0 ]; then
  echo "`date`: no checks ran - no test files found in ../data or ../data/loaded (${skipped} skipped)"
  exit 1
elif [ ${failures} -eq 0 ]; then
  echo "`date`: all ${checks_run} checks passed (${skipped} skipped)"
else
  echo "`date`: ${failures} of ${checks_run} check(s) FAILED (${skipped} skipped)"
  exit 1
fi
