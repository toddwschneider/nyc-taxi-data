# Taxi vs. Citi Bike Comparison Analysis

Code in support of the post ["When are Citi Bikes Faster than Taxis in New York City?"](http://toddwschneider.com/posts/taxi-vs-citi-bike-nyc/)

## Instructions

##### 0. Prerequisites

Set up and import data for [nyc-taxi-data](https://github.com/toddwschneider/nyc-taxi-data) and [nyc-citibike-data](https://github.com/toddwschneider/nyc-citibike-data) repos. You don't need all of the supporting analysis tables, but you do need the `trips` table from each database. If you want to make things go faster, you could load only data since July 2016, or download some of the processed data from Amazon S3 (see below).

##### 1. Set up data

`./set_up_comparison_data.sh`

This creates a new `taxi_citibike_trips` table in the `nyc-taxi-data` database and populates it with a subset of trips from each of the taxi and Citi Bike databases.

##### 2. Dump data to .csv

`./write_data_to_csv.sh`

This dumps the records from the `taxi_citibike_trips` table into multiple .csv files, one file for each starting zone (neighborhood). Having multiple .csv files helps avoid running up against memory limits in R, but if you have enough memory, you could modify the code to dump into a single .csv and import that into R, or you could connect R directly to the database and pull in data via SQL queries.

##### 3. Analysis scripts

Within the `analysis/` folder:

- `analysis_queries.sql`
- `crosstown_queries.sql` does some calculations to help define "crosstown" and "uptown" routes after adjusting for [Manhattan's 29 degree tilt](http://www.charlespetzold.com/etc/AvenuesOfManhattan/)
- `monte_carlo_simulation.R` defines the simulation
- `simulation_analysis.R` runs various simulations and analyzes the results
- `traffic_analysis.R` runs some other analysis of long-term traffic trends for taxis and Citi Bikes

## Partial data on Amazon S3

If you don't want to go through the hassle of loading the entire taxi and Citi Bike datasets, the raw data used for the Monte Carlo simulation—the output of `write_data_to_csv.sql`—is available for download from a requester pays Amazon S3 bucket:

https://s3.amazonaws.com/nyc-taxi-vs-citibike-comparison-data/weekday_trips.zip

[See here](http://docs.aws.amazon.com/AmazonS3/latest/dev/ObjectsinRequesterPaysBuckets.html) for instructions on how to download from a requester pays S3 bucket. The data is 1.3 GB zipped, 12 GB uncompressed.

Note that the dataset available on S3 is only the subset of taxi and Citi Bike trips used in the various Monte Carlo simulations, and other analysis code in this repo (e.g. traffic over time) depends on loading the taxi/Citi Bike datasets in their entirety.

## Data filtering

I applied filters to both datasets to try to make them as comparable as possible, and also to try to maximize the percentage of Citi Bike trips in particular where the rider was likely trying to get from point A to point B relatively quickly.

For both datasets, I filtered to weekday trips only, excluding holidays. Traffic patterns are different on weekdays and weekends, and I was afraid that weekend Citi Bike rides would often be primarily for leisure, not efficient transportation.

Within the Citi Bike dataset, I removed trips by daily use customers, keeping only the trips made by annual subscribers. Subscribers are more likely to be regular commuters, while daily users are more likely to be tourists who, even during the week, might ride more for the scenery than for an efficient commute.

Within the taxi dataset, I restricted to trips that picked up and dropped off within areas served by the Citi Bike system, i.e. taxi trips where taking a Citi Bike would have been a viable option. Taxis can pick up or drop off anywhere, while Citi Bikes must be picked up and dropped off at one of the 600+ fixed station locations. The current [Citi Bike station map](https://member.citibikenyc.com/map/) covers Manhattan south of 110th Street, the stretch of Brooklyn from Greenpoint to Park Slope, and Long Island City in Queens.

Starting in July 2016, perhaps owing to [privacy concerns](http://toddwschneider.com/posts/analyzing-1-1-billion-nyc-taxi-and-uber-trips-with-a-vengeance/#data-privacy-concerns), the TLC stopped providing precise latitude and longitude coordinates for every taxi trip. Instead, the TLC provides the pickup and drop off taxi zone for each trip, where the 263 zones—[see here](https://toddwschneider.carto.com/viz/2961a180-ffb1-11e6-a29f-0e233c30368f/public_map) for a map—roughly correspond to the neighborhoods of the city.

80% of all taxi trips in the filtered dataset started and ended within one of the 82 zones that includes a Citi Bike station. Of the 20% that did not, about a third involved LaGuardia or JFK airports. Harlem and Astoria were the Citi Bike-less residential neighborhoods with the most taxi trips, though they are part of Citi Bike's [expansion plans](https://www.dnainfo.com/new-york/20170727/astoria/citi-bike-stations-update-queens-cb1-bike-share-sept-oct-2017).

I removed trips from both datasets that started and ended within the same zone. For Citi Bikes, these trips often started and ended at the same station, which is clearly an indication that the rider wasn't trying to get from point A to point B quickly, and even in cases where they started and ended at different stations, it seems likely that many of those trips might not be for commuting purposes. When considering trips confined to a single zone, it also seems more likely that the average taxi and Citi Bike trip distances might differ by a larger magnitude than trips that span multiple zones.

For most analyses, I used the most recent year of available data, July 1, 2016 to June 30, 2017, but for some I included all data since July 2013 to see how the taxi vs. Citi Bike calculus might have changed over time. For a sense of scale, taxis made 135 million total trips in the past year, while Citi Bikes made 17 million.

## Taxi zones

One of the biggest caveats of this taxi vs. Citi Bike analysis arises because the taxi data since July 2016 does not provide specific coordinates, only starting and ending zones. The analysis makes the assumption that the distribution of trips within zones is the same for both taxis and Citi Bikes, which might not be true. For example, are taxi trips from Union Square to Midtown East on average the same distance as Citi Bike trips? My guess is that in most cases it's close enough, but we don't really know.

![stations and zones](https://user-images.githubusercontent.com/70271/30783529-50a087b8-a112-11e7-8558-edc5745e7f68.png)

The overlay map above of taxi zones and Citi Bike stations shows that Citi Bike stations are fairly evenly distributed throughout most of the taxi zones, especially in Manhattan. There are four particular zones—Bushwick South, Crown Heights North, and Prospect Heights in Brooklyn, and Sunnyside in Queens—where the Citi Bike stations are clustered on one side of the zone, which makes it more likely that there's a significant difference in average distances within those zones, but less than 1% of the trips in the dataset start or end in one of those areas, so they should not have a meaningful effect on any aggregate results.

## Why use a Monte Carlo simulation instead of an empirical calculation?

If your buckets are small enough, it's fine to do a full empirical calculation using R's `expand.grid()` to compare every taxi trip within a single bucket to every Citi Bike trips within the same bucket. But if you have a bucket with a large number of trips, say 50,000 taxi trips and 10,000 Citi Bike trips, then the full cross product contains 500 million rows, which might cause memory problems in R. In fact I tried the empirical calculation at some point, and it produced very similar results to the Monte Carlo simulation, but the empirical calculation couldn't handle buckets with large number of trips, so I stuck with the Monte Carlo approach.

I also think Monte Carlo method is easier to implement than the empirical calculation, though that might be personal preference.

## Questions/issues/contact

todd@toddwschneider.com, or open a GitHub issue
