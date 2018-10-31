#!/bin/bash

mkdir -p data/unaltered

mv data/yellow_tripdata_2010-02.csv data/yellow_tripdata_2010-03.csv data/unaltered/

sed -E '/(.*,){18,}/d' data/unaltered/yellow_tripdata_2010-02.csv > data/yellow_tripdata_2010-02.csv
sed -E '/(.*,){18,}/d' data/unaltered/yellow_tripdata_2010-03.csv > data/yellow_tripdata_2010-03.csv
