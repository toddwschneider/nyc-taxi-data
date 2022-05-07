DROP TABLE IF EXISTS tlc_monthly_reports CASCADE;
DROP TABLE IF EXISTS fhv_monthly_reports CASCADE;

CREATE TABLE tlc_monthly_reports (
  month date,
  license_class text,
  trips_per_day integer,
  farebox_per_day integer,
  unique_drivers integer,
  unique_vehicles integer,
  vehicles_per_day integer,
  avg_days_vehicles_on_road numeric,
  avg_hours_per_day_per_vehicle numeric,
  avg_days_drivers_on_road numeric,
  avg_hours_per_day_per_driver numeric,
  avg_minutes_per_trip numeric,
  percent_trips_paid_with_credit_card numeric,
  trips_per_day_shared integer
);

CREATE UNIQUE INDEX ON tlc_monthly_reports (month, license_class);

CREATE TABLE fhv_monthly_reports (
  base_number text,
  base_name text,
  dba text,
  year integer,
  month integer,
  month_name text,
  total_dispatched_trips integer,
  total_dispatched_shared_trips integer,
  unique_dispatched_vehicles integer,
  dba_category text
);

CREATE UNIQUE INDEX ON fhv_monthly_reports (base_number, year, month);
CREATE INDEX ON fhv_monthly_reports (dba_category, year, month);

CREATE OR REPLACE VIEW tlc_monthly_reports_dashboard AS
SELECT
  *,
  unique_drivers * avg_days_drivers_on_road / extract(day FROM month) AS drivers_per_day,
  trips_per_day::numeric * extract(day FROM month) / unique_vehicles AS trips_per_vehicle,
  trips_per_day::numeric / vehicles_per_day AS trips_per_vehicle_per_day,
  trips_per_day::numeric * avg_minutes_per_trip / vehicles_per_day / 60 AS active_trip_hours_per_day,
  trips_per_day::numeric / vehicles_per_day / avg_hours_per_day_per_vehicle AS trips_per_vehicle_per_active_hour,
  trips_per_day::numeric / LAG(trips_per_day, 12) OVER (PARTITION BY license_class ORDER BY month) AS trips_growth_yoy,
  trips_per_day_shared::numeric / trips_per_day AS shared_trips_frac,
  farebox_per_day::numeric * extract(day FROM month) / unique_vehicles AS farebox_per_vehicle,
  farebox_per_day::numeric * extract(day FROM month) / unique_drivers AS farebox_per_driver,
  farebox_per_day::numeric / trips_per_day AS farebox_per_trip,
  farebox_per_day::numeric / (trips_per_day * avg_minutes_per_trip) AS farebox_per_minute,
  farebox_per_day::numeric / vehicles_per_day AS farebox_per_vehicle_daily,
  farebox_per_day::numeric / (unique_drivers * avg_days_drivers_on_road / extract(day FROM month)) AS farebox_per_driver_daily
FROM tlc_monthly_reports
ORDER BY license_class, month;

CREATE OR REPLACE VIEW fhv_monthly_reports_dashboard AS
WITH fhv_eom AS (
  SELECT
    *,
    date((year || '-' || month || '-01')::date + '1 month - 1 day'::interval) AS eo_month
  FROM fhv_monthly_reports
)
SELECT
  *,
  total_dispatched_trips::numeric / extract(day FROM eo_month) AS trips_per_day,
  total_dispatched_trips::numeric / unique_dispatched_vehicles AS trips_per_vehicle,
  total_dispatched_shared_trips::numeric / extract(day FROM eo_month) AS trips_per_day_shared,
  total_dispatched_shared_trips::numeric / total_dispatched_trips AS shared_trips_frac,
  total_dispatched_trips::numeric / LAG(total_dispatched_trips, 12) OVER (PARTITION BY dba_category ORDER BY eo_month) AS trips_growth_yoy
FROM fhv_eom
WHERE dba_category IN ('uber', 'lyft', 'via', 'juno', 'gett')
ORDER BY dba_category, eo_month;
