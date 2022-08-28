#!/bin/bash

psql nyc-taxi-data -c "CREATE INDEX ON trips USING BRIN (pickup_datetime) WITH (pages_per_range = 32);"
psql nyc-taxi-data -c "CREATE INDEX ON fhv_trips USING BRIN (pickup_datetime) WITH (pages_per_range = 32);"
