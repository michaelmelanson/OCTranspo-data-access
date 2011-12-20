require 'sinatra'
require 'csv'
require 'json'

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
$stops = CSV.table("data/google_transit/stops.txt")


get '/stops/nearest' do
  
  # Parse the GET parameters
  latitude   = params[:latitude].to_f
  longitude  = params[:longitude].to_f
  range      = (params[:range] || 0).to_i.clamp(MIN_RANGE, MAX_RANGE)
  max_results = (params[:max_results] || 0).to_i.clamp(1, MAX_MAX_RESULTS)
    
  # Find the distances of each stop to this location
  stop_distances = []
  
  index = 0   # we use this to keep track of the stop's index in $stops, for faster lookup
  $stops.each do |stop|
    
    # We use the Euclidian distance here, which is close enough to the Great Circle distance, over small scales, 
    # for our purposes
    dist = distance(latitude, longitude, stop[:stop_lat], stop[:stop_lon])
    
    # We only care about it if it's within the range the user specified
    next if dist > range
    
    puts "    It's within range"
    # Add it to the list of stops
    stop_distances << { 
      :stop_index => index,
      :distance => dist
    }
    
    index += 1
  end
  
  # Sort it by the distance to the location
  stop_distances.sort_by! { |x| x[:distance] }
  
  # Get a list of the stops closest to the location
  nearest_stops = stop_distances.take(max_results).map { |s| $stops[s[:stop_index]] }

  # Send it back to the user as JSON data
  content_type :json
  nearest_stops.map(&:to_hash).to_json
end