require 'rubygems'
require 'csv'
require 'rest-client'
require 'active_support'
require 'active_support/core_ext'

def parse_number(string)
  string.to_s.squish.gsub(/[,%-]/, "").presence&.to_f
end

# TLC monthly reports
tlc_monthly_data_url = "http://www.nyc.gov/html/tlc/downloads/csv/data_reports_monthly_indicators.csv"
tlc_monthly_data = CSV.parse(RestClient.get(tlc_monthly_data_url))

CSV.open("tlc_monthly_data.csv", "wb") do |csv|
  tlc_monthly_data.drop(1).each do |row|
    csv << [
      Date.strptime(row[0], "%Y-%m").end_of_month,
      row[1].downcase.gsub("-", " ").squish.gsub(" ", "_"),
      parse_number(row[2])&.to_i,
      parse_number(row[3])&.to_i,
      parse_number(row[4])&.to_i,
      parse_number(row[5])&.to_i,
      parse_number(row[6])&.to_i,
      parse_number(row[7]),
      parse_number(row[8]),
      parse_number(row[9]),
      parse_number(row[10]),
      parse_number(row[11]),
      parse_number(row[12]),
      parse_number(row[13])&.to_i
    ]
  end
end

# FHV weekly data (includes Uber and Lyft)
fhv_weekly_data_url = "http://data.cityofnewyork.us/api/views/2v9c-2k7f/rows.csv?accessType=DOWNLOAD"
fhv = CSV.parse(RestClient.get(fhv_weekly_data_url))

CSV.open("fhv_weekly_data.csv", "wb") do |csv|
  fhv.drop(1).each do |row|
    dba_string = row[3]

    dba = if dba_string =~ /^uber/i
      "uber"
    elsif dba_string =~ /^lyft/i
      "lyft"
    else
      "other"
    end

    csv << (row + [dba])
  end
end

# create tables and import data
system(%{psql nyc-taxi-data -f create_statistics_tables.sql})
system(%{cat tlc_monthly_data.csv | psql nyc-taxi-data -c "COPY tlc_monthly_reports FROM stdin CSV;"})
system(%{cat fhv_weekly_data.csv | psql nyc-taxi-data -c "COPY fhv_weekly_reports FROM stdin CSV;"})
