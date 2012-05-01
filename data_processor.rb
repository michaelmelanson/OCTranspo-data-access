require 'ar-extensions'
require 'csv'
require './models.rb'
require 'logger'

ActiveRecord::Base.logger = Logger.new(STDOUT)


# Stop time data

index = 0

BATCH_SIZE = 50000

$batch = []

def dump_batch
  StopTime.transaction do
    $batch.each do |stop_time|
      StopTime.connection.execute "INSERT INTO stop_times(#{stop_time.to_hash.keys.map(&:to_s).join(', ')}) VALUES (#{stop_time.values.map(&:inspect).join(', ')})"
    end
  end
  
  $batch = []
end

CSV.foreach("data/google_transit/stop_times.txt", :headers => :first_row) do |stop_time|
  $batch << stop_time.to_hash
  index += 1
  
  if $batch.size >= BATCH_SIZE
    puts "Dumping data at index #{index}..."
    dump_batch    
  end
end

dump_batch


# Trip data

puts "Processing trip data..."

Trip.transaction do
  CSV.foreach("data/google_transit/trips.txt", :headers => :first_row) do |trip|
    Trip.create(:route_id => trip["route_id"],
                :service_id => trip["service_id"],
                :trip_id => trip["trip_id"],
                :trip_headsign => trip["trip_headsign"],
                :block_id => trip["block_id"])
  end
end