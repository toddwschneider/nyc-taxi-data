source("helpers.R")

taxi_traffic = query("
  SELECT
    t.pickup_location_id,
    t.dropoff_location_id,
    t.month,
    t.weekday,
    t.date_with_precipitation,
    t.time_bucket,
    t.avg_duration,
    t.avg_distance,
    t.avg_mph,
    t.trips,
    p.zone AS pickup_zone,
    p.borough AS pickup_borough,
    d.zone AS dropoff_zone,
    d.borough AS dropoff_borough
  FROM monthly_taxi_travel_times t
    INNER JOIN taxi_zones p ON t.pickup_location_id = p.locationid
    INNER JOIN taxi_zones d ON t.dropoff_location_id = d.locationid
  WHERE t.weekday = true
  ORDER BY t.pickup_location_id, t.dropoff_location_id, t.month, t.weekday, t.date_with_precipitation, t.time_bucket
")

taxi_traffic = taxi_traffic %>%
  mutate(
    year_factor = factor(year(month)),
    month_of_year_factor = factor(month(month)),
    time_bucket = factor(time_bucket, levels = c("morning", "midday", "afternoon", "evening", "other")),
    route_type = factor(
      case_when(
        pickup_borough == "Manhattan" & dropoff_borough == "Manhattan" ~ "within_manhattan",
        pickup_borough == "Manhattan" & dropoff_borough != "Manhattan" ~ "manhattan_to_outer_boroughs",
        pickup_borough != "Manhattan" & dropoff_borough == "Manhattan" ~ "outer_boroughs_to_manhattan",
        TRUE ~ "within_outer_boroughs",
      )
    )
  )

taxi_traffic_regression = lm(
  log(avg_duration) ~ sqrt(avg_distance) + time_bucket + date_with_precipitation + route_type + year_factor + month_of_year_factor,
  data = taxi_traffic,
  weights = trips
)

summary(taxi_traffic_regression)

# Call:
# lm(formula = log(avg_duration) ~ sqrt(avg_distance) + time_bucket +
#     date_with_precipitation + route_type + year_factor + month_of_year_factor,
#     data = taxi_traffic, weights = trips)
#
# Weighted Residuals:
#     Min      1Q  Median      3Q     Max
# -54.765  -0.421   0.087   0.636  37.479
#
# Coefficients:
#                                         Estimate Std. Error   t value Pr(>|t|)
# (Intercept)                            5.3139081  0.0005460  9732.343   <2e-16 ***
# sqrt(avg_distance)                     0.7254193  0.0001296  5597.749   <2e-16 ***
# time_bucketmidday                      0.0170821  0.0002127    80.303   <2e-16 ***
# time_bucketafternoon                  -0.0233701  0.0002349   -99.486   <2e-16 ***
# time_bucketevening                    -0.1757805  0.0002243  -783.655   <2e-16 ***
# time_bucketother                      -0.3111840  0.0002112 -1473.366   <2e-16 ***
# date_with_precipitationTRUE            0.0133688  0.0001608    83.146   <2e-16 ***
# route_typeouter_boroughs_to_manhattan -0.1279685  0.0004184  -305.861   <2e-16 ***
# route_typewithin_manhattan             0.1272590  0.0003219   395.327   <2e-16 ***
# route_typewithin_outer_boroughs       -0.0726629  0.0003970  -183.041   <2e-16 ***
# year_factor2010                        0.0005849  0.0002676     2.186   0.0288 *
# year_factor2011                        0.0295602  0.0002639   111.994   <2e-16 ***
# year_factor2012                        0.0198924  0.0002639    75.391   <2e-16 ***
# year_factor2013                        0.0380196  0.0002649   143.522   <2e-16 ***
# year_factor2014                        0.0907963  0.0002637   344.361   <2e-16 ***
# year_factor2015                        0.1332881  0.0002704   492.954   <2e-16 ***
# year_factor2016                        0.1499675  0.0002779   539.648   <2e-16 ***
# year_factor2017                        0.1579645  0.0003636   434.393   <2e-16 ***
# month_of_year_factor2                  0.0227648  0.0003236    70.350   <2e-16 ***
# month_of_year_factor3                  0.0182895  0.0003120    58.617   <2e-16 ***
# month_of_year_factor4                  0.0369282  0.0003123   118.263   <2e-16 ***
# month_of_year_factor5                  0.0740635  0.0003139   235.924   <2e-16 ***
# month_of_year_factor6                  0.0688822  0.0003139   219.464   <2e-16 ***
# month_of_year_factor7                  0.0490718  0.0003272   149.965   <2e-16 ***
# month_of_year_factor8                  0.0250940  0.0003294    76.183   <2e-16 ***
# month_of_year_factor9                  0.0904237  0.0003282   275.531   <2e-16 ***
# month_of_year_factor10                 0.0831078  0.0003257   255.204   <2e-16 ***
# month_of_year_factor11                 0.0903942  0.0003384   267.111   <2e-16 ***
# month_of_year_factor12                 0.0893086  0.0003268   273.244   <2e-16 ***
# ---
# Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1
#
# Residual standard error: 2.011 on 13933522 degrees of freedom
# Multiple R-squared:  0.7945,  Adjusted R-squared:  0.7945
# F-statistic: 1.924e+06 on 28 and 13933522 DF,  p-value: < 2.2e-16

taxi_traffic_coefs = tidy(taxi_traffic_regression) %>%
  mutate(exp_estimate = exp(estimate)) %>%
  as_data_frame()

png("graphs/taxi_traffic_multipliers_by_year.png", width = 640, height = 640)
filter(taxi_traffic_coefs, grepl("^year_factor", term, perl = TRUE)) %>%
  mutate(year = as.numeric(sub("year_factor", "", term))) %>%
  select(year, exp_estimate) %>%
  bind_rows(data_frame(year = 2009, exp_estimate = 1)) %>%
  arrange(year) %>%
  ggplot(aes(x = year, y = exp_estimate)) +
  geom_line(size = 1, color = taxi_hex) +
  geom_point(size = 5, color = taxi_hex) +
  scale_y_continuous(labels = function(x) { paste0(x, "x") }, breaks = c(1, 1.1, 1.2)) +
  scale_x_continuous(breaks = seq(2009, 2017, by = 2)) +
  ggtitle(
    "NYC taxis have gotten slower since 2009",
    "Based on model that takes into account trip distance,\nseasonality, weather, and time of day\n\nTaxi trip time multiplier, scaled to 2009 = 1"
  ) +
  labs(caption = "Data via NYC TLC\ntoddwschneider.com") +
  expand_limits(y = c(1, 1.2)) +
  theme_tws(base_size = 28) +
  no_axis_titles()
dev.off()

png("graphs/taxi_traffic_multipliers_by_month.png", width = 640, height = 400)
filter(taxi_traffic_coefs, grepl("^month_of_year_factor", term, perl = TRUE)) %>%
  mutate(month = as.numeric(sub("month_of_year_factor", "", term))) %>%
  select(month, exp_estimate) %>%
  bind_rows(data_frame(month = 1, exp_estimate = 1)) %>%
  arrange(month) %>%
  mutate(month = factor(month, levels = 1:12, labels = month.abb)) %>%
  ggplot(aes(x = month, y = exp_estimate)) +
  geom_point(color = taxi_hex, size = 5) +
  geom_segment(aes(xend = month, yend = 1), color = taxi_hex, size = 1) +
  scale_y_continuous(labels = function(x) { paste0(x, "x") }, breaks = c(1, 1.05, 1.1, 1.15)) +
  ggtitle(
    "Taxi trip time multipliers by month",
    "Scaled to Jan = 1"
  ) +
  labs(caption = "Data via NYC TLC\ntoddwschneider.com") +
  expand_limits(y = c(1, 1.1)) +
  theme_tws(base_size = 28) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(size = rel(0.8))
  ) +
  no_axis_titles()
dev.off()

citi_traffic = query("
  SELECT
    t.*,
    p.zone AS pickup_zone,
    p.borough AS pickup_borough,
    d.zone AS dropoff_zone,
    d.borough AS dropoff_borough
  FROM monthly_citibike_travel_times t
    INNER JOIN taxi_zones p ON t.start_location_id = p.locationid
    INNER JOIN taxi_zones d ON t.end_location_id = d.locationid
  WHERE t.weekday = true
", con = citi_con)

avg_trip_distances = query("SELECT * FROM avg_trip_distances")

citi_traffic = citi_traffic %>%
  inner_join(avg_trip_distances, by = c("start_location_id" = "start_taxi_zone_id", "end_location_id" = "end_taxi_zone_id")) %>%
  select(-count, estimated_avg_distance = avg_distance) %>%
  mutate(
    year_factor = factor(year(month)),
    month_of_year_factor = factor(month(month)),
    time_bucket = factor(time_bucket, levels = c("morning", "midday", "afternoon", "evening", "other")),
    route_type = factor(
      case_when(
        pickup_borough == "Manhattan" & dropoff_borough == "Manhattan" ~ "within_manhattan",
        pickup_borough == "Manhattan" & dropoff_borough != "Manhattan" ~ "manhattan_to_outer_boroughs",
        pickup_borough != "Manhattan" & dropoff_borough == "Manhattan" ~ "outer_boroughs_to_manhattan",
        TRUE ~ "within_outer_boroughs",
      )
    )
  )

citi_traffic_regression = lm(
  log(avg_duration) ~ sqrt(estimated_avg_distance) + time_bucket + date_with_precipitation + route_type + year_factor + month_of_year_factor,
  data = citi_traffic,
  weights = trips
)

summary(citi_traffic_regression)

# Call:
# lm(formula = log(avg_duration) ~ sqrt(estimated_avg_distance) +
#     time_bucket + date_with_precipitation + route_type + year_factor +
#     month_of_year_factor, data = citi_traffic, weights = trips)
#
# Weighted Residuals:
#      Min       1Q   Median       3Q      Max
# -17.7084  -0.3185   0.0678   0.4850  16.5979
#
# Coefficients:
#                                         Estimate Std. Error  t value Pr(>|t|)
# (Intercept)                            4.5808275  0.0021153 2165.556   <2e-16 ***
# sqrt(estimated_avg_distance)           1.3004633  0.0006076 2140.246   <2e-16 ***
# time_bucketmidday                      0.0698344  0.0005641  123.802   <2e-16 ***
# time_bucketafternoon                   0.0456632  0.0005327   85.715   <2e-16 ***
# time_bucketevening                     0.0448342  0.0006269   71.516   <2e-16 ***
# time_bucketother                      -0.0678005  0.0006266 -108.202   <2e-16 ***
# date_with_precipitationTRUE           -0.0242200  0.0005308  -45.626   <2e-16 ***
# route_typeouter_boroughs_to_manhattan  0.0260926  0.0018997   13.735   <2e-16 ***
# route_typewithin_manhattan             0.2444000  0.0014270  171.269   <2e-16 ***
# route_typewithin_outer_boroughs        0.0482845  0.0015670   30.813   <2e-16 ***
# year_factor2014                        0.0072416  0.0007259    9.976   <2e-16 ***
# year_factor2015                       -0.0145335  0.0006962  -20.876   <2e-16 ***
# year_factor2016                       -0.0209216  0.0006710  -31.178   <2e-16 ***
# year_factor2017                       -0.0308949  0.0008528  -36.229   <2e-16 ***
# month_of_year_factor2                  0.0106239  0.0012404    8.565   <2e-16 ***
# month_of_year_factor3                  0.0222076  0.0011450   19.395   <2e-16 ***
# month_of_year_factor4                  0.0533124  0.0010836   49.198   <2e-16 ***
# month_of_year_factor5                  0.0830162  0.0010379   79.983   <2e-16 ***
# month_of_year_factor6                  0.0990421  0.0010193   97.165   <2e-16 ***
# month_of_year_factor7                  0.1045880  0.0010868   96.239   <2e-16 ***
# month_of_year_factor8                  0.0943806  0.0010733   87.935   <2e-16 ***
# month_of_year_factor9                  0.0970698  0.0010607   91.514   <2e-16 ***
# month_of_year_factor10                 0.0684389  0.0010640   64.325   <2e-16 ***
# month_of_year_factor11                 0.0436751  0.0011150   39.172   <2e-16 ***
# month_of_year_factor12                 0.0150918  0.0011712   12.886   <2e-16 ***
# ---
# Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1
#
# Residual standard error: 1.009 on 1078318 degrees of freedom
# Multiple R-squared:  0.8376,  Adjusted R-squared:  0.8376
# F-statistic: 2.317e+05 on 24 and 1078318 DF,  p-value: < 2.2e-16

citi_traffic_coefs = tidy(citi_traffic_regression) %>%
  mutate(exp_estimate = exp(estimate)) %>%
  as_data_frame()

png("graphs/citi_traffic_multipliers_by_year.png", width = 640, height = 640)
filter(citi_traffic_coefs, grepl("^year_factor", term, perl = TRUE)) %>%
  mutate(year = as.numeric(sub("year_factor", "", term))) %>%
  select(year, exp_estimate) %>%
  bind_rows(data_frame(year = 2013, exp_estimate = 1)) %>%
  arrange(year) %>%
  ggplot(aes(x = year, y = exp_estimate)) +
  geom_line(size = 1, color = citi_hex) +
  geom_point(size = 5, color = citi_hex) +
  scale_y_continuous(labels = function(x) { paste0(x, "x") }, breaks = c(0.95, 1, 1.05)) +
  scale_x_continuous(breaks = 2013:2017) +
  expand_limits(y = c(0.95, 1.05)) +
  ggtitle(
    "Citi Bike trip time multipliers by year",
    "Based on model that takes into account trip distance,\nseasonality, weather, and time of day\n\nCiti Bike trip time multiplier, scaled to 2013 = 1"
  ) +
  labs(caption = "Data via Citi Bike\ntoddwschneider.com") +
  theme_tws(base_size = 28) +
  no_axis_titles()
dev.off()

png("graphs/citi_traffic_multipliers_by_month.png", width = 640, height = 400)
filter(citi_traffic_coefs, grepl("^month_of_year_factor", term, perl = TRUE)) %>%
  mutate(month = as.numeric(sub("month_of_year_factor", "", term))) %>%
  select(month, exp_estimate) %>%
  bind_rows(data_frame(month = 1, exp_estimate = 1)) %>%
  arrange(month) %>%
  mutate(month = factor(month, levels = 1:12, labels = month.abb)) %>%
  ggplot(aes(x = month, y = exp_estimate)) +
  geom_point(size = 5, color = citi_hex) +
  geom_segment(aes(xend = month, yend = 1), color = citi_hex, size = 1) +
  scale_y_continuous(labels = function(x) { paste0(x, "x") }, breaks = c(1, 1.05, 1.1, 1.15)) +
  ggtitle(
    "Citi Bike trip time multipliers by month",
    "Scaled to Jan = 1"
  ) +
  labs(caption = "Data via Citi Bike\ntoddwschneider.com") +
  theme_tws(base_size = 28) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(size = rel(0.8))
  ) +
  no_axis_titles()
dev.off()
