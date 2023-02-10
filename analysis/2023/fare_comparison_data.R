# code to generate json data files used at https://toddwschneider.com/dashboards/nyc-taxi-uber-lyft-fare-and-driver-pay-comparison/?from=161&to=255&since=2019

# assumes full dataset has been loaded into ClickHouse database, see clickhouse/README for more info

library(tidyverse)
library(RClickhouse)

tz = read_csv("../../clickhouse/setup_files/taxi_zone_location_ids.csv", col_names = FALSE) %>%
  setNames(c("location_id", "zone", "borough"))

zone_names = tz$zone
names(zone_names) = as.character(tz$location_id)
zone_names["-1"] = "all"

con = dbConnect(RClickhouse::clickhouse(), dbname = "nyc_tlc_data", host = "localhost")

query = function(sql, conn = con) {
  DBI::dbGetQuery(conn, sql) %>%
    as_tibble()
}

monthly_trip_counts = query("
  SELECT
    company AS car_type,
    pickup_location_id,
    dropoff_location_id,
    date_trunc('month', pickup_datetime) AS month,
    count(*)::int AS trips
  FROM fhv_trips_expanded
  WHERE company IN ('uber', 'lyft')
    AND (
      (pickup_datetime >= '2015-01-01' AND pickup_datetime < '2019-02-01' AND coalesce(legacy_shared_ride, 0) = 0)
      OR (pickup_datetime >= '2019-02-01' AND solo_non_special_request = 1)
    )
  GROUP BY car_type, pickup_location_id, dropoff_location_id, month
  ORDER BY car_type, pickup_location_id, dropoff_location_id, month

  UNION ALL

  SELECT
    'taxi' AS car_type,
    pickup_location_id,
    dropoff_location_id,
    date_trunc('month', pickup_datetime) AS month,
    count(*)::int AS trips
  FROM taxi_trips
  WHERE pickup_datetime >= '2009-01-01'
  GROUP BY car_type, pickup_location_id, dropoff_location_id, month
  ORDER BY car_type, pickup_location_id, dropoff_location_id, month
")

monthly_fare_data = query("
  SELECT
    company AS car_type,
    pickup_location_id,
    dropoff_location_id,
    date_trunc('month', pickup_datetime) AS month,
    count(*)::int AS non_outlier_trips,
    avg(base_passenger_fare + extra_charges + tips) AS mean_cost,
    avg(driver_pay) AS mean_driver_pay,
    avg(base_passenger_fare) AS mean_base_fare,
    avg(tips) AS mean_tip,
    avg(extra_charges) AS mean_extra_charges
  FROM fhv_trips_expanded
  WHERE pickup_datetime >= '2019-02-01'
    AND company IN ('uber', 'lyft')
    AND solo_non_special_request = 1
    AND reasonable_time_distance_fare = 1
  GROUP BY car_type, pickup_location_id, dropoff_location_id, month
  ORDER BY car_type, pickup_location_id, dropoff_location_id, month

  UNION ALL

  SELECT
    'taxi' AS car_type,
    pickup_location_id,
    dropoff_location_id,
    date_trunc('month', pickup_datetime) AS month,
    count(*)::int AS non_outlier_trips,
    /* assume 15% tip for cash fares with 0 tip (payment_type = 2) */
    avg(total_amount * (CASE WHEN payment_type = 2 AND tip_amount = 0 THEN 1.15 ELSE 1 END)) AS mean_cost,
    NULL AS mean_driver_pay,
    avg(fare_amount) AS mean_base_fare,
    avg(CASE WHEN payment_type = 2 AND tip_amount = 0 THEN 0.15 * total_amount ELSE tip_amount END) AS mean_tip,
    avg(total_amount - fare_amount - tip_amount) AS mean_extra_charges
  FROM taxi_trips_expanded
  WHERE pickup_datetime >= '2009-01-01'
    AND reasonable_time_distance_fare = 1
  GROUP BY car_type, pickup_location_id, dropoff_location_id, month
  ORDER BY car_type, pickup_location_id, dropoff_location_id, month
")

monthly_trip_data = monthly_trip_counts %>%
  left_join(
    monthly_fare_data,
    by = c("car_type", "pickup_location_id", "dropoff_location_id", "month")
  ) %>%
  mutate(non_outlier_trips = replace_na(non_outlier_trips, 0))

extra_grouping_vars = list(
  c("car_type", "pickup_location_id", "month"),
  c("car_type", "dropoff_location_id", "month"),
  c("car_type", "month")
)

extra_groupings = purrr::map_dfr(extra_grouping_vars, function(grouping_vars) {
  grouped_data = monthly_trip_data %>%
    group_by(pick({{ grouping_vars }})) %>%
    summarize(
      across(starts_with("mean"), ~ { weighted.mean(., non_outlier_trips, na.rm = TRUE) }),
      trips = sum(trips),
      non_outlier_trips = sum(non_outlier_trips),
      .groups = "drop"
    ) %>%
    mutate(across(starts_with("mean"), ~ { ifelse(is.nan(.), NA, .) }))

  if (!("pickup_location_id" %in% grouping_vars)) {
    grouped_data$pickup_location_id = -1
  }

  if (!("dropoff_location_id" %in% grouping_vars)) {
    grouped_data$dropoff_location_id = -1
  }

  grouped_data
})

max_ridehail_month = extra_groupings %>%
  filter(car_type %in% c("uber", "lyft"), trips >= 10000) %>%
  summarize(month = max(month)) %>%
  pull(month)

max_taxi_month = extra_groupings %>%
  filter(car_type == "taxi", trips >= 10000) %>%
  summarize(month = max(month)) %>%
  pull(month)

ridehail_full_data_months = seq.Date(as.Date("2017-06-01"), max_ridehail_month, "1 month")
uber_limited_data_months = seq.Date(as.Date("2015-01-01"), as.Date("2017-05-01"), "1 month")
lyft_limited_data_months = seq.Date(as.Date("2015-04-01"), as.Date("2017-05-01"), "1 month")
taxi_months = seq.Date(as.Date("2009-01-01"), max_taxi_month, "1 month")

# no pickups at EWR (location id 1)
# exclude Governor's Island (ids 103-105)
# use -1 for "all trips"
pickup_location_ids = c(2:102, 106:263, -1)
dropoff_location_ids = c(1:102, 106:263, -1)

output_data = bind_rows(
  expand_grid(
    car_type = "uber",
    pickup_location_id = pickup_location_ids,
    dropoff_location_id = -1,
    month = uber_limited_data_months
  ),
  expand_grid(
    car_type = "lyft",
    pickup_location_id = pickup_location_ids,
    dropoff_location_id = -1,
    month = lyft_limited_data_months
  ),
  expand_grid(
    car_type = c("uber", "lyft"),
    pickup_location_id = pickup_location_ids,
    dropoff_location_id = dropoff_location_ids,
    month = ridehail_full_data_months
  ),
  expand_grid(
    car_type = "taxi",
    pickup_location_id = pickup_location_ids,
    dropoff_location_id = dropoff_location_ids,
    month = taxi_months
  )
) %>%
  left_join(
    bind_rows(monthly_trip_data, extra_groupings),
    by = c("car_type", "pickup_location_id", "dropoff_location_id", "month")
  ) %>%
  mutate(
    trips = replace_na(trips, 0),
    ts = as.numeric(as.POSIXct(month, "UTC")) * 1000
  )

sorted_car_types = extra_groupings %>%
  distinct(car_type) %>%
  pull(car_type) %>%
  sort()

subdir_name = "fare_comparison_json"
if (!dir.exists(subdir_name)) dir.create(subdir_name)

output_data %>%
  group_by(pickup_location_id, dropoff_location_id) %>%
  group_walk(~ {
    pu = ifelse(.y$pickup_location_id == -1, "all", .y$pickup_location_id)
    do = ifelse(.y$dropoff_location_id == -1, "all", .y$dropoff_location_id)

    filename = paste0(subdir_name, "/", pu, "_", do, ".json")

    data = .x %>%
      group_by(car_type) %>%
      group_map(~ {
        list(
          ts = .x$ts,
          trips = .x$trips,
          non_outlier_trips = .x$non_outlier_trips,
          mean_cost = .x$mean_cost,
          mean_driver_pay = .x$mean_driver_pay,
          mean_base_fare = .x$mean_base_fare,
          mean_tip = .x$mean_tip,
          mean_extra_charges = .x$mean_extra_charges
        )
      }) %>%
      setNames(sorted_car_types)

    data$from = zone_names[as.character(.y$pickup_location_id)]
    data$to = zone_names[as.character(.y$dropoff_location_id)]

    data %>%
      jsonlite::toJSON(auto_unbox = TRUE, na = "null", digits = 2) %>%
      cat(file = filename)
  })
