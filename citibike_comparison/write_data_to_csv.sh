#!/bin/bash
psql nyc-taxi-data -f setup_scripts/write_data_to_csv.sql -v PWD=$(pwd)
