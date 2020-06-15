#!/usr/bin/env ruby
# Import observation data from a Postgres database and upload using the
# original method: one HTTP request at a time, using the GET/POST check
# for existing observation entities in SensorThings API.
#
# Requires local PostgreSQL instance, FROST running in a VM (with its
# own database), original KLRS energy usage data.
require "benchmark"
require "pry"

require_relative "../lib/transloader"

# Configuration
allowed_list = []
blocked_list = []
database_url = "postgres://localhost:5432/etl"
data_paths   = [
  "tmp/klrs-energy/gen_april.xls",
  "tmp/klrs-energy/gen_may.xls",
  "tmp/klrs-energy/gen_jun.xls",
  "tmp/klrs-energy/gen_july.xls",
  "tmp/klrs-energy/gen_aug.xls",
  "tmp/klrs-energy/gen_sep.xls"
]
destination = "http://192.168.33.77:8080/FROST-Server/v1.0/"
station_id  = "KLRS_Office_Energy"

# note: "2014-04-28T00:00:00Z/2014-04-29T00:00:00Z"
#       has 120935 observations
interval    = "2014-04-28T00:00:00Z/2014-04-29T00:00:00Z"

# Set up logger
SemanticLogger.default_level = :error
SemanticLogger.add_appender(io: $stdout)
$logger = SemanticLogger["Upload_001"]

# We want to test different methods for observation upload with this
# data set, so a sub-class works well.
class TestStation < Transloader::KLRSHistoricalEnergyStation
  def times
    @times ||= {}
  end

  # This re-creates the original method of uploading observations used
  # in v0.7.0.
  # Loads *all* the observations from the database into Ruby memory;
  # simple but very inefficient.
  def upload_observations(destination, interval, options = {})
    @times ||= {}
    time_interval = Transloader::TimeInterval.new(interval)
    observations  = []

    @times[:loading] = Benchmark.measure do
      observations = @store.get_data_in_range(time_interval.start, time_interval.end)
    end

    puts "Uploading Observations: #{observations.length}"

    # Filter datastreams, if applicable
    datastreams = []

    @times[:filter] = Benchmark.measure do
      datastreams = filter_datastreams(@metadata[:datastreams],
        options[:allowed], options[:blocked])
    end

    # Create hash map of observed properties to datastream URLs.
    # This is used to determine where Observation entities are
    # uploaded.
    datastream_hash = datastreams.reduce({}) do |memo, datastream|
      memo[datastream[:name]] = datastream
      memo
    end

    # Collect datastream names for comparisons.
    # A Set is used for fast lookups and unique values.
    datastream_names = datastream_names_set(datastreams)

    # Use ObservationPropertyCache to store matches between
    # Observation property names and datastream names, as this is
    # faster than doing a "find" for the matches on every Observation.
    property_matches = Transloader::ObservationPropertyCache.new(datastream_names)

    # Observation from DataStore:
    # * timestamp
    # * result
    # * property
    # * unit
    responses = []

    @times[:upload] = Benchmark.measure do
      responses = observations.collect do |observation|
        property_matches.cache_observation_property(observation[:property])
        datastream_name = property_matches[observation[:property]]
        datastream      = datastream_hash[datastream_name]

        if datastream.nil?
          $logger.warn "No datastream found for observation property: #{observation[:property]}"
          :unavailable
        else
          datastream_url = datastream[:'Datastream@iot.navigationLink']

          if datastream_url.nil?
            raise Error, "Datastream navigation URLs not cached"
          end

          phenomenonTime = Time.parse(observation[:timestamp]).iso8601(3)
          result = coerce_result(observation[:result], observation_type_for(datastream[:name]))

          observation = entity_factory.new_observation({
            phenomenonTime: phenomenonTime,
            result: result,
            resultTime: phenomenonTime
          })

          # Upload entity and parse response
          observation.upload_to(datastream_url)
        end
      end
    end
  end
end

# Back to testing script
http_client  = Transloader::HTTP.new()
fake_station = TestStation.new(
  database_url: database_url,
  http_client:  http_client,
  id:           station_id,
  properties:   { data_paths: data_paths }
)

#################
# Upload Metadata
#################
# Upload the station metadata to SensorThings API, in case the remote
# instance was reset.
upload_metadata_time = Benchmark.measure do
  fake_station.upload_metadata(destination)
end

#####################
# Upload Observations
#####################
fake_station.upload_observations(destination, interval, {
  allowed: nil,
  blocked: nil
})

puts "                 #{Benchmark::CAPTION}"
puts "upload metadata: #{upload_metadata_time}"
puts "loading:         #{fake_station.times[:loading]}"
puts "filter:          #{fake_station.times[:filter]}"
puts "upload obs:      #{fake_station.times[:upload]}"
