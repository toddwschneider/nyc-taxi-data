DROP TABLE IF EXISTS tlc_monthly_reports;
DROP TABLE IF EXISTS fhv_monthly_reports;

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
