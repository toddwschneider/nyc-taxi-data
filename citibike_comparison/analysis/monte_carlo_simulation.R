source("helpers.R")

# Run the simulation for trips beginning in a list of zones
#
# ids - a vector of taxi zone ids to iterate over
# ... - extra arguments passed to run_simulation_for_start_zone()
#
# returns a data_frame
run_simulation = function(ids = start_taxi_zone_ids, ...) {
  map(ids, function(id) {
    run_simulation_for_start_zone(start_taxi_zone_id = id, ...)
  }) %>% bind_rows()
}

# default list of all zone ids to run simulation on
start_taxi_zone_ids = query("
  SELECT start_taxi_zone_id
  FROM total_trips_by_start_zone
  GROUP BY start_taxi_zone_id
  HAVING SUM(CASE WHEN type = 'taxi' THEN count ELSE 0 END) >= 100
    AND SUM(CASE WHEN type = 'citibike' THEN count ELSE 0 END) >= 100
  ORDER BY start_taxi_zone_id
")$start_taxi_zone_id

# mapping of zone ids to names and boroughs
zones = read_csv("taxi_zone_names.csv")

# Run the simulation for trips from a single start zone
#
# start_taxi_zone_id - integer zone id
# filters - optional list of quosures to filter trips before running simulation
# dimensions - character vector defining bucket dimensions
# min_observations - integer minimum number of taxi and Citi Bike observations per bucket
# n_samples - integer number of samples to draw for each bucket
#
# returns a data_frame
#
# see below for example usage
run_simulation_for_start_zone = function(start_taxi_zone_id,
                                         filters = NULL,
                                         dimensions = c("end_taxi_zone_id", "time_bucket"),
                                         min_observations = 5,
                                         n_samples = 10000) {
  filename = paste0("../data/weekday_trips_start_zone_", start_taxi_zone_id, ".csv")

  trips = read_csv(filename)

  if (!is.null(filters)) trips = filter(trips, !!!filters)

  if ("month" %in% dimensions) {
    trips = mutate(trips, month = floor_date(date, unit = "month"))
  }

  if ("wday" %in% dimensions) {
    trips = mutate(trips, wday = wday(date))
  }

  if ("time_bucket" %in% dimensions) {
    trips = mutate(trips,
      time_bucket = case_when(
        hour_of_day %in% 8:10 ~ "morning",
        hour_of_day %in% 11:15 ~ "midday",
        hour_of_day %in% 16:18 ~ "afternoon",
        hour_of_day %in% 19:21 ~ "evening",
        TRUE ~ "other"
      )
    )
  }

  simulations_to_run = trips %>%
    group_by_at(dimensions) %>%
    summarize(
      taxi_trips = sum(type == "taxi"),
      citi_trips = sum(type == "citibike")
    ) %>%
    ungroup() %>%
    filter(taxi_trips >= min_observations, citi_trips >= min_observations)

  if (nrow(simulations_to_run) == 0) return(data_frame())

  map(1:nrow(simulations_to_run), function(i) {
    simulation = simulations_to_run[i, ]

    simulation_trips = trips %>%
      inner_join(simulation, by = dimensions) %>%
      select(-taxi_trips, -citi_trips)

    simulation_trips_taxi = filter(simulation_trips, type == "taxi")
    simulation_trips_citi = filter(simulation_trips, type == "citibike")

    results = data_frame(
      taxi = sample(simulation_trips_taxi$duration_in_seconds, n_samples, replace = TRUE),
      citi = sample(simulation_trips_citi$duration_in_seconds, n_samples, replace = TRUE),
      taxi_wins = taxi < citi,
      winning_margin = abs(taxi - citi)
    )

    taxi_wins = sum(results$taxi_wins)

    winning_margins = results %>%
      group_by(taxi_wins) %>%
      summarize(
        avg = mean(winning_margin),
        median = median(winning_margin)
      ) %>%
      ungroup()

    simulation %>%
      mutate(
        start_taxi_zone_id = start_taxi_zone_id,
        taxi_win_rate = taxi_wins / n_samples,
        taxi_mean = mean(simulation_trips_taxi$duration_in_seconds),
        citi_mean = mean(simulation_trips_citi$duration_in_seconds),
        taxi_median = median(simulation_trips_taxi$duration_in_seconds),
        citi_median = median(simulation_trips_citi$duration_in_seconds),
        taxi_avg_winning_margin = ifelse(taxi_wins == 0, NA, filter(winning_margins, taxi_wins)$avg),
        citi_avg_winning_margin = ifelse(taxi_wins == n_samples, NA, filter(winning_margins, !taxi_wins)$avg),
        start_zone = filter(zones, gid == start_taxi_zone_id)$zone,
        start_borough = filter(zones, gid == start_taxi_zone_id)$borough,
        end_zone = filter(zones, gid == simulation$end_taxi_zone_id)$zone,
        end_borough = filter(zones, gid == simulation$end_taxi_zone_id)$borough
      )
  }) %>% bind_rows()
}
