library(ggplot2)
library(ggmap)
library(dplyr)
library(reshape2)
library(zoo)
library(scales)
library(extrafont)
library(grid)
library(RPostgreSQL)
library(rgdal)
library(maptools)
gpclibPermit()
source("helpers.R")

# this script assumes that queries in prepare_analysis.sql have been run

# import spatial data for census tracts and neighborhoods
tracts = spTransform(readOGR("../nyct2010_15b", layer = "nyct2010"), CRS("+proj=longlat +datum=WGS84"))
tracts@data$id = as.character(as.numeric(rownames(tracts@data)) + 1)
tracts.points = fortify(tracts, region = "id")
tracts.map = inner_join(tracts.points, tracts@data, by = "id")

nyc_map = tracts.map
ex_staten_island_map = filter(tracts.map, BoroName != "Staten Island")
manhattan_map = filter(tracts.map, BoroName == "Manhattan")

# NYC dot maps
pickups = query("SELECT * FROM trips_by_lat_long_cab_type ORDER BY count")
pickups = mutate(pickups, cab_type_id = factor(cab_type_id))

alpha_range = c(0.14, 0.75)
size_range = c(0.134, 0.173)

p = ggplot() +
  geom_polygon(data = ex_staten_island_map,
               aes(x = long, y = lat, group = group),
               fill = "#080808", color = "#080808") +
  geom_point(data = pickups,
             aes(x = pickup_long, y = pickup_lat, alpha = count, size = count, color = cab_type_id)) +
  scale_alpha_continuous(range = alpha_range, trans = "log", limits = range(pickups$count)) +
  scale_size_continuous(range = size_range, trans = "log", limits = range(pickups$count)) +
  scale_color_manual(values = c("#ffffff", green_hex)) +
  coord_map(xlim = range(ex_staten_island_map$long), ylim = range(ex_staten_island_map$lat)) +
  title_with_subtitle("New York City Taxi Pickups", "2009–2015") +
  theme_dark_map(base_size = 24) +
  theme(legend.position = "none")

fname = "graphs/taxi_pickups_map.png"
png(filename = fname, width = 490, height = 759, bg = "black")
print(p)
add_credits(color = "#dddddd", xpos = 0.98)
dev.off()

dropoffs = query("SELECT * FROM dropoff_by_lat_long_cab_type ORDER BY count")
dropoffs = mutate(dropoffs, cab_type_id = factor(cab_type_id))

p = ggplot() +
  geom_polygon(data = ex_staten_island_map,
               aes(x = long, y = lat, group = group),
               fill = "#080808", color = "#080808") +
  geom_point(data = dropoffs,
             aes(x = dropoff_long, y = dropoff_lat, alpha = count, size = count, color = cab_type_id)) +
  scale_alpha_continuous(range = alpha_range, trans = "log", limits = range(dropoffs$count)) +
  scale_size_continuous(range = size_range, trans = "log", limits = range(dropoffs$count)) +
  scale_color_manual(values = c("#ffffff", green_hex)) +
  coord_map(xlim = range(ex_staten_island_map$long), ylim = range(ex_staten_island_map$lat)) +
  title_with_subtitle("New York City Taxi Drop Offs", "2009–2015") +
  theme_dark_map(base_size = 24) +
  theme(legend.position = "none")

fname = "graphs/taxi_dropoffs_map.png"
png(filename = fname, width = 490, height = 759, bg = "black")
print(p)
add_credits(color = "#dddddd", xpos = 0.98)
dev.off()

# high resolution maps
alpha_range = c(0.14, 0.75)
size_range = c(0.72, 1.02)

p = ggplot() +
  geom_polygon(data = ex_staten_island_map,
               aes(x = long, y = lat, group = group),
               fill = "#080808", color = "#080808", size = 0) +
  geom_point(data = pickups,
             aes(x = pickup_long, y = pickup_lat, alpha = count, size = count, color = cab_type_id)) +
  scale_alpha_continuous(range = alpha_range, trans = "log", limits = range(pickups$count)) +
  scale_size_continuous(range = size_range, trans = "log", limits = range(pickups$count)) +
  scale_color_manual(values = c("#ffffff", green_hex)) +
  coord_map(xlim = range(ex_staten_island_map$long), ylim = range(ex_staten_island_map$lat)) +
  theme_dark_map() +
  theme(legend.position = "none")

fname = "graphs/taxi_pickups_map_hires.png"
png(filename = fname, width = 2880, height = 4068, bg = "black")
print(p)
dev.off()

p = ggplot() +
  geom_polygon(data = ex_staten_island_map,
               aes(x = long, y = lat, group = group),
               fill = "#080808", color = "#080808", size = 0) +
  geom_point(data = dropoffs,
             aes(x = dropoff_long, y = dropoff_lat, alpha = count, size = count, color = cab_type_id)) +
  scale_alpha_continuous(range = alpha_range, trans = "log", limits = range(dropoffs$count)) +
  scale_size_continuous(range = size_range, trans = "log", limits = range(dropoffs$count)) +
  scale_color_manual(values = c("#ffffff", green_hex)) +
  coord_map(xlim = range(ex_staten_island_map$long), ylim = range(ex_staten_island_map$lat)) +
  theme_dark_map() +
  theme(legend.position = "none")

fname = "graphs/taxi_dropoffs_map_hires.png"
png(filename = fname, width = 2880, height = 4068, bg = "black")
print(p)
dev.off()

# borough trends
daily_pickups_borough_type = query("
  SELECT
    *,
    CASE type
      WHEN 'uber' THEN boroname || type || EXTRACT(YEAR FROM date)
      ELSE boroname || type
    END AS group_for_monthly_total
  FROM daily_pickups_by_borough_and_type
  WHERE boroname != 'New Jersey'
  ORDER BY boroname, type, date
")

cab_type_levels = c("yellow", "green", "uber")
cab_type_labels = c("Yellow taxi", "Green taxi", "Uber car")

daily_pickups_borough_type = daily_pickups_borough_type %>%
  mutate(type = factor(type, levels = cab_type_levels, labels = cab_type_labels)) %>%
  group_by(group_for_monthly_total) %>%
  mutate(monthly = rollsum(trips, k = 28, na.pad = TRUE, align = "right"))

daily_dropoffs_borough = query("
  SELECT *
  FROM daily_dropoffs_by_borough
  WHERE boroname != 'New Jersey'
  ORDER BY boroname, date
")

daily_dropoffs_borough = daily_dropoffs_borough %>%
  mutate(type = factor(type, levels = cab_type_levels[1:2], labels = cab_type_labels[1:2])) %>%
  group_by(boroname, type) %>%
  mutate(monthly = rollsum(trips, k = 28, na.pad = TRUE, align = "right"))

for (b in boroughs) {
  p = ggplot(data = filter(daily_pickups_borough_type, type != "Uber car", boroname == b),
         aes(x = date, y = monthly, color = type)) +
        geom_line(size = 1) +
        scale_x_date("") +
        scale_y_continuous("pickups, trailing 28 days\n", labels = comma) +
        scale_color_manual("", values = c(yellow_hex, green_hex)) +
        title_with_subtitle(paste(b, "Monthly Taxi Pickups"), "Based on NYC TLC trip data") +
        expand_limits(y = 0) +
        theme_tws(base_size = 20) +
        theme(legend.position = "bottom")

  png(filename = paste0("graphs/taxi_pickups_", to_slug(b), ".png"), width = 640, height = 420)
  print(p)
  add_credits()
  dev.off()

  p = ggplot(data = filter(daily_pickups_borough_type, date >= "2014-01-01" & boroname == b),
         aes(x = date, y = monthly, color = type, group = group_for_monthly_total)) +
        geom_line(size = 1) +
        scale_x_date("", labels = date_format("%m/%y")) +
        scale_y_continuous("pickups, trailing 28 days\n", labels = comma) +
        scale_color_manual("", values = c(yellow_hex, green_hex, uber_hex)) +
        title_with_subtitle(paste0("Uber vs. Taxi Pickups in ", b), "Based on NYC TLC and Uber trip data") +
        expand_limits(y = 0) +
        theme_tws(base_size = 20) +
        theme(legend.position = "bottom")

  png(filename = paste0("graphs/uber_vs_taxi_pickups_", to_slug(b), ".png"), width = 640, height = 420)
  print(p)
  add_credits()
  dev.off()

  p = ggplot(data = filter(daily_dropoffs_borough, boroname == b),
             aes(x = date, y = monthly, color = type)) +
        geom_line(size = 1) +
        scale_x_date("") +
        scale_y_continuous("drop offs, trailing 28 days\n", labels = comma) +
        scale_color_manual("", values = c(yellow_hex, green_hex)) +
        title_with_subtitle(paste(b, "Monthly Taxi Drop Offs"), "Based on NYC TLC trip data") +
        expand_limits(y = 0) +
        theme_tws(base_size = 20) +
        theme(legend.position = "bottom")

  png(filename = paste0("graphs/taxi_dropoffs_", to_slug(b), ".png"), width = 640, height = 420)
  print(p)
  add_credits()
  dev.off()
}

# airport traffic
airport = query("
  SELECT *
  FROM airport_trips_summary
  WHERE day_of_week = 'weekday'
    AND ntaname NOT IN ('Airport', 'Newark Airport')
    AND ntaname NOT LIKE 'park-cemetery-etc%'
  ORDER BY ntaname, airport_code, hour
")

airport = airport %>%
  mutate(timestamp_for_x_axis = as.POSIXct(hour * 3600, origin = "1970-01-01", tz = "UTC"))

xlim = range(airport$timestamp_for_x_axis)

totals_by_nta = airport %>%
  group_by(ntacode, ntaname, airport_code) %>%
  summarize(total = sum(trips_count)) %>%
  ungroup() %>%
  arrange(desc(total))

ntas = query("SELECT DISTINCT ntacode, ntaname, boroname FROM nyct2010 ORDER BY ntacode")
nta_codes_to_calculate = unique(filter(totals_by_nta, total > 1000)$ntacode)
ntas_to_calculate = filter(ntas, ntacode %in% nta_codes_to_calculate)

airport_monthly = query("
  SELECT *
  FROM airport_trips_summary_monthly_avg
  ORDER BY ntacode, airport_code, month
")
airport_monthly$airport_code = factor(airport_monthly$airport_code,
                                      levels = c("LGA", "JFK", "EWR"),
                                      labels = c("LaGuardia", "JFK", "Newark"))

airports = data.frame(code = c("LGA", "JFK", "EWR"),
                      name = c("LaGuardia", "JFK", "Newark Airport"),
                      stringsAsFactors = FALSE)

min_trips = 10

insufficient_data = ggplot(data = data.frame(x = 0, y = 0, label = "insufficient data"),
                             aes(x = x, y = y, label = label)) +
                           geom_text(size = 20) +
                           theme_tws() +
                           theme(text = element_blank(), axis.ticks = element_blank())

for (i in 1:nrow(ntas_to_calculate)) {
  for (j in 1:nrow(airports)) {
    nta = ntas_to_calculate[i, ]
    ap = airports[j, ]
    data = filter(airport, ntacode == nta$ntacode, airport_code == ap$code, trips_count >= min_trips)
    fname = paste0("graphs/airport/", nta$ntacode, "_", ap$code, ".png")

    if (nrow(data) < 12) {
      png(filename = fname, width = 640, height = 120)
      print(insufficient_data)
      dev.off()
      next()
    }

    display_name = nta_display_name(nta$ntacode)
    if (is.na(display_name)) display_name = nta$ntaname
    title_text = paste0(display_name, " to ", ap$name, " Taxi Travel Time")
    title_rel = ifelse(nchar(display_name) > 20, 1, 1.2)

    p = ggplot(data = data, aes(x = timestamp_for_x_axis)) +
          geom_line(aes(y = pct50, alpha = "  Median   ")) +
          geom_ribbon(aes(ymin = pct25, ymax = pct75, alpha = " 25–75th percentile   ")) +
          geom_ribbon(aes(ymin = pct10, ymax = pct90, alpha = "10–90th percentile")) +
          scale_x_datetime("", labels = date_format("%l %p"),
                           breaks = "3 hours", minor_breaks = "1 hour") +
          scale_y_continuous("trip duration in minutes\n") +
          expand_limits(y = 0) +
          coord_cartesian(xlim = xlim) +
          scale_alpha_manual("", values = c(1, 0.2, 0.2)) +
          title_with_subtitle(title_text,
                              "Weekdays only, based on NYC TLC data from 1/2009–6/2015") +
          theme_tws(base_size = 19) +
          theme(legend.position = "bottom",
                plot.title = element_text(size = rel(title_rel))) +
          guides(alpha = guide_legend(override.aes = list(alpha = c(1, 0.4, 0.2),
                                                          size = c(1, 0, 0),
                                                          fill = c(NA, "black", "black"))))

    png(filename = fname, width = 640, height = 420)
    print(p)
    add_credits()
    dev.off()
  }
}

nta_centers = query("SELECT ntacode, long, lat FROM neighborhood_centroids")

# maps of each NTA
for (nta_code in ntas_to_calculate$ntacode) {
  w = h = 320
  nta_data = filter(tracts.map, NTACode == nta_code)
  coords = as.numeric(filter(nta_centers, ntacode == nta_code)[, c("long", "lat")])
  google_map = get_googlemap(center = coords, zoom = 13, size = c(w, h))

  p = ggmap(google_map, extent = "device") +
    geom_polygon(data = nta_data,
                 aes(x = long, y = lat, group = group),
                 color = "#ff0000", fill = "#ff0000", alpha = 0.3, size = 0.1) +
    theme_nothing()

  png(filename = paste0("graphs/airport/", nta_code, "_map.png"), width = w, height = h)
  print(p)
  dev.off()

  Sys.sleep(2)
}

# uber vs. taxi at JFK and LGA
airport_pickups_by_type = query("
  SELECT
    type,
    date,
    CASE type
      WHEN 'uber' THEN type || EXTRACT(YEAR FROM date)
      ELSE type
    END AS group_for_monthly_total,
    SUM(pickups) AS pickups
  FROM airport_pickups_by_type
  WHERE airport_code IN ('LGA', 'JFK')
  GROUP BY type, date, group_for_monthly_total
  ORDER BY type, date
")

airport_pickups_by_type = airport_pickups_by_type %>%
  mutate(type = factor(type, levels = cab_type_levels, labels = cab_type_labels)) %>%
  group_by(group_for_monthly_total) %>%
  mutate(monthly = rollsum(pickups, k = 28, na.pad = TRUE, align = "right"))

png(filename = "graphs/uber_vs_taxi_pickups_airports.png", width = 640, height = 420)
ggplot(data = filter(airport_pickups_by_type, date >= "2014-01-01", type != "Green taxi"),
       aes(x = date, y = monthly, color = type, group = group_for_monthly_total)) +
  geom_line(size = 1) +
  scale_x_date("", labels = date_format("%m/%y")) +
  scale_y_continuous("pickups, trailing 28 days\n", labels = comma) +
  scale_color_manual("", values = c(yellow_hex, uber_hex)) +
  title_with_subtitle(paste("Uber vs. Taxi Pickups at JFK and LaGuardia Airports"), "Based on NYC TLC and Uber trip data") +
  expand_limits(y = 0) +
  theme_tws(base_size = 20) +
  theme(legend.position = "bottom")
add_credits()
dev.off()

# Die Hard 3, UWS to Wall Street
dh3 = query("
  SELECT duration_in_minutes
  FROM die_hard_3
  WHERE dow BETWEEN 1 AND 5
    AND duration_in_minutes IS NOT NULL
    AND duration_in_minutes BETWEEN 10 AND 75
    AND (   (hour = 9 AND EXTRACT(minute FROM pickup_datetime) >= 20)
         OR (hour = 10 AND EXTRACT(minute FROM pickup_datetime) <= 20))
")

png(filename = "graphs/die_hard_3.png", width = 640, height = 420)
ggplot(data = dh3, aes(x = pmin(duration_in_minutes, 45))) +
  geom_histogram(binwidth = 2.5) +
  scale_x_continuous("\ntrip time in minutes",
                     breaks = seq(10, 45, by = 5),
                     labels = c(seq(10, 40, by = 5), ">45"),
                     minor_breaks = c()) +
  scale_y_continuous("count\n") +
  title_with_subtitle("72nd & Broadway to Wall Street Taxi Travel Times", "Weekdays 9:20–10:20 AM, based on NYC TLC data 1/2009–6/2015") +
  theme_tws(base_size = 20)
add_credits()
dev.off()

# weather
weather = query("SELECT * FROM pickups_and_weather ORDER BY date")
weather = weather %>%
  mutate(precip_bucket = cut(precipitation, breaks = c(0, 0.0001, 0.2, 0.4, 0.6, 6), right = FALSE),
         snow_bucket = cut(snowfall, breaks = c(0, 0.0001, 2, 4, 6, 13), right = FALSE),
         taxi_week_avg = rollmean(taxi, k = 7, na.pad = TRUE, align = "right"),
         uber_week_avg = rollmean(uber, k = 7, na.pad = TRUE, align = "right"))

precip = weather %>%
  group_by(precip_bucket) %>%
  summarize(taxi = mean(taxi), days = n())

snowfall = weather %>%
  group_by(snow_bucket) %>%
  summarize(taxi = mean(taxi), days = n())

p1 = ggplot(data = precip, aes(x = precip_bucket, y = taxi)) +
  geom_bar(stat = "identity") +
  scale_x_discrete("\nprecipitation in inches", labels = c(0, "0–0.2", "0.2–0.4", "0.4–0.6", ">0.6")) +
  scale_y_continuous("average daily trips\n", labels = comma) +
  title_with_subtitle("Precipitation vs. NYC Daily Taxi Trips", "Based on NYC TLC data 1/2009–6/2015") +
  theme_tws(base_size = 20)

p2 = ggplot(data = snowfall, aes(x = snow_bucket, y = taxi)) +
  geom_bar(stat = "identity") +
  scale_x_discrete("\nsnowfall in inches", labels = c(0, "0–2", "2–4", "4–6", ">6")) +
  scale_y_continuous("average daily taxi trips\n", labels = comma) +
  title_with_subtitle("Snowfall vs. NYC Daily Taxi Trips", "Based on NYC TLC data 1/2009–6/2015") +
  theme_tws(base_size = 20)

png(filename = "graphs/daily_trips_precipitation.png", width = 640, height = 420)
print(p1)
add_credits()
dev.off()

png(filename = "graphs/daily_trips_snowfall.png", width = 640, height = 420)
print(p2)
add_credits()
dev.off()

filter(weather, date >= '2015-01-07') %>%
  mutate(taxi_last_week = lag(taxi_week_avg, 1), uber_last_week = lag(uber_week_avg, 1)) %>%
  filter(snowfall > 4) %>%
  select(date, snowfall, precipitation, taxi, uber, taxi_last_week, uber_last_week) %>%
  mutate(taxi_frac = taxi / taxi_last_week, uber_frac = uber / uber_last_week)

filter(weather, date >= '2015-01-07') %>%
  mutate(taxi_last_week = lag(taxi_week_avg, 1), uber_last_week = lag(uber_week_avg, 1)) %>%
  filter(snowfall == 0, precipitation > 0.6) %>%
  select(date, snowfall, precipitation, taxi, uber, taxi_last_week, uber_last_week) %>%
  mutate(taxi_frac = taxi / taxi_last_week, uber_frac = uber / uber_last_week)

# Bridge and tunnel
bnt = query("
  SELECT
    id,
    pickup_datetime,
    pickup_longitude,
    pickup_latitude,
    dropoff_longitude,
    dropoff_latitude,
    pickup_nyct2010_gid,
    dropoff_nyct2010_gid
  FROM bridge_and_tunnel
  WHERE
    dropoff_longitude IS NOT NULL
    AND dropoff_latitude IS NOT NULL
")

goog_map = get_googlemap(center = c(-73.984, 40.7425), zoom = 13, style = "element:labels|visibility:off")
bbox = attr(goog_map, "bb")
dropoffs = table(bnt$dropoff_nyct2010_gid)

png(filename = "graphs/bridge_and_tunnel_tracts.png", width = 480, height = 550, bg = "#f4f4f4")
ggmap(goog_map, extend = "device") +
  geom_polygon(data = ex_staten_island_map,
               aes(x = long, y = lat, group = group, alpha = dropoffs[as.character(id)]),
               fill = "#ff0000",
               color = "#222222",
               size = 0) +
  scale_x_continuous(lim = range(nyc_map$long)) +
  scale_y_continuous(lim = range(nyc_map$lat)) +
  scale_alpha_continuous(range = c(0, 0.8)) +
  coord_map(xlim = bbox[c(2, 4)], ylim = bbox[c(1, 3)]) +
  title_with_subtitle("Bridge and Tunnel Destinations", "Drop offs for Saturday evening taxi rides originating at Penn Station") +
  theme_tws_map(base_size = 19) +
  theme(legend.position = "none")
add_credits()
dev.off()

mh_map = get_googlemap(center = c(-73.978, 40.74486), zoom = 16, style = "feature:poi|visibility:off")
mh = filter(bnt, dropoff_nyct2010_gid %in% c(11, 1413, 1431, 1440, 1525, 1526, 1621, 1666, 1667, 1885))

png("graphs/murray_hill_bnt.png", width = 640, height = 709, bg = "#f4f4f4")
ggmap(mh_map, extent = "device") +
  geom_point(data=mh,
             aes(x = dropoff_longitude, y=dropoff_latitude),
             alpha = 0.0275,
             size = 2,
             color = "#cc0000") +
  title_with_subtitle("Murray Hill Bridge and Tunnel", "Drop offs for Saturday evening taxi rides originating at Penn Station") +
  theme_tws_map(base_size = 20)
add_credits()
dev.off()

# Williamsburg Northside
northside = query("
  SELECT
    date(pickup_hour) AS date,
    SUM(count) AS pickups
  FROM hourly_pickups
  WHERE pickup_nyct2010_gid = 1100
    AND cab_type_id IN (1, 2)
  GROUP BY date
  ORDER BY date
")

northside = northside %>%
  mutate(monthly = rollsum(pickups, k = 28, na.pad = TRUE, align = "right"))

png(filename = "graphs/northside_williamsburg_pickups.png", width = 640, height = 420)
ggplot(data = northside, aes(x = date, y = monthly)) +
  geom_line(size = 1) +
  scale_x_date("") +
  scale_y_continuous("pickups, trailing 28 days\n", labels = comma) +
  title_with_subtitle("Northside Williamsburg Taxi Pickups", "N 7th to N 14th, East River to Berry St, based on NYC TLC data") +
  theme_tws(base_size = 20) +
  theme(legend.position = "bottom")
add_credits()
dev.off()

northside_pickup_locations = query("
  SELECT
    pickup_longitude,
    pickup_latitude,
    pickup_datetime,
    month
  FROM northside_pickups
  ORDER BY pickup_datetime
")

northside_map = get_googlemap(center = c(-73.9579, 40.7215), zoom = 17)

periods = list(
  c("2011-01-01", "2011-07-01", "1st Half 2011"),
  c("2011-07-01", "2012-01-01", "2nd Half 2011"),
  c("2012-01-01", "2012-07-01", "1st Half 2012"),
  c("2012-07-01", "2013-01-01", "2nd Half 2012"),
  c("2013-01-01", "2013-07-01", "1st Half 2013"),
  c("2013-07-01", "2014-01-01", "2nd Half 2013"),
  c("2014-01-01", "2014-07-01", "1st Half 2014"),
  c("2014-07-01", "2015-01-01", "2nd Half 2014"),
  c("2015-01-01", "2015-07-01", "1st Half 2015")
)

for (months in periods) {
  p = ggmap(northside_map, extent = "device") +
        geom_point(data = filter(northside_pickup_locations, pickup_datetime >= months[1], pickup_datetime < months[2]),
               aes(x = pickup_longitude, y = pickup_latitude),
               alpha = 0.007,
               size = 2.5,
               color = "#d00000") +
    title_with_subtitle(months[3], "Taxi pickups in Northside Williamsburg") +
    theme_tws_map(base_size = 20)

  png(filename = paste0("graphs/northside/northside_", months[1], ".png"), bg = "#f4f4f4", width = 480, height = 550)
  print(p)
  add_credits()
  dev.off()
}

# convert to animated gif with ImageMagick

# investment banks
gs = query("
  SELECT
    dropoff_datetime,
    date_trunc('day', dropoff_datetime) AS dropoff_day,
    EXTRACT(EPOCH FROM dropoff_datetime - date_trunc('day', dropoff_datetime)) AS second_of_day,
    pickup_datetime,
    pickup_nyct2010_gid,
    pickup_longitude,
    pickup_latitude,
    EXTRACT(HOUR FROM dropoff_datetime) AS hour,
    EXTRACT(DOW FROM dropoff_datetime) AS dow
  FROM goldman_sachs_dropoffs
")

citi = query("
  SELECT
    dropoff_datetime,
    date_trunc('day', dropoff_datetime) AS dropoff_day,
    EXTRACT(EPOCH FROM dropoff_datetime - date_trunc('day', dropoff_datetime)) AS second_of_day,
    pickup_datetime,
    pickup_nyct2010_gid,
    pickup_longitude,
    pickup_latitude,
    EXTRACT(HOUR FROM dropoff_datetime) AS hour,
    EXTRACT(DOW FROM dropoff_datetime) AS dow
  FROM citigroup_dropoffs
")

gs = gs %>%
  mutate(timestamp_for_x_axis = as.POSIXct(second_of_day, origin = "1970-01-01", tz = "UTC"))

citi = citi %>%
  mutate(timestamp_for_x_axis = as.POSIXct(second_of_day, origin = "1970-01-01", tz = "UTC"))

png(filename = "graphs/gs_dropoffs.png", width = 640, height = 420)
ggplot(data = filter(gs, dow %in% 1:5),
       aes(x = timestamp_for_x_axis)) +
  geom_histogram(binwidth = 600) +
  scale_x_datetime("\ndrop off time", labels = date_format("%l %p"), minor_breaks = "1 hour") +
  scale_y_continuous("taxi drop offs\n", labels = comma) +
  title_with_subtitle("Goldman Sachs Weekday Taxi Drop Offs at 200 West St", "Based on NYC TLC data from 1/2009–6/2015") +
  theme_tws(base_size = 19)
add_credits()
dev.off()

png(filename = "graphs/citi_dropoffs.png", width = 640, height = 420)
ggplot(data = filter(citi, dow %in% 1:5),
       aes(x = timestamp_for_x_axis)) +
  geom_histogram(binwidth = 600) +
  scale_x_datetime("\ndrop off time", labels = date_format("%l %p"), minor_breaks = "1 hour") +
  scale_y_continuous("taxi drop offs\n", labels = comma) +
  title_with_subtitle("Citigroup Weekday Taxi Drop Offs at 388 Greenwich St", "Based on NYC TLC data from 1/2009–6/2015") +
  theme_tws(base_size = 19)
add_credits()
dev.off()

# cash vs. credit
payments = query("
  WITH pt AS (
  SELECT
    date(month) AS month,
    CASE
      WHEN LOWER(payment_type) IN ('2', 'csh', 'cash', 'cas') THEN 'cash'
      WHEN LOWER(payment_type) IN ('1', 'crd', 'credit', 'cre') THEN 'credit'
    END AS payment_type,
    SUM(count) AS trips
  FROM payment_types
  GROUP BY month, payment_type
  )
  SELECT
    month,
    SUM(CASE WHEN payment_type = 'credit' THEN trips ELSE 0 END) / SUM(trips) AS frac_credit
  FROM pt
  GROUP BY month
  ORDER BY month
")

payments_split = query("
  WITH pt AS (
  SELECT
    date(month) AS month,
    total_amount_bucket,
    CASE
      WHEN LOWER(payment_type) IN ('2', 'csh', 'cash', 'cas') THEN 'cash'
      WHEN LOWER(payment_type) IN ('1', 'crd', 'credit', 'cre') THEN 'credit'
    END AS payment_type,
    SUM(count) AS trips
  FROM payment_types
  GROUP BY month, payment_type, total_amount_bucket
  )
  SELECT
    month,
    total_amount_bucket,
    SUM(CASE WHEN payment_type = 'credit' THEN trips ELSE 0 END) / SUM(trips) AS frac_credit
  FROM pt
  WHERE total_amount_bucket BETWEEN 0 AND 30
  GROUP BY month, total_amount_bucket
  ORDER BY month, total_amount_bucket
")

png(filename = "graphs/cash_vs_credit.png", width = 640, height = 420)
ggplot(data = payments, aes(x = month, y = frac_credit)) +
  geom_line(size = 1) +
  scale_y_continuous("% paying with credit card\n", labels = percent) +
  scale_x_date("") +
  title_with_subtitle("Cash vs. Credit NYC Taxi Payments", "Based on NYC TLC data") +
  expand_limits(y = 0) +
  theme_tws(base_size = 20)
add_credits()
dev.off()

payments_split = payments_split %>%
  mutate(total_amount_bucket = factor(total_amount_bucket, labels = c("$0–$10  ", "$10–$20  ", "$20–$30  ", "$30–$40  ")))

png(filename = "graphs/cash_vs_credit_split.png", width = 640, height = 420)
ggplot(data = payments_split, aes(x = month, y = frac_credit, color = total_amount_bucket)) +
  geom_line(size = 1) +
  scale_y_continuous("% paying with credit card\n", labels = percent) +
  scale_x_date("") +
  scale_color_discrete("Fare amount") +
  title_with_subtitle("Cash vs. Credit by Total Fare Amount", "Based on NYC TLC data") +
  expand_limits(y = 0) +
  theme_tws(base_size = 20) +
  theme(legend.position = "bottom")
add_credits()
dev.off()
