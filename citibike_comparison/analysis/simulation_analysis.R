source("helpers.R")

# 1. Define Monte Carlo simulation, see monte_carlo_simulation.R for more

source("monte_carlo_simulation.R")



# 2. Run various simulations

set.seed(1738)

t1 = as.Date("2016-07-01")
t2 = as.Date("2017-06-30")

simulation_results = run_simulation(
  filters = quos(date >= t1, date <= t2),
  dimensions = c("end_taxi_zone_id", "time_bucket")
)
write_csv(simulation_results, "simulation_results/simulation_results.csv")

hourly_simulation_results = run_simulation(
  filters = quos(date >= t1, date <= t2),
  dimensions = c("end_taxi_zone_id", "hour_of_day")
)
write_csv(hourly_simulation_results_min5, "simulation_results/hourly_simulation_results.csv")

same_date_simulation_results = run_simulation(
  filters = quos(date >= t1, date <= t2),
  dimensions = c("end_taxi_zone_id", "time_bucket", "date")
)
write_csv(same_date_simulation_results, "simulation_results/same_date_simulation_results.csv")

monthly_simulation_results = run_simulation(
  filters = quos(hour_of_day %in% 8:18),
  dimensions = c("end_taxi_zone_id", "time_bucket", "month")
)
write_csv(monthly_simulation_results, "simulation_results/monthly_simulation_results.csv")

dates_with_precipitation = query("
  SELECT date
  FROM central_park_weather_observations
  WHERE precipitation >= 0.1
  ORDER BY date
")$date

precip_simulation_results = run_simulation(
  filters = quos(date >= t1, date <= t2, date %in% dates_with_precipitation),
  dimensions = c("end_taxi_zone_id", "time_bucket")
)
write_csv(precip_simulation_results, "simulation_results/precip_simulation_results.csv")



# 3. Analyze simulation results

png("graphs/hourly_taxi_win_rate.png", width = 640, height = 640)
hourly_simulation_results %>%
  group_by(hour_of_day) %>%
  summarize(
    wtd_taxi_win_rate = sum(taxi_trips * taxi_win_rate) / sum(taxi_trips),
    wtd_citi_win_rate = 1 - wtd_taxi_win_rate
  ) %>%
  ungroup() %>%
  ggplot(aes(x = hour_of_day, y = wtd_citi_win_rate)) +
  geom_bar(stat = "identity", fill = citi_hex) +
  scale_y_continuous(labels = percent, breaks = c(0, 0.25, 0.5)) +
  scale_x_continuous(breaks = c(0, 6, 12, 18), labels = c("12 AM", "6 AM", "12 PM", "6 PM")) +
  ggtitle(
    "When Citi Bikes are faster than taxis",
    "% of taxi trips taken weekdays within Citi Bike service area\nexpected to be faster if switched to Citi Bike"
  ) +
  labs(caption = "Data via NYC TLC and Citi Bike\ntoddwschneider.com") +
  theme_tws(base_size = 28) +
  no_axis_titles()
dev.off()

avg_trip_distances = query("SELECT * FROM avg_trip_distances")

png("graphs/win_rate_by_distance.png", width = 640, height = 640)
simulation_results %>%
  filter(time_bucket %in% c("morning", "midday", "afternoon")) %>%
  inner_join(avg_trip_distances, by = c("start_taxi_zone_id", "end_taxi_zone_id")) %>%
  mutate(distance_bucket = floor(avg_distance / 0.25) * 0.25 + 0.125) %>%
  group_by(distance_bucket) %>%
  summarize(
    twr = sum(taxi_trips * taxi_win_rate) / sum(taxi_trips),
    citi_total = sum(citi_trips)
  ) %>%
  ungroup() %>%
  filter(citi_total >= 10000) %>%
  ggplot(aes(x = distance_bucket, y = 1 - twr)) +
  geom_line(size = 1.5, color = citi_hex) +
  scale_x_continuous("Trip distance in miles") +
  scale_y_continuous(labels = percent) +
  ggtitle(
    "Citi Bikes vs. taxis by trip distance",
    "% of taxi trips taken within Citi Bike service area, weekdays\n8 AM–7 PM, expected to be faster if switched to Citi Bike"
  ) +
  labs(caption = "Data via NYC TLC and Citi Bike\ntoddwschneider.com") +
  expand_limits(y = c(0.2, 0.8), x = 0) +
  theme_tws(base_size = 28) +
  theme(axis.title.y = element_blank())
dev.off()

png("graphs/hourly_win_rate_by_route.png", width = 640, height = 640)
hourly_simulation_results %>%
  mutate(
    trip_type = case_when(
      start_borough == "Manhattan" & end_borough == "Manhattan" ~ "Within Manhattan",
      start_borough != "Manhattan" & end_borough == "Manhattan" ~ "Outer boroughs to Manhattan",
      start_borough == "Manhattan" & end_borough != "Manhattan" ~ "Manhattan to outer boroughs",
      start_borough != "Manhattan" & end_borough != "Manhattan" ~ "Within outer boroughs"
    ) %>% factor(levels = c("Within Manhattan", "Manhattan to outer boroughs", "Outer boroughs to Manhattan", "Within outer boroughs"))
  ) %>%
  group_by(trip_type, hour_of_day) %>%
  summarize(twr = sum(taxi_win_rate * taxi_trips) / sum(taxi_trips)) %>%
  ungroup() %>%
  ggplot(aes(x = hour_of_day, y = 1 - twr)) +
  geom_bar(stat = "identity", fill = citi_hex) +
  scale_y_continuous(labels = percent, breaks = c(0, 0.25, 0.5)) +
  scale_x_continuous(breaks = c(0, 6, 12, 18), labels = c("12 AM", "6 AM", "12 PM", "6 PM")) +
  expand_limits(y = c(0, 0.65)) +
  ggtitle(
    "When Citi Bikes are faster than taxis, by route",
    "% of taxi trips taken weekdays within Citi Bike service area\nexpected to be faster if switched to Citi Bike"
  ) +
  labs(caption = "Data via NYC TLC and Citi Bike\ntoddwschneider.com") +
  facet_wrap(~trip_type, ncol = 2, scales = "free_x") +
  theme_tws(base_size = 24) +
  no_axis_titles() +
  theme(axis.text.x = element_text(size = rel(0.7)))
dev.off()

citi_bike_first_expansion_date = as.Date("2015-08-01")
original_citi_bike_zones = monthly_simulation_results %>%
  filter(month < citi_bike_first_expansion_date) %>%
  pull(start_taxi_zone_id) %>%
  unique() %>%
  sort()

png("graphs/taxi_vs_citibike_by_month.png", width = 640, height = 640)
monthly_simulation_results %>%
  filter(
    start_taxi_zone_id %in% original_citi_bike_zones,
    end_taxi_zone_id %in% original_citi_bike_zones,
    time_bucket %in% c("morning", "midday", "afternoon"),
  ) %>%
  group_by(month) %>%
  summarize(twr = sum(taxi_win_rate * taxi_trips) / sum(taxi_trips)) %>%
  ungroup() %>%
  ggplot(aes(x = month, y = 1 - twr)) +
  geom_line(size = 1.5, color = citi_hex) +
  scale_y_continuous(labels = percent) +
  scale_x_date() +
  ggtitle(
    "Taxis are losing to Citi Bikes over time",
    "% of weekday 8 AM–7 PM taxi trips within pre-expansion Citi Bike\nservice area expected to be faster if switched to Citi Bike"
  ) +
  labs(caption = "Data via NYC TLC and Citi Bike\ntoddwschneider.com") +
  expand_limits(y = c(0.4, 0.6)) +
  theme_tws(base_size = 28) +
  theme(plot.subtitle = element_text(size = rel(0.6))) +
  no_axis_titles()
dev.off()

png("graphs/weekday_taxi_loss_rate_histogram.png", width = 640, height = 640)
same_date_simulation_results %>%
  filter(time_bucket == "afternoon") %>%
  filter(date >= as.Date("2016-07-01")) %>%
  group_by(date) %>%
  summarize(twr = sum(taxi_win_rate * taxi_trips)/sum(taxi_trips)) %>%
  ungroup() %>%
  ggplot(aes(x = 1 - twr)) +
  geom_histogram(binwidth = 0.02) +
  scale_y_continuous("Number of days", labels = comma) +
  scale_x_continuous("Taxi loss rate", labels = percent) +
  ggtitle(
    "Taxi loss rate distribution",
    "Weekdays 4:00 PM–7:00 PM, Jul 2016–Jun 2017"
  ) +
  labs(caption = "Data via NYC TLC and Citi Bike\ntoddwschneider.com") +
  theme_tws(base_size = 28)
dev.off()

png("graphs/union_sq_murray_hill_afternoon_medians.png", width = 640, height = 640)
same_date_simulation_results %>%
  filter(time_bucket == "afternoon", start_zone == "Union Sq", end_zone == "Murray Hill") %>%
  select(date, taxi_median, citi_median) %>%
  gather(variable, value, -date) %>%
  mutate(variable = factor(variable, levels = c("taxi_median", "citi_median"), labels = c("Taxi", "Citi Bike"))) %>%
  ggplot(aes(x = date, y = value / 60, color = variable)) +
  geom_vline(xintercept = as.Date(c("2016-06-08", "2016-09-19")), linetype = "dashed", alpha = 0.8, color = "#666666") +
  geom_point(size = 2.5) +
  scale_y_continuous() +
  scale_color_manual(values = c(taxi_hex, citi_hex), guide = FALSE) +
  expand_limits(y = c(0, 22)) +
  facet_wrap(~variable, ncol = 1) +
  ggtitle(
    "Union Square to Murray Hill",
    "Median travel time in minutes, weekdays 4:00 PM–7:00 PM"
  ) +
  labs(caption = "Data via NYC TLC and Citi Bike\ntoddwschneider.com") +
  theme_tws(base_size = 28) +
  no_axis_titles() +
  theme(
    axis.text.x = element_text(size = rel(0.8)),
    panel.grid.minor.y = element_blank()
  )
dev.off()

png("graphs/uws_west_chelsea_morning_medians.png", width = 640, height = 640)
same_date_simulation_results %>%
  filter(time_bucket == "morning", start_zone == "Upper West Side South", end_zone == "West Chelsea/Hudson Yards") %>%
  select(date, taxi_median, citi_median) %>%
  gather(variable, value, -date) %>%
  mutate(variable = factor(variable, levels = c("taxi_median", "citi_median"), labels = c("Taxi", "Citi Bike"))) %>%
  ggplot(aes(x = date, y = value / 60, color = variable)) +
  geom_vline(xintercept = as.Date("2016-06-15"), linetype = "dashed", alpha = 0.8, color = "#666666") +
  geom_point(size = 2.5) +
  scale_y_continuous() +
  scale_color_manual(values = c(taxi_hex, citi_hex), guide = FALSE) +
  expand_limits(y = c(0, 40)) +
  facet_wrap(~variable, ncol = 1) +
  ggtitle(
    "Upper West Side to West Chelsea/Hudson Yards",
    "Median travel time in minutes, weekdays 8:00 AM–11:00 AM"
  ) +
  labs(caption = "Data via NYC TLC and Citi Bike\ntoddwschneider.com") +
  theme_tws(base_size = 28) +
  no_axis_titles() +
  theme(
    plot.title = element_text(size = rel(1.1)),
    axis.text.x = element_text(size = rel(0.8)),
    panel.grid.minor.y = element_blank()
  )
dev.off()

same_date_simulation_results %>%
  filter(time_bucket %in% c("morning", "midday", "afternoon")) %>%
  group_by(start_zone, end_zone, time_bucket) %>%
  summarize(
    count = n(),
    taxi_total = sum(taxi_trips),
    citi_total = sum(citi_trips),
    median_taxi_median = median(taxi_median),
    median_citi_median = median(citi_median)
  ) %>%
  ungroup() %>%
  inner_join(same_date_simulation_results) %>%
  summarize(
    taxi_slow = sum(taxi_median - median_taxi_median >= 300),
    citi_slow = sum(citi_median - median_citi_median >= 300),
    taxi_very_slow = sum(taxi_median - median_taxi_median >= 600),
    citi_very_slow = sum(citi_median - median_citi_median >= 600),
    slow_ratio = taxi_slow / citi_slow,
    very_slow_ratio = taxi_very_slow / citi_very_slow
  )

# define Manhattan uptown and crosstown regions based on similar latitude/longitude,
# after adjusting for Manhattan's 29 degree rotation from true north
uptown_buckets = query("
  SELECT
    z.gid,
    z.zone,
    CASE
      WHEN rotated_x < 991000 THEN 0
      WHEN rotated_x < 994100 THEN 1
      WHEN rotated_x < 996000 THEN 2
      ELSE 3
    END AS bucket,
    r.rotated_x,
    r.rotated_y
  FROM rotated_taxi_zones r, taxi_zones z
  WHERE r.gid = z.gid
    AND z.borough = 'Manhattan'
  ORDER BY bucket, r.rotated_y
")

crosstown_buckets = query("
  SELECT
    z.gid,
    z.zone,
    CASE
      WHEN rotated_y < 200000 THEN 0
      WHEN rotated_y < 202500 THEN 1
      WHEN rotated_y < 206500 THEN 2
      WHEN rotated_y < 212000 THEN 3
      WHEN rotated_y < 217000 THEN 4
      WHEN rotated_y < 222000 THEN 5
      WHEN rotated_y < 226500 THEN 6
      ELSE 7
    END AS bucket,
    r.rotated_x,
    r.rotated_y
  FROM rotated_taxi_zones r, taxi_zones z
  WHERE r.gid = z.gid
    AND z.borough = 'Manhattan'
    AND z.zone != 'Central Park'
  ORDER BY bucket, r.rotated_y
")

crosstown_bucket_labels = c(
  "Below Canal",
  "Canal–Houston",
  "Houston–14th",
  "14th–42nd",
  "42nd–59th",
  "59th–77th",
  "77th–96th",
  "96th–110th"
)

xtown = map(unique(crosstown_buckets$bucket), function(b) {
  bucket_zone_ids = filter(crosstown_buckets, bucket == b)$gid

  hourly_simulation_results %>%
    filter(start_taxi_zone_id %in% bucket_zone_ids, end_taxi_zone_id %in% bucket_zone_ids) %>%
    group_by(hour_of_day) %>%
    summarize(
      taxi_win_rate = sum(taxi_trips * taxi_win_rate) / sum(taxi_trips),
      taxi_trips = sum(taxi_trips),
      citi_trips = sum(citi_trips)
    ) %>%
    ungroup() %>%
    mutate(crosstown_bucket = b)
}) %>%
  bind_rows() %>%
  mutate(crosstown_bucket = factor(crosstown_bucket, levels = 7:0, labels = rev(crosstown_bucket_labels)))

xtown %>%
  filter(hour_of_day %in% 8:18) %>%
  group_by(crosstown_bucket) %>%
  summarize(
    taxi_loss_rate = 1 - sum(taxi_win_rate * taxi_trips) / sum(taxi_trips),
    taxi_trips_total = sum(taxi_trips),
    citi_trips_total = sum(citi_trips)
  ) %>%
  ungroup()

xtown_summary = xtown %>%
  group_by(hour_of_day) %>%
  summarize(
    taxi_win_rate = sum(taxi_trips * taxi_win_rate) / sum(taxi_trips),
    taxi_trips = sum(taxi_trips),
    citi_trips = sum(citi_trips)
  ) %>%
  ungroup()

png("graphs/hourly_results_by_xtown_bucket.png", width = 640, height = 1280)
ggplot(xtown, aes(x = hour_of_day, y = 1 - taxi_win_rate)) +
  geom_bar(stat = "identity", fill = citi_hex) +
  scale_y_continuous(labels = percent, breaks = (0:3) / 4) +
  scale_x_continuous(breaks = c(0, 6, 12, 18), labels = c("12 AM", "6 AM", "12 PM", "6 PM")) +
  ggtitle(
    "Citi Bikes vs. taxis by Manhattan region",
    "% of weekday taxi trips that start and end within same Manhattan\nregion expected to be faster if switched to Citi Bike"
  ) +
  labs(caption = "Data via NYC TLC and Citi Bike\ntoddwschneider.com") +
  facet_wrap(~crosstown_bucket, ncol = 2, scales = "free_x") +
  expand_limits(y = c(0, 0.8)) +
  theme_tws(base_size = 26) +
  theme(axis.text.x = element_text(size = rel(0.7))) +
  no_axis_titles()
dev.off()

png("graphs/hourly_results_by_xtown_42_59.png", width = 640, height = 640)
filter(xtown, crosstown_bucket == "42nd–59th") %>%
  ggplot(aes(x = hour_of_day, y = 1 - taxi_win_rate)) +
  geom_bar(stat = "identity", fill = citi_hex) +
  scale_y_continuous(labels = percent, breaks = (0:3) / 4) +
  scale_x_continuous(breaks = (0:3) * 6, labels = c("12 AM", "6 AM", "12 PM", "6 PM")) +
  ggtitle(
    "Citi Bikes vs. taxis, 42nd–59th streets",
    "% of weekday taxi trips that start and end between 42nd and 59th\nstreets expected to be faster if switched to Citi Bike"
  ) +
  labs(caption = "Data via NYC TLC and Citi Bike\ntoddwschneider.com") +
  expand_limits(y = c(0, 0.8)) +
  theme_tws(base_size = 26) +
  no_axis_titles()
dev.off()

uptown = map(unique(uptown_buckets$bucket), function(b) {
  bucket_zone_ids = filter(uptown_buckets, bucket == b)$gid

  hourly_simulation_results %>%
    filter(start_taxi_zone_id %in% bucket_zone_ids, end_taxi_zone_id %in% bucket_zone_ids) %>%
    group_by(hour_of_day) %>%
    summarize(
      taxi_win_rate = sum(taxi_trips * taxi_win_rate) / sum(taxi_trips),
      taxi_trips = sum(taxi_trips),
      citi_trips = sum(citi_trips)
    ) %>%
    ungroup() %>%
    mutate(uptown_bucket = b)
}) %>% bind_rows()

uptown %>%
  filter(hour_of_day %in% 8:18) %>%
  group_by(uptown_bucket) %>%
  summarize(taxi_loss_rate = 1 - sum(taxi_win_rate * taxi_trips) / sum(taxi_trips)) %>%
  ungroup()

uptown_summary = uptown %>%
  group_by(hour_of_day) %>%
  summarize(
    taxi_win_rate = sum(taxi_trips * taxi_win_rate) / sum(taxi_trips),
    taxi_trips = sum(taxi_trips),
    citi_trips = sum(citi_trips)
  ) %>%
  ungroup()
