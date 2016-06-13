require 'rubygems'
require 'csv'
require 'roo'
require 'rest-client'
require 'active_support'
require 'active_support/core_ext'

# yellow taxi data
yellow_monthly_data_url = "http://www.nyc.gov/html/tlc/downloads/csv/data_reports_monthly_indicators_yellow.csv"
yellow_monthly_data = CSV.parse(RestClient.get(yellow_monthly_data_url))
yellow_monthly_data.shift

CSV.open("yellow_monthly_data.csv", "wb") do |csv|
  yellow_monthly_data.each do |row|
    csv << [
      Date.strptime(row[0], "%y-%B").end_of_month,
      row[1].gsub(",", "").to_i,
      row[2].gsub(",", "").to_i,
      row[3].gsub(",", "").to_i,
      row[4].gsub(",", "").to_i,
      row[5].gsub(",", "").to_i,
      row[6].to_f,
      row[7].to_f,
      row[8].to_f,
      row[9].to_f,
      row[10].presence.try(:to_f),
      row[11].gsub("%", "").to_f
    ]
  end
end

# FHV weekly data (includes Uber and Lyft)
fhv_weekly_data_url = "http://www.nyc.gov/html/tlc/downloads/excel/data_reports_weekly_fhv_base.xlsx"
fhv = Roo::Spreadsheet.open(fhv_weekly_data_url)

header_row_index = (fhv.first_row..fhv.last_row).detect do |i|
  fhv.row(i).compact.size > 5
end
header_row = fhv.row(header_row_index)

column_indexes_to_select = header_row.map.with_index do |name, idx|
  idx if name.present?
end.compact

data_row_range = (header_row_index + 1)..fhv.last_row

CSV.open("fhv_weekly_data.csv", "wb") do |csv|
  data_row_range.each do |i|
    row = fhv.row(i)

    values = column_indexes_to_select.map { |col_idx| row[col_idx] }

    dba_string = values[3]

    values << if dba_string =~ /^uber/i
      "uber"
    elsif dba_string =~ /^lyft/i
      "lyft"
    else
      "other"
    end

    csv << values
  end
end

# create tables and import data
system(%{psql nyc-taxi-data -f create_statistics_tables.sql})
system(%{cat yellow_monthly_data.csv | psql nyc-taxi-data -c "COPY yellow_monthly_reports FROM stdin CSV;"})
system(%{cat fhv_weekly_data.csv | psql nyc-taxi-data -c "COPY fhv_weekly_reports FROM stdin CSV;"})
