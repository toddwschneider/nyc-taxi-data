source("helpers_2017.R")

# this script assumes that queries in queries_2017.sql have been run

trips = query("
  SELECT * FROM daily_trips
  UNION
  SELECT * FROM daily_manhattan
  UNION
  SELECT * FROM daily_manhattan_hub
  UNION
  SELECT * FROM daily_airports
  UNION
  SELECT * FROM daily_outer_boroughs_ex_airports
  ORDER BY car_type, geo, date
")

write_csv(trips, "data/daily_trips_by_geography.csv")

# make sure to zero-pad when there are missing dates
# so that rolling 28-day totals are correct
date_seq = seq(
  as.Date("2009-01-01"),
  as.Date("2017-12-31"),
  by = "1 day"
)

trips = trips %>%
  group_by(car_type) %>%
  complete(
    date = date_seq,
    geo = c("total", "manhattan", "manhattan_hub", "airports", "outer_boroughs_ex_airports"),
    fill = list(trips = 0)
  ) %>%
  ungroup() %>%
  filter(
    date >= case_when(
      car_type == "yellow" ~ as.Date("2009-01-01"),
      car_type == "green" ~ as.Date("2013-08-01"),
      car_type == "uber" ~ as.Date("2014-04-01"),
      car_type %in% c("lyft", "via") ~ as.Date("2015-04-01"),
      car_type == "juno" ~ as.Date("2016-03-01"),
      car_type == "gett" ~ as.Date("2016-04-01"),
      car_type == "other" ~ as.Date("2015-09-01")
    )
  ) %>%
  filter(
    case_when(
      car_type == "uber" & date >= as.Date("2014-10-01") & date <= as.Date("2014-12-31") ~ FALSE,
      TRUE ~ TRUE
    )
  ) %>%
  mutate(
    grouping = case_when(
      car_type == "uber" & date < as.Date("2015-01-01") ~ "uber_2014",
      TRUE ~ car_type
    )
  ) %>%
  arrange(car_type, geo, date) %>%
  group_by(car_type, grouping, geo) %>%
  mutate(monthly = rollsumr(trips, k = 28, na.pad = TRUE)) %>%
  ungroup() %>%
  mutate(
    car_type = factor(
      car_type,
      levels = c("yellow", "green", "uber", "lyft", "juno", "via", "other", "gett"),
      labels = c("Yellow taxis", "Green taxis", "Uber", "Lyft", "Juno", "Via", "Non-app FHVs", "Gett")
    ),
    parent_type = factor(
      case_when(
        car_type %in% c("Yellow taxis", "Green taxis") ~ "Taxis",
        car_type == "Non-app FHVs" ~ "Other",
        TRUE ~ "Ride-hailing apps"
      ),
      levels = c("Taxis", "Ride-hailing apps", "Other")
    )
  )

# Juno and Gett do not report pickup geography
# assume they follow same distribution as the average of Uber and Lyft
uber_lyft_geo_fracs = trips %>%
  filter(car_type %in% c("Uber", "Lyft")) %>%
  group_by(date, geo) %>%
  summarize(trips = sum(trips), monthly = sum(monthly, na.rm = TRUE)) %>%
  ungroup() %>%
  group_by(date) %>%
  mutate(
    daily_frac = trips / sum(trips * as.numeric(geo == "total")),
    monthly_frac = monthly / sum(monthly * as.numeric(geo == "total"))
  ) %>%
  ungroup() %>%
  select(date, geo, daily_frac, monthly_frac)

trips = trips %>%
  left_join(uber_lyft_geo_fracs, by = c("date", "geo")) %>%
  group_by(car_type, date) %>%
  mutate(
    monthly = case_when(
      car_type %in% c("Juno", "Gett") & geo != "total" ~ sum(as.numeric(geo == "total") * monthly) * monthly_frac,
      TRUE ~ monthly
    ),
    monthly_is_estimated = case_when(
      car_type %in% c("Juno", "Gett") & geo != "total" ~ TRUE,
      TRUE ~ FALSE
    )
  ) %>%
  ungroup() %>%
  select(-daily_frac, -monthly_frac)


### graphs by geography

# citywide total
totals_by_car_type = trips %>%
  filter(
    date >= as.Date("2014-01-01"),
    car_type %in% c("Yellow taxis", "Green taxis", "Uber", "Lyft", "Juno", "Via"),
    geo == "total"
  )

totals_by_car_type_label_data = totals_by_car_type %>%
  filter(date == max(date)) %>%
  mutate(yval = case_when(
    car_type == "Juno" ~ monthly + 400e3,
    car_type == "Green taxis" ~ monthly - 500e3,
    TRUE ~ monthly
  ))

totals_by_car_type_plot = totals_by_car_type %>%
  ggplot(aes(x = date, y = monthly, color = car_type, group = grouping)) +
  geom_line(size = 1.5) +
  geom_text(
    data = totals_by_car_type_label_data,
    aes(x = date + 25, y = yval, label = car_type),
    size = 8,
    hjust = 0,
    family = "Open Sans"
  ) +
  scale_color_manual(values = c(yellow_hex, green_hex, uber_hex, lyft_hex, juno_hex, via_hex), guide = FALSE) +
  scale_y_continuous(labels = unit_format("m", scale = 1e-6, sep = "")) +
  scale_x_date(
    breaks = seq.Date(as.Date("2014-01-01"), as.Date("2018-01-01"), by = "1 year"),
    minor_breaks = NULL,
    labels = date_format("%Y")
  ) +
  ggtitle("NYC Monthly Taxi Pickups", "Trailing 28 days") +
  labs(caption = "Data via NYC TLC\ntoddwschneider.com") +
  expand_limits(y = c(0, 15e6), x = as.Date(c("2014-01-01", "2018-10-30"))) +
  theme_tws(base_size = 36) +
  no_axis_titles()

totals_by_parent_type = trips %>%
  filter(
    parent_type %in% c("Taxis", "Ride-hailing apps"),
    geo == "total",
    !is.na(monthly)
  ) %>%
  group_by(parent_type, date) %>%
  summarize(monthly = sum(monthly)) %>%
  ungroup() %>%
  mutate(grouping = factor(
    case_when(
      parent_type == "Ride-hailing apps" & date < as.Date("2015-01-01") ~ "Ridehailing_2014",
      TRUE ~ as.character(parent_type)
    ),
    levels = c("Taxis", "Ride-hailing apps", "Ridehailing_2014", "Other")
  ))

totals_by_parent_type_label_data = totals_by_parent_type %>%
  filter(date == as.Date("2017-11-01")) %>%
  mutate(yval = case_when(
    parent_type == "Ride-hailing apps" ~ monthly + 2.5e6,
    parent_type == "Taxis" ~ monthly - 2.2e6
  ))

totals_by_parent_type_plot = totals_by_parent_type %>%
  ggplot(aes(x = date, y = monthly, color = parent_type, group = grouping)) +
  geom_line(size = 1.5) +
  geom_text(
    data = totals_by_parent_type_label_data,
    aes(y = yval, label = gsub(" ", "\n", parent_type)),
    size = 9,
    lineheight = 0.7,
    family = "Open Sans"
  ) +
  scale_color_manual(values = c(yellow_hex, fhv_hex), guide = FALSE) +
  scale_y_continuous(labels = unit_format("m", scale = 1e-6, sep = "")) +
  scale_x_date(
    breaks = seq.Date(as.Date("2010-01-01"), as.Date("2018-01-01"), by = "2 years"),
    minor_breaks = NULL,
    labels = date_format("%Y")
  ) +
  ggtitle("NYC Monthly Taxi Pickups", "Trailing 28 days") +
  labs(caption = paste(
    "Ride-hailing apps include Uber, Lyft, Juno, Via, and Gett; taxis include yellow and green",
    "Data via NYC TLC",
    "toddwschneider.com",
    sep = "\n"
  )) +
  expand_limits(y = c(0, 15e6), x = as.Date(c("2009-02-01", "2018-09-01"))) +
  theme_tws(base_size = 36) +
  no_axis_titles()



# Manhattan
manhattan_by_car_type = trips %>%
  filter(
    date >= as.Date("2014-01-01"),
    car_type %in% c("Yellow taxis", "Green taxis", "Uber", "Lyft", "Via"),
    geo == "manhattan"
  )

manhattan_by_car_type_label_data = manhattan_by_car_type %>%
  filter(date == max(date)) %>%
  mutate(yval = case_when(
    car_type == "Lyft" ~ monthly + 400e3,
    TRUE ~ monthly
  ))

manhattan_by_car_type_plot = manhattan_by_car_type %>%
  ggplot(aes(x = date, y = monthly, color = car_type, group = grouping)) +
  geom_line(size = 1.5) +
  geom_text(
    data = manhattan_by_car_type_label_data,
    aes(x = date + 25, y = yval, label = car_type),
    size = 8,
    hjust = 0,
    family = "Open Sans"
  ) +
  scale_color_manual(values = c(yellow_hex, green_hex, uber_hex, lyft_hex, via_hex), guide = FALSE) +
  scale_y_continuous(labels = unit_format("m", scale = 1e-6, sep = "")) +
  scale_x_date(
    breaks = seq.Date(as.Date("2014-01-01"), as.Date("2018-01-01"), by = "1 year"),
    minor_breaks = NULL,
    labels = date_format("%Y")
  ) +
  ggtitle("Manhattan Monthly Taxi Pickups", "Trailing 28 days") +
  labs(caption = "Data via NYC TLC\ntoddwschneider.com") +
  expand_limits(y = c(0, 15e6), x = as.Date(c("2014-01-01", "2018-10-30"))) +
  theme_tws(base_size = 36) +
  no_axis_titles()

manhattan_by_parent_type = trips %>%
  filter(
    parent_type %in% c("Taxis", "Ride-hailing apps"),
    geo == "manhattan",
    !is.na(monthly)
  ) %>%
  group_by(parent_type, date) %>%
  summarize(monthly = sum(monthly)) %>%
  ungroup() %>%
  mutate(grouping = factor(
    case_when(
      parent_type == "Ride-hailing apps" & date < as.Date("2015-01-01") ~ "Ridehailing_2014",
      TRUE ~ as.character(parent_type)
    ),
    levels = c("Taxis", "Ride-hailing apps", "Ridehailing_2014", "Other")
  ))

manhattan_by_parent_type_label_data = manhattan_by_parent_type %>%
  filter(date == as.Date("2017-11-01")) %>%
  mutate(yval = case_when(
    parent_type == "Ride-hailing apps" ~ monthly - 4e6,
    parent_type == "Taxis" ~ monthly + 1.2e6
  ))

manhattan_by_parent_type_plot = manhattan_by_parent_type %>%
  ggplot(aes(x = date, y = monthly, color = parent_type, group = grouping)) +
  geom_line(size = 1.5) +
  geom_text(
    data = manhattan_by_parent_type_label_data,
    aes(y = yval, label = gsub(" ", "\n", parent_type)),
    size = 9,
    lineheight = 0.7,
    family = "Open Sans"
  ) +
  scale_color_manual(values = c(yellow_hex, fhv_hex), guide = FALSE) +
  scale_y_continuous(labels = unit_format("m", scale = 1e-6, sep = "")) +
  scale_x_date(
    breaks = seq.Date(as.Date("2010-01-01"), as.Date("2018-01-01"), by = "2 years"),
    minor_breaks = NULL,
    labels = date_format("%Y")
  ) +
  ggtitle("Manhattan Monthly Taxi Pickups", "Trailing 28 days") +
  labs(caption = paste(
    "Ride-hailing apps include Uber, Lyft, Juno*, Via, and Gett*; taxis include yellow and green",
    "*Juno/Gett geographic info not available; distribution assumed to be same as Uber/Lyft",
    "Data via NYC TLC",
    "toddwschneider.com",
    sep = "\n"
  )) +
  expand_limits(y = c(0, 15e6), x = as.Date(c("2009-02-01", "2018-09-01"))) +
  theme_tws(base_size = 36) +
  no_axis_titles()



# Manhattan Central Business District
manhattan_cbd_by_car_type = trips %>%
  filter(
    date >= as.Date("2014-01-01"),
    car_type %in% c("Yellow taxis", "Uber", "Lyft", "Via"),
    geo == "manhattan_hub"
  )

manhattan_cbd_by_car_type_label_data = manhattan_cbd_by_car_type %>%
  filter(date == max(date)) %>%
  mutate(yval = case_when(
    car_type == "Lyft" ~ monthly + 200e3,
    TRUE ~ monthly
  ))

manhattan_cbd_by_car_type_plot = manhattan_cbd_by_car_type %>%
  ggplot(aes(x = date, y = monthly, color = car_type, group = grouping)) +
  geom_line(size = 1.5) +
  geom_text(
    data = manhattan_cbd_by_car_type_label_data,
    aes(x = date + 25, y = yval, label = car_type),
    size = 8,
    hjust = 0,
    family = "Open Sans"
  ) +
  scale_color_manual(values = c(yellow_hex, uber_hex, lyft_hex, via_hex), guide = FALSE) +
  scale_y_continuous(labels = unit_format("m", scale = 1e-6, sep = ""), breaks = c(0, 5, 10) * 1e6) +
  scale_x_date(
    breaks = seq.Date(as.Date("2014-01-01"), as.Date("2018-01-01"), by = "1 year"),
    minor_breaks = NULL,
    labels = date_format("%Y")
  ) +
  ggtitle("Manhattan CBD Taxi Pickups", "Pickups south of 60th St, trailing 28 days") +
  labs(caption = "Data via NYC TLC\ntoddwschneider.com") +
  expand_limits(y = c(0, 10e6), x = as.Date(c("2014-01-01", "2018-10-30"))) +
  theme_tws(base_size = 36) +
  no_axis_titles()

manhattan_cbd_by_parent_type = trips %>%
  filter(
    parent_type %in% c("Taxis", "Ride-hailing apps"),
    geo == "manhattan_hub",
    !is.na(monthly)
  ) %>%
  group_by(parent_type, date) %>%
  summarize(monthly = sum(monthly)) %>%
  ungroup() %>%
  mutate(grouping = factor(
    case_when(
      parent_type == "Ride-hailing apps" & date < as.Date("2015-01-01") ~ "Ridehailing_2014",
      TRUE ~ as.character(parent_type)
    ),
    levels = c("Taxis", "Ride-hailing apps", "Ridehailing_2014", "Other")
  ))

manhattan_cbd_by_parent_type_label_data = manhattan_cbd_by_parent_type %>%
  filter(date == as.Date("2017-11-01")) %>%
  mutate(yval = case_when(
    parent_type == "Ride-hailing apps" ~ monthly - 2.5e6,
    parent_type == "Taxis" ~ monthly + 1e6
  ))

manhattan_cbd_by_parent_type_plot = manhattan_cbd_by_parent_type %>%
  ggplot(aes(x = date, y = monthly, color = parent_type, group = grouping)) +
  geom_line(size = 1.5) +
  geom_text(
    data = manhattan_cbd_by_parent_type_label_data,
    aes(y = yval, label = gsub(" ", "\n", parent_type)),
    size = 9,
    lineheight = 0.7,
    family = "Open Sans"
  ) +
  scale_color_manual(values = c(yellow_hex, fhv_hex), guide = FALSE) +
  scale_y_continuous(labels = unit_format("m", scale = 1e-6, sep = ""), breaks = c(0, 5, 10) * 1e6) +
  scale_x_date(
    breaks = seq.Date(as.Date("2010-01-01"), as.Date("2018-01-01"), by = "2 years"),
    minor_breaks = NULL,
    labels = date_format("%Y")
  ) +
  ggtitle("Manhattan CBD Taxi Pickups", "Pickups south of 60th St, trailing 28 days") +
  labs(caption = paste(
    "Ride-hailing apps include Uber, Lyft, Juno*, Via, and Gett*; taxis include yellow and green",
    "*Juno/Gett geographic info not available; distribution assumed to be same as Uber/Lyft",
    "Data via NYC TLC",
    "toddwschneider.com",
    sep = "\n"
  )) +
  expand_limits(y = c(0, 10e6), x = as.Date(c("2009-02-01", "2018-09-01"))) +
  theme_tws(base_size = 36) +
  no_axis_titles()



# outer boroughs excluding airports
outer_boroughs_by_car_type = trips %>%
  filter(
    date >= as.Date("2014-01-01"),
    car_type %in% c("Yellow taxis", "Green taxis", "Uber", "Lyft"),
    geo == "outer_boroughs_ex_airports"
  )

outer_boroughs_by_car_type_label_data = outer_boroughs_by_car_type %>%
  filter(date == max(date)) %>%
  mutate(yval = monthly)

outer_boroughs_by_car_type_plot = outer_boroughs_by_car_type %>%
  ggplot(aes(x = date, y = monthly, color = car_type, group = grouping)) +
  geom_line(size = 1.5) +
  geom_text(
    data = outer_boroughs_by_car_type_label_data,
    aes(x = date + 25, y = yval, label = car_type),
    size = 8,
    hjust = 0,
    family = "Open Sans"
  ) +
  scale_color_manual(values = c(yellow_hex, green_hex, uber_hex, lyft_hex), guide = FALSE) +
  scale_y_continuous(labels = unit_format("m", scale = 1e-6, sep = "")) +
  scale_x_date(
    breaks = seq.Date(as.Date("2014-01-01"), as.Date("2018-01-01"), by = "1 year"),
    minor_breaks = NULL,
    labels = date_format("%Y")
  ) +
  ggtitle("NYC Outer Borough Taxi Pickups", "Excluding airports, trailing 28 days") +
  labs(caption = "Data via NYC TLC\ntoddwschneider.com") +
  expand_limits(y = c(0, 6e6), x = as.Date(c("2014-01-01", "2018-10-30"))) +
  theme_tws(base_size = 36) +
  no_axis_titles()

outer_boroughs_by_parent_type = trips %>%
  filter(
    parent_type %in% c("Taxis", "Ride-hailing apps"),
    geo == "outer_boroughs_ex_airports",
    !is.na(monthly)
  ) %>%
  group_by(parent_type, date) %>%
  summarize(monthly = sum(monthly)) %>%
  ungroup() %>%
  mutate(grouping = factor(
    case_when(
      parent_type == "Ride-hailing apps" & date < as.Date("2015-01-01") ~ "Ridehailing_2014",
      TRUE ~ as.character(parent_type)
    ),
    levels = c("Taxis", "Ride-hailing apps", "Ridehailing_2014", "Other")
  ))

outer_boroughs_by_parent_type_label_data = outer_boroughs_by_parent_type %>%
  filter(date == as.Date("2017-11-01")) %>%
  mutate(yval = case_when(
    parent_type == "Ride-hailing apps" ~ monthly - 4e6,
    parent_type == "Taxis" ~ monthly - 400e3
  ))

outer_boroughs_by_parent_type_plot = outer_boroughs_by_parent_type %>%
  ggplot(aes(x = date, y = monthly, color = parent_type, group = grouping)) +
  geom_line(size = 1.5) +
  geom_text(
    data = outer_boroughs_by_parent_type_label_data,
    aes(y = yval, label = gsub(" ", "\n", parent_type)),
    size = 9,
    lineheight = 0.7,
    family = "Open Sans"
  ) +
  scale_color_manual(values = c(yellow_hex, fhv_hex), guide = FALSE) +
  scale_y_continuous(labels = unit_format("m", scale = 1e-6, sep = ""), breaks = c(0, 4, 8) * 1e6) +
  scale_x_date(
    breaks = seq.Date(as.Date("2010-01-01"), as.Date("2018-01-01"), by = "2 years"),
    minor_breaks = NULL,
    labels = date_format("%Y")
  ) +
  ggtitle("NYC Outer Borough Taxi Pickups", "Excluding airports, trailing 28 days") +
  labs(caption = paste(
    "Ride-hailing apps include Uber, Lyft, Juno*, Via, and Gett*; taxis include yellow and green",
    "*Juno/Gett geographic info not available; distribution assumed to be same as Uber/Lyft",
    "Data via NYC TLC",
    "toddwschneider.com",
    sep = "\n"
  )) +
  expand_limits(y = c(0, 8e6), x = as.Date(c("2009-02-01", "2018-09-01"))) +
  theme_tws(base_size = 36) +
  no_axis_titles()



# JFK + LGA airports
airports_by_car_type = trips %>%
  filter(
    date >= as.Date("2014-01-01"),
    car_type %in% c("Yellow taxis", "Uber", "Lyft"),
    geo == "airports"
  )

airports_by_car_type_label_data = airports_by_car_type %>%
  filter(date == max(date)) %>%
  mutate(yval = monthly)

airports_by_car_type_plot = airports_by_car_type %>%
  ggplot(aes(x = date, y = monthly, color = car_type, group = grouping)) +
  geom_line(size = 1.5) +
  geom_text(
    data = airports_by_car_type_label_data,
    aes(x = date + 25, y = yval, label = car_type),
    size = 8,
    hjust = 0,
    family = "Open Sans"
  ) +
  scale_color_manual(values = c(yellow_hex, uber_hex, lyft_hex), guide = FALSE) +
  scale_y_continuous(labels = unit_format("k", scale = 1e-3, sep = "")) +
  scale_x_date(
    breaks = seq.Date(as.Date("2014-01-01"), as.Date("2018-01-01"), by = "1 year"),
    minor_breaks = NULL,
    labels = date_format("%Y")
  ) +
  ggtitle("NYC Airport Taxi Pickups", "JFK + LGA, trailing 28 days") +
  labs(caption = "Data via NYC TLC\ntoddwschneider.com") +
  expand_limits(y = c(0, 600e3), x = as.Date(c("2014-01-01", "2018-10-30"))) +
  theme_tws(base_size = 36) +
  no_axis_titles()

airports_by_parent_type = trips %>%
  filter(
    parent_type %in% c("Taxis", "Ride-hailing apps"),
    geo == "airports",
    !is.na(monthly)
  ) %>%
  group_by(parent_type, date) %>%
  summarize(monthly = sum(monthly)) %>%
  ungroup() %>%
  mutate(grouping = factor(
    case_when(
      parent_type == "Ride-hailing apps" & date < as.Date("2015-01-01") ~ "Ridehailing_2014",
      TRUE ~ as.character(parent_type)
    ),
    levels = c("Taxis", "Ride-hailing apps", "Ridehailing_2014", "Other")
  ))

airports_by_parent_type_label_data = airports_by_parent_type %>%
  filter(date == as.Date("2017-11-01")) %>%
  mutate(yval = case_when(
    parent_type == "Ride-hailing apps" ~ monthly - 200e3,
    parent_type == "Taxis" ~ monthly + 50e3
  ))

airports_by_parent_type_plot = airports_by_parent_type %>%
  ggplot(aes(x = date, y = monthly, color = parent_type, group = grouping)) +
  geom_line(size = 1.5) +
  geom_text(
    data = airports_by_parent_type_label_data,
    aes(y = yval, label = gsub(" ", "\n", parent_type)),
    size = 9,
    lineheight = 0.7,
    family = "Open Sans"
  ) +
  scale_color_manual(values = c(yellow_hex, fhv_hex), guide = FALSE) +
  scale_y_continuous(labels = unit_format("k", scale = 1e-3, sep = "")) +
  scale_x_date(
    breaks = seq.Date(as.Date("2010-01-01"), as.Date("2018-01-01"), by = "2 years"),
    minor_breaks = NULL,
    labels = date_format("%Y")
  ) +
  ggtitle("NYC Airport Taxi Pickups", "JFK + LGA, trailing 28 days") +
  labs(caption = paste(
    "Ride-hailing apps include Uber, Lyft, Juno*, Via, and Gett*; taxis include yellow and green",
    "*Juno/Gett geographic info not available; distribution assumed to be same as Uber/Lyft",
    "Data via NYC TLC",
    "toddwschneider.com",
    sep = "\n"
  )) +
  expand_limits(y = c(0, 600e3), x = as.Date(c("2009-02-01", "2018-09-01"))) +
  theme_tws(base_size = 36) +
  no_axis_titles()


png("graphs/totals_by_car_type.png", width = 800, height = 800)
print(totals_by_car_type_plot)
dev.off()

png("graphs/totals_by_parent_type.png", width = 800, height = 800)
print(totals_by_parent_type_plot)
dev.off()

png("graphs/manhattan_by_car_type.png", width = 800, height = 800)
print(manhattan_by_car_type_plot)
dev.off()

png("graphs/manhattan_by_parent_type.png", width = 800, height = 800)
print(manhattan_by_parent_type_plot)
dev.off()

png("graphs/manhattan_cbd_by_car_type.png", width = 800, height = 800)
print(manhattan_cbd_by_car_type_plot)
dev.off()

png("graphs/manhattan_cbd_by_parent_type.png", width = 800, height = 800)
print(manhattan_cbd_by_parent_type_plot)
dev.off()

png("graphs/outer_boroughs_by_car_type.png", width = 800, height = 800)
print(outer_boroughs_by_car_type_plot)
dev.off()

png("graphs/outer_boroughs_by_parent_type.png", width = 800, height = 800)
print(outer_boroughs_by_parent_type_plot)
dev.off()

png("graphs/airports_by_car_type.png", width = 800, height = 800)
print(airports_by_car_type_plot)
dev.off()

png("graphs/airports_by_parent_type.png", width = 800, height = 800)
print(airports_by_parent_type_plot)
dev.off()



# ride-hailing market share
ridehail_trips = trips %>%
  filter(
    car_type %in% c("Uber", "Lyft", "Juno", "Via", "Gett"),
    geo == "total"
  ) %>%
  arrange(car_type, grouping, date) %>%
  group_by(car_type, grouping) %>%
  mutate(weekly = rollsumr(trips, k = 7, na.pad = TRUE)) %>%
  ungroup() %>%
  group_by(date) %>%
  mutate(
    daily_market_share = trips / sum(trips, na.rm = TRUE),
    weekly_market_share = weekly / sum(weekly, na.rm = TRUE),
    monthly_market_share = monthly / sum(monthly, na.rm = TRUE)
  ) %>%
  ungroup() %>%
  group_by(car_type, grouping) %>%
  mutate(
    daily_market_share_change = daily_market_share - lag(daily_market_share, 1),
    weekly_market_share_change = weekly_market_share - lag(weekly_market_share, 7),
    monthly_market_share_change = monthly_market_share - lag(monthly_market_share, 28),
  ) %>%
  ungroup()

ridehail_market_share = ridehail_trips %>%
  filter(date >= "2015-04-07", car_type %in% c("Uber", "Lyft")) %>%
  ggplot(aes(x = date, y = weekly_market_share, color = car_type)) +
  geom_line(size = 1.5) +
  geom_text(
    data = filter(ridehail_trips, date == as.Date("2017-09-15"), car_type %in% c("Uber", "Lyft")),
    aes(label = car_type, y = weekly_market_share + 0.07),
    size = 10,
    family = "Open Sans"
  ) +
  geom_vline(xintercept = as.Date("2017-01-28"), alpha = 0.3, size = 3, color = "#ff0000") +
  scale_y_continuous(labels = percent) +
  scale_color_manual(values = c(uber_hex, lyft_hex), guide = FALSE) +
  expand_limits(y = c(0, 1)) +
  ggtitle("Weekly NYC Ride-hail Market Share", "JFK taxi strike on Jan 28, 2017 in red") +
  labs(caption = paste(
    "Market share calculated as percentage of (Uber + Lyft + Juno + Via + Gett)",
    "Data via NYC TLC",
    "toddwschneider.com",
    sep = "\n"
  )) +
  theme_tws(base_size = 36) +
  theme(plot.title = element_text(size = rel(1.1))) +
  no_axis_titles()

png("graphs/ridehail_market_share.png", width = 800, height = 800)
print(ridehail_market_share)
dev.off()

# Uber and Lyft weeks with biggest INCREASE in ride-hailing market share
ridehail_trips %>%
  filter(
    car_type %in% c("Uber", "Lyft"),
    geo == "total",
    date >= as.Date("2015-05-01")
  ) %>%
  arrange(car_type, desc(weekly_market_share_change)) %>%
  group_by(car_type) %>%
  top_n(10, weekly_market_share_change) %>%
  ungroup() %>%
  select(car_type, date, weekly_market_share, weekly_market_share_change)

# Uber and Lyft weeks with biggest DECREASE in ride-hailing market share
ridehail_trips %>%
  filter(
    car_type %in% c("Uber", "Lyft"),
    geo == "total",
    date >= as.Date("2015-05-01")
  ) %>%
  arrange(car_type, weekly_market_share_change) %>%
  group_by(car_type) %>%
  top_n(-10, weekly_market_share_change) %>%
  ungroup() %>%
  select(car_type, date, weekly_market_share, weekly_market_share_change)


# JFK protest Jan 28, 2017
jfk_hourly_pickups = query("
  SELECT * FROM (
    SELECT
      'yellow'::text AS car_type,
      pickup_hour,
      trips
    FROM jfk_hourly_pickups_taxi
    WHERE cab_type_id = 1
  UNION
    SELECT
      dba_category,
      pickup_hour,
      trips
    FROM jfk_hourly_pickups_fhv
    WHERE dba_category = 'uber'
  ) q
  WHERE pickup_hour BETWEEN '2016-12-01' AND '2017-03-31'
  ORDER BY car_type, pickup_hour
")

write_csv(jfk_hourly_pickups, "data/jfk_hourly_pickups.csv")

protest_hour = as.POSIXct("2017-01-28 18:00:00")

jfk_hourly_pickups = mutate(jfk_hourly_pickups,
  car_type = factor(car_type, levels = c("yellow", "uber"), labels = c("Yellow taxis", "Uber")),
  fill_color = case_when(
    pickup_hour == protest_hour ~ "#cc0000",
    car_type == "Yellow taxis" ~ yellow_hex,
    car_type == "Uber" ~ uber_hex
  )
)

jfk_hourly = jfk_hourly_pickups %>%
  filter(
    pickup_hour >= as.POSIXct("2017-01-26 00:00:00"),
    pickup_hour < as.POSIXct("2017-02-01 00:00:00")
  ) %>%
  ggplot(aes(x = pickup_hour, y = trips, fill = fill_color, color = fill_color)) +
  geom_bar(stat = "identity", width = 2800, size = 0) +
  scale_fill_identity() +
  scale_color_identity() +
  scale_y_continuous(labels = comma, minor_breaks = NULL) +
  expand_limits(y = 0) +
  coord_cartesian(xlim = as.POSIXct(c("2017-01-27 02:00:00", "2017-01-30 16:00:00"))) +
  facet_wrap(~car_type, ncol = 1) +
  ggtitle("Hourly JFK Pickups, Jan 2017", "Taxi strike 6–7 PM on Jan 28, 2017 in red") +
  labs(caption = "Data via NYC TLC\ntoddwschneider.com") +
  theme_tws(base_size = 36) +
  no_axis_titles()

png("graphs/jfk_hourly_pickups.png", width = 800, height = 800)
print(jfk_hourly)
dev.off()

election = query("
  SELECT
    e.*,
    ul.lyft_share_2016,
    ul.pre_strike_lyft_share,
    ul.post_strike_lyft_share,
    ul.rest_of_2017_lyft_share,
    ul.lyft_share_change
  FROM uber_vs_lyft_carto_data ul, election_results_by_taxi_zone e
  WHERE ul.locationid = e.locationid
    AND e.estimated_total_votes > 1000
")

summary(lm(lyft_share_change ~ clinton, data = election))
# Call:
# lm(formula = lyft_share_change ~ clinton, data = election)
#
# Residuals:
#      Min       1Q   Median       3Q      Max
# -0.05649 -0.02151 -0.00854  0.01503  0.10695
#
# Coefficients:
#              Estimate Std. Error t value Pr(>|t|)
# (Intercept) -0.001073   0.008925  -0.120    0.904
# clinton      0.062076   0.011152   5.567 7.13e-08 ***
# ---
# Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1
#
# Residual standard error: 0.03262 on 233 degrees of freedom
# Multiple R-squared:  0.1174,  Adjusted R-squared:  0.1136
# F-statistic: 30.99 on 1 and 233 DF,  p-value: 7.126e-08

summary(lm(lyft_share_change ~ stein, data = election))
# Call:
# lm(formula = lyft_share_change ~ stein, data = election)
#
# Residuals:
#       Min        1Q    Median        3Q       Max
# -0.058317 -0.019047 -0.001654  0.012641  0.101557
#
# Coefficients:
#              Estimate Std. Error t value Pr(>|t|)
# (Intercept) -0.014323   0.005718  -2.505   0.0129 *
# stein        4.635190   0.408649  11.343   <2e-16 ***
# ---
# Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1
#
# Residual standard error: 0.02787 on 233 degrees of freedom
# Multiple R-squared:  0.3557,  Adjusted R-squared:  0.353
# F-statistic: 128.7 on 1 and 233 DF,  p-value: < 2.2e-16

clinton = election %>%
  ggplot(aes(x = clinton, y = lyft_share_change)) +
  geom_point(size = 4, alpha = 0.7) +
  scale_x_continuous("Clinton vote %", labels = percent) +
  scale_y_continuous("Lyft market share increase", labels = percent) +
  expand_limits(x = c(0.1, 1)) +
  ggtitle("Lyft Usage vs. Clinton Vote %") +
  labs(caption = paste(
    "Market share calculated as percentage of (Uber + Lyft) in each taxi zone",
    "Increase measured from month ending 1/28/17 to week ending 2/4/17",
    "Data via NYC TLC and NYC Board of Elections",
    "toddwschneider.com",
    sep = "\n"
  )) +
  theme_tws(base_size = 36) +
  theme(axis.title = element_text(size = rel(0.7)))

stein = election %>%
  ggplot(aes(x = stein, y = lyft_share_change)) +
  geom_point(size = 4, alpha = 0.7) +
  scale_x_continuous("Jill Stein vote %", labels = percent) +
  scale_y_continuous("Lyft market share increase", labels = percent) +
  ggtitle("Lyft Usage vs. Jill Stein Vote %") +
  labs(caption = paste(
    "Market share calculated as percentage of (Uber + Lyft) in each taxi zone",
    "Increase measured from month ending 1/28/17 to week ending 2/4/17",
    "Data via NYC TLC and NYC Board of Elections",
    "toddwschneider.com",
    sep = "\n"
  )) +
  theme_tws(base_size = 36) +
  theme(axis.title = element_text(size = rel(0.7)))

png("graphs/lyft_vs_clinton.png", width = 800, height = 800)
print(clinton)
dev.off()

png("graphs/lyft_vs_jill_stein.png", width = 800, height = 800)
print(stein)
dev.off()
