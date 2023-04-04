# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

template_letter = File.read('form_letter.erb') # rubocop:disable Lint/UselessAssignment

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  clean_number = phone_number.gsub(/[^0-9]/, '')
  if clean_number.length > 11 && clean_number[0] != '1'
    '0000000000'
  elsif clean_number.length == 11 && clean_number[0] == '1'
    clean_number[1..-1]
  elsif clean_number.length == 10
    clean_number
  else
    '0000000000'
  end
end

def legislators_by_zipcode(zip) # rubocop:disable Metrics/MethodLength
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody'] # rubocop:disable Style/WordArray
    ).officials
  rescue # rubocop:disable Style/RescueStandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

reg_day_array = []
reg_hour_array = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phone_number = clean_phone_number(row[:homephone])

  # p row

  zipcode = clean_zipcode(row[:zipcode])

  reg_date = row[:regdate]
  reg_day = Time.strptime(reg_date, '%M/%d/%y %k:%M').strftime('%A')
  reg_day_array.push(reg_day)

  reg_hour = Time.strptime(reg_date, '%M/%d/%y %k:%M').strftime('%k')
  reg_hour_array.push(reg_hour)

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

most_common_day = reg_day_array.reduce(Hash.new(0)) do |hash, day|
  hash[day] += 1
  hash
end

most_common_hour = reg_hour_array.reduce(Hash.new(0)) do |hash, hour|
  hash[hour] += 1
  hash
end

puts 'Event Manager Initialized!'

puts "\nThe most common registration day is: #{most_common_day.max_by { |_k, v| v }[0]}"

puts "\nThe most common hour of registration is: #{most_common_hour.max_by { |_k, v| v }[0]}:00"
