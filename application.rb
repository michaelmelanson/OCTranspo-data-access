require 'sinatra'
require 'csv'
require 'json'
require 'logger'

require './models.rb'

STDOUT.sync = true
STDERR.sync = true

ActiveRecord::Base.logger = Logger.new(STDOUT)

class Numeric

  # Clamps our value to the range [min, max]
  def clamp(min, max)
    return min if self < min
    return max if self > max
    self
  end
end

class Float
  
  # Assuming our value is measured in degrees, returns the corresponding value in radians
  def to_radians
    self * Math::PI / 180
  end
end

# Calculates the distance, in km, between two pairs of coordinates. Assumes that the Earth is a sphere, which is
# not true but close enough for our purposes.
#
# Source: http://www.movable-type.co.uk/scripts/latlong.html
# via Jake's mobile-bus-schedule
RADIUS_OF_EARTH_IN_KM = 6371
def distance(latA, lonA, latB, lonB)
  dLat = (latB-latA).to_radians
  dLon = (lonB-lonA).to_radians
  latA = latA.to_radians
  latB = latB.to_radians

  a = Math.sin(dLat/2) * Math.sin(dLat/2) +
      Math.sin(dLon/2) * Math.sin(dLon/2) * Math.cos(latA) * Math.cos(latB); 
  c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)); 

  RADIUS_OF_EARTH_IN_KM * c;
end

# Some constants
MIN_RANGE = 1
MAX_RANGE = 10
MAX_MAX_RESULTS = 50


# Load the data into memory
# TODO: Make the data_processor tool import these as well
puts "Loading stop data..."
$stops      = CSV.table("data/google_transit/stops.txt")

puts "Loading route data..."
$routes     = CSV.table("data/google_transit/routes.txt")

puts "Finished loading data"


# Some helper methods

def stop_ids_by_code(stop_code)
  stop_ids = []
  $stops.each do |stop|
    if stop[:stop_code].to_i == stop_code
      stop_ids << stop[:stop_id]
    end
  end

  return stop_ids
end



# Sinatra handlers

get '/stops/nearest' do
  
  # Parse the GET parameters
  latitude   = params[:latitude].to_f
  longitude  = params[:longitude].to_f
  range      = (params[:range] || 0).to_i.clamp(MIN_RANGE, MAX_RANGE)
  max_results = (params[:max_results] || 0).to_i.clamp(1, MAX_MAX_RESULTS)
    
  # Find the distances of each stop to this location
  stop_distances = []
  
  $stops.each do |stop|
    
    # We use the Euclidian distance here, which is close enough to the Great Circle distance, over small scales, 
    # for our purposes
    dist = distance(latitude, longitude, stop[:stop_lat], stop[:stop_lon])
    
    # We only care about it if it's within the range the user specified
    next if dist > range

    # Add it to the list of stops
    stop_distances << { 
      :stop => stop,
      :distance => dist
    }
  end
  
  # Sort it by the distance to the location
  stop_distances.sort_by! { |x| x[:distance] }
  
  # Get a list of the stops closest to the location
  nearest_stops = stop_distances.take(max_results).map { |s| s[:stop] }

  # Send it back to the user as JSON data
  content_type :json
  nearest_stops.map(&:to_hash).to_json
end


get '/stops' do
  startswith = params[:startswith]
  
  matches = []
  $stops.by_col[:stop_code].to_a.each do |stop_code|
    stop_code = stop_code.to_i
    if startswith.nil? or stop_code.to_s.starts_with? startswith
      matches.push(stop_code)
    end
  end
  
  content_type :json
  matches.to_json
end

get '/stop/:code' do
  code = params[:code].to_i
  
  # Get a list of all stop codes in the same order as $stops
  all_codes = $stops.by_col[:stop_code].to_a

  # Find the index of the code that the user is looking for
  stop_index = all_codes.index(code)
  
  if stop_index.nil?
    # We couldn't find it, so return 404 Not Found
    status 404
    return
  end
    
  
  # Return the stop data at that index
  content_type :json
  $stops[stop_index].to_hash.to_json
end


get '/stop/:stop_code/routes' do
  stop_code = params[:stop_code].to_i

  
  # Look up the stop code to get the stop ID
  stop_ids = stop_ids_by_code(stop_code)
  if stop_ids.empty?
    status 404
    return
  end
  
  puts "Stop IDs are: #{stop_ids}"

  # Get the trips that go to this stop
  stop_times = StopTime.find_all_by_stop_id(stop_ids)

  # What trip IDs do these correspond to?
  trip_ids = stop_times.map {|stop_time| stop_time.trip_id }

  # Get the matching trips
  matching_trips = Trip.find_all_by_trip_id(trip_ids)

  # Finally reduce it to a list of routes
  route_ids = matching_trips.map {|trip| trip[:route_id] }

  routes = []
  $routes.each do |route|
    if route_ids.include? route[:route_id]
      routes << route[:route_short_name]
    end
  end


  # Return it as JSON data
  content_type :json
  routes.uniq.to_json
end


get '/trips/by_stop/:stop_code' do
  stop_code = params[:stop_code].to_i
  
  # Look up the stop code to get the stop ID
  stop_ids = stop_ids_by_code(stop_code)
  if stop_ids.empty?
    status 404
    return
  end
  

  # Get the trips that go to this stop
  stop_times = StopTime.find_all_by_stop_id(stop_ids)

  # What trip IDs do these correspond to?
  trip_ids = stop_times.map {|stop_time| stop_time.trip_id }

  # Get the matching trips
  matching_trips = Trip.find_all_by_trip_id(trip_ids)

  response_data = {
    trips: matching_trips,
    times: stop_times
  }
    
  # Return it as JSON data
  content_type :json
  response_data.to_json
end
