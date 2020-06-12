#!/usr/bun/env ruby
# Import observation data from a Postgres database and upload using
# SensorThings API Batch extension. Adjust "$batch_size" for tweaks.
#
# Requires local PostgreSQL instance, FROST running in a VM (with its
# own database), original KLRS energy usage data.
require "benchmark"
require "pry"
require "ruby-progressbar"
require "securerandom"
require "uri"

require_relative "../lib/transloader"

# Configuration
allowed_list = []
$batch_size = 1000
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

  def upload_observations(destination, interval, options = {})
    @times ||= {}
    time_interval = Transloader::TimeInterval.new(interval)
    observations  = []

    @times[:loading] = Benchmark.measure do
      observations = @store.get_data_in_range(time_interval.start, time_interval.end)
    end

    puts "Loaded Observations: #{observations.length}"

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
    observation_queue = {}

    puts "Converting to Observation objects"
    @times[:prepare] = Benchmark.measure do
      progressbar = ProgressBar.create(total: observations.length, title: "Preparing observations", format: "%c/%u %a |%W| %e")

      # Convert from an Array to a Hash, where the keys are the parent
      # entity Datastream URLs, and the values are the Observation
      # entities to upload for that Datastream.
      observation_queue = observations.reduce({}) do |memo, observation|
        progressbar.increment

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

          # Converting to UTC first gets us the "Z" timezone, which works
          # better with FROST than "+00:00"
          phenomenonTime = Time.parse(observation[:timestamp]).utc.iso8601(3)
          result = coerce_result(observation[:result], observation_type_for(datastream[:name]))

          observation = entity_factory.new_observation({
            phenomenonTime: phenomenonTime,
            result:         result,
            resultTime:     phenomenonTime
          })

          memo[datastream_url] ||= []
          memo[datastream_url].push(observation)
        end
        memo
      end
    end

    puts "Datastream URLs: #{observation_queue.keys.length}"
    puts "Batch size: #{$batch_size}"

    @times[:upload] = Benchmark.measure do
      progressbar = ProgressBar.create(total: observations.length, title: "Sending POST requests", format: "%c/%u %a |%W| %e")

      # Process requests in batches
      observation_queue.each do |key, value|
        value.each_slice($batch_size) do |observations|
          batch_id = "batch_#{SecureRandom.uuid}"
          datastream_url = URI(key)

          batch_body = ""

          observations.each do |observation|
            entity_json = observation.to_json

            batch_body += <<~HEREDOC
            --#{batch_id}
            Content-Type: application/http
            Content-Transfer-Encoding: binary

            POST #{datastream_url.path}/Observations HTTP/1.1
            Host: #{datastream_url.host}:#{datastream_url.port}
            Content-Type: application/json
            Content-Length: #{entity_json.length}

            #{entity_json}
            HEREDOC
          end

          batch_body += "--#{batch_id}--"

          response = @http_client.post({
            body: batch_body,
            uri: "#{destination}$batch",
            headers: {
              "Content-Type" => "multipart/mixed;boundary=#{batch_id}"
            }
          })

          # TODO: Parse response to check success

          progressbar.progress += observations.length
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
puts "prepare obs:     #{fake_station.times[:prepare]}"
puts "upload obs:      #{fake_station.times[:upload]}"
