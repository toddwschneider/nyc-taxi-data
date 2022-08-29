ALTER TABLE fhv_trips
DELETE WHERE filename = splitByChar('/', {filename:String})[-1];

INSERT INTO fhv_trips (
  hvfhs_license_num, company, dispatching_base_num, pickup_datetime,
  dropoff_datetime, pickup_location_id, dropoff_location_id, pickup_borough,
  dropoff_borough, legacy_shared_ride, filename
)
SELECT
  multiIf(
    trimBoth(upper(dispatching_base_num)) IN ('B02907', 'B02908', 'B02914', 'B03035'), 'HV0002',
    trimBoth(upper(dispatching_base_num)) IN ('B02510', 'B02844'), 'HV0005',
    trimBoth(upper(dispatching_base_num)) IN ('B02395', 'B02404', 'B02512', 'B02598', 'B02617', 'B02682', 'B02764', 'B02765', 'B02835', 'B02836', 'B02864', 'B02865', 'B02866', 'B02867', 'B02869', 'B02870', 'B02871', 'B02872', 'B02875', 'B02876', 'B02877', 'B02878', 'B02879', 'B02880', 'B02882', 'B02883', 'B02884', 'B02887', 'B02888', 'B02889'), 'HV0003',
    trimBoth(upper(dispatching_base_num)) IN ('B02800', 'B03136'), 'HV0004',
    'other'
  ),
  multiIf(
    trimBoth(upper(dispatching_base_num)) IN ('B02907', 'B02908', 'B02914', 'B03035'), 'juno',
    trimBoth(upper(dispatching_base_num)) IN ('B02510', 'B02844'), 'lyft',
    trimBoth(upper(dispatching_base_num)) IN ('B02395', 'B02404', 'B02512', 'B02598', 'B02617', 'B02682', 'B02764', 'B02765', 'B02835', 'B02836', 'B02864', 'B02865', 'B02866', 'B02867', 'B02869', 'B02870', 'B02871', 'B02872', 'B02875', 'B02876', 'B02877', 'B02878', 'B02879', 'B02880', 'B02882', 'B02883', 'B02884', 'B02887', 'B02888', 'B02889'), 'uber',
    trimBoth(upper(dispatching_base_num)) IN ('B02800', 'B03136'), 'via',
    'other'
  ),
  trimBoth(upper(dispatching_base_num)),
  pickup_datetime,
  dropOff_datetime,
  PUlocationID,
  DOlocationID,
  multiIf(
    PUlocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'Bronx'), 'Bronx',
    PUlocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'Brooklyn'), 'Brooklyn',
    PUlocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'Manhattan'), 'Manhattan',
    PUlocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'Queens'), 'Queens',
    PUlocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'Staten Island'), 'Staten Island',
    PUlocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'EWR'), 'EWR',
    null
  ),
  multiIf(
    DOlocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'Bronx'), 'Bronx',
    DOlocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'Brooklyn'), 'Brooklyn',
    DOlocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'Manhattan'), 'Manhattan',
    DOlocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'Queens'), 'Queens',
    DOlocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'Staten Island'), 'Staten Island',
    DOlocationID IN (SELECT location_id FROM taxi_zones WHERE borough = 'EWR'), 'EWR',
    null
  ),
  SR_Flag,
  splitByChar('/', {filename:String})[-1]
FROM file({filename:String});
