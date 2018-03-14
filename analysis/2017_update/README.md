# 2017 Analysis Update

Scripts in support of the 2017 update of this post:

http://toddwschneider.com/posts/analyzing-1-1-billion-nyc-taxi-and-uber-trips-with-a-vengeance/#update-2017

These scripts assume that you have the full taxi and FHV datasets loaded, but if you don't want to go through the time-consuming process of loading the whole dataset, the `data/` subfolder includes the following pre-computed files:

1. `data/daily_trips_with_location_id.csv.gz` - the number of daily pickups in each taxi zone for each car type (Yellow taxi, Green taxi, Uber, Lyft, Juno, Via, Gett, Other)
2. `data/daily_trips_by_geography.csv` - the number of daily pickups in each aggregated geography (citywide total, Manhattan, Manhattan CBD, airports, outer boroughs excluding airports)
3. `data/uber_vs_lyft_carto_data.csv` - Uber vs. Lyft market share throughout 2017, before, during, and after the JFK taxi strike on Jan 28, 2017
4. `data/jfk_hourly_pickups.csv` - hourly pickups at JFK airport for each car type in Q1 2017
5. `data/election_results_by_taxi_zone.csv` - 2016 US presidential election vote counts by taxi zone. Note that election districts do not overlap exactly with taxi zones, so taxi zone aggregates are estimates
6. `data/taxi_zones_simple.csv` - lookup file to convert location IDs to neighborhood names
