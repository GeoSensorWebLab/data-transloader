require "time"

module Transloader
  # Shared methods for multiple station classes
  module StationMethods
    include SemanticLogger::Loggable

    # Create a `Location` entity for SensorThings API based on this
    # station's metadata.
    def build_location
      @entity_factory.new_location({
        name:         @metadata[:name],
        description:  @metadata[:description],
        encodingType: "application/vnd.geo+json",
        location: {
          type:        "Point",
          coordinates: [@metadata[:longitude].to_f, @metadata[:latitude].to_f]
        }
      })
    end

    # Create an `Observed Property` entity for SensorThings API based
    # on this station's metadata and this datastream's name. A lookup
    # in the Ontology will be performed, and any match will be used
    # for the entity attributes. If no Ontology match is found, then
    # a warning will be printed and the original source property name
    # will be used.
    def build_observed_property(property_name)
      entity = ontology.observed_property(property_name)

      if entity.nil?
        logger.warn "No Observed Property found in Ontology for #{self.class::PROVIDER_ID}:#{property_name}"
        entity = {
          name:        property_name,
          definition:  "http://example.org/#{property_name}",
          description: property_name
        }
      end

      @entity_factory.new_observed_property(entity)
    end

    # Create a `Sensor` entity for SensorThings API based on this
    # station's metadata. If `sensor_description` is nil, then
    # `sensor_name` will be re-used.
    def build_sensor(sensor_name, sensor_description = nil)
      @entity_factory.new_sensor({
        name:        sensor_name,
        description: sensor_description || sensor_name,
        # This encoding type is a lie, because there are only two types in
        # the spec and none apply here. Implementations are strict about those
        # two types, so we have to pretend.
        # More discussion on specification that could change this:
        # https://github.com/opengeospatial/sensorthings/issues/39
        encodingType: "application/pdf",
        metadata:     @metadata[:procedure] || "http://example.org/unknown"
      })
    end

    # Create a `Thing` entity for SensorThings API based on this station
    # and add custom properties.
    def build_thing(properties)
      @entity_factory.new_thing({
        name:        @metadata[:name],
        description: @metadata[:description],
        properties:  properties
      })
    end

    # Converts an array of observations (from loading a file/http file)
    # to an array of observations for the DataStore class. Observations
    # must have a property that matches in the `datastream_names` set.
    # Array is automatically flattened and compacted.
    #
    # * observations: Array of input observations
    # * datastream_names: Set of datastream names that observations must
    #                     match.
    def convert_to_store_observations(observations, datastream_names)
      # Use a Hash to store matches between Observation property names
      # and datastream names, as this is faster than doing a "find" for
      # the matches. A "find" is still necessary to make the first
      # match. If no match to a datastream name is found, then "nil" is
      # stored.
      matches = {}

      observations.flat_map do |observation_set|
        # observation:
        # * name (property)
        # * reading (result)
        observation_set[1].collect do |observation|
          # Check if match has already been made
          if !matches.key?(observation[:name])
            matching_datastream = datastream_names.find do |datastream|
              observation[:name].include?(datastream)
            end

            matches[observation[:name]] = matching_datastream
          end

          if !matches[observation[:name]].nil?
            # This observation property name has been matched to a
            # datastream name.
            {
              timestamp: Time.parse(observation_set[0]),
              result:    observation[:reading],
              property:  observation[:name]
            }
          else
            # This observation property name has failed to match any
            # datastream name.
            nil
          end
        end
      end.compact
    end

    # Generate a Set containing the names from the datastreams.
    # Useful for fast lookups. Assumes names are under the `:name` key.
    def datastream_names_set(datastreams)
      datastreams.reduce(Set.new()) do |memo, datastream|
        memo.add(datastream[:name])
        memo
      end
    end

    # Use the observation_type to convert result to float, int, or
    # string. This is used to use the most appropriate data type when
    # converting results to JSON.
    def coerce_result(result, observation_type)
      logger.trace %Q[Coercing #{result} for #{observation_type}]
      case observation_type
      when "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement"
        result.to_f
      when "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_CountObservation"
        result.to_i
      else # OM_Observation, any other type
        result
      end
    end

    # Filter the datastreams array by only keeping the items in the
    # `allowed` array. If `allowed` is empty or nil, then remove items
    # that are in the `blocked` array.
    def filter_datastreams(datastreams, allowed, blocked)
      if allowed
        datastreams.select do |datastream|
          allowed.include?(datastream[:name])
        end
      elsif blocked
        datastreams.select do |datastream|
          !blocked.include?(datastream[:name])
        end
      else
        datastreams
      end
    end

    # Reduce the set of observations to those in `interval` string.
    def filter_observations(observations, interval)
      time_interval = Transloader::TimeInterval.new(interval)
      puts "Applying interval filter: #{observations.length}"
      observations = observations.filter do |observation|
        timestamp = observation[0]
        timestamp >= time_interval.start && timestamp <= time_interval.end
      end
      puts "Reduced to #{observations.length}"
      observations
    end

    # For an array of symbols returned from the HTTP SensorThings API
    # module, print out how many entities were created, reused, updated,
    # or unavailable.
    def log_response_types(responses)
      logger.info "Entities unavailable for upload: #{responses.count(:unavailable)}"
      logger.info "Entities created for upload: #{responses.count(:created)}"
      logger.info "Entities updated for upload: #{responses.count(:updated)}"
      logger.info "Entities reused for upload: #{responses.count(:reused)}"
    end

    # Determine the O&M observation type for the Datastream based on
    # the Observed Property (see Transloader::Ontology)
    def observation_type_for(property)
      ontology.observation_type(property) ||
      "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Observation"
    end

    # Lazy-load the Ontology instance, waiting until it is actually
    # needed.
    def ontology
      @ontology ||= Ontology.new(self.class::PROVIDER_ID.to_sym)
    end

    # Convert Last-Modified header String to Time object.
    # If `time` is nil, nil is returned.
    def parse_last_modified(time)
      logger.trace %Q[Parsing HTTP Date "#{time}"]
      if time.nil?
        nil
      else
        Time.httpdate(time)
      end
    end

    # Convert a TOA5 timestamp String to a Time object.
    # An ISO8601 time zone offset (e.g. "-07:00") is required.
    def parse_toa5_timestamp(time, zone_offset)
      logger.trace %Q[Converting TOA5 timestamp "#{time}" with offset "#{zone_offset}"]
      Time.parse("#{time}#{zone_offset}").utc
    end

    # Download the file from `url`, using HTTP Ranges to try to download
    # from the `offset` in bytes. If `offset` is `nil`, then a full
    # download will be used.
    #
    # Will first issue a HEAD request for the Content-Length. If it is
    # less than `offset`, the file will be re-downloaded in full.
    # If it is equal to `offset`, no download will occur.
    # If it is greater than `offset`, then only the part of the file
    # after `offset` will be downloaded.
    #
    # This method does not handle parsing of the content, and the
    # implementer should be careful of partial files that may not fully
    # parse.
    #
    # Returns a Hash with the following data:
    # * body: String contents of response body
    # * last_modified: HTTP Last-Modified date for file (as `Time`)
    # * content_length: Full Content-Length of the file
    # * full_file: Boolean if file was completely downloaded and may
    #              still include data file CSV headers.
    def partial_download_url(url:, offset:)
      logger.info "Executing partial download for #{url}"
      logger.debug "Using byte offset #{offset}"

      body           = nil
      last_modified  = nil
      content_length = nil

      # Should the full remote file be downloaded, or should a partial
      # download be used instead?
      redownload = true

      # Check if file has already been downloaded, and if so use HTTP
      # Range header to only download the newest part of the file
      if offset
        # Download part of file; do not use gzip compression
        redownload = false

        # Check if content-length is smaller than expected
        # (offset). If it is smaller, that means the file was
        # probably truncated and the file should be re-downloaded
        # instead.
        response = @http_client.head(uri: url)

        last_modified  = parse_last_modified(response["Last-Modified"])
        content_length = response["Content-Length"].to_i

        if response["Content-Length"].to_i < offset
          logger.debug "Remote data file length is shorter than expected."
          redownload = true
        elsif response["Content-Length"].to_i == offset
          # Do nothing, no download necessary
          logger.debug "Remote file length unchanged, no download necessary."
        else
          # Do a partial GET
          response = @http_client.get({
            uri: url,
            headers: {
              "Accept-Encoding" => "",
              "Range"           => "bytes=#{offset}-"
            }
          })

          # 416 Requested Range Not Satisfiable
          if response.code == "416"
            logger.debug "No new data."
          elsif response.code == "206"
            logger.debug "Downloaded partial data."
            body           = response.body
            last_modified  = parse_last_modified(response["Last-Modified"])
            content_length = offset + body.length
          else
            # Other codes are probably errors
            logger.error "Error downloading partial data."
          end
        end
      end

      if redownload
        logger.debug "Downloading entire data file."
        # Download entire file; can use gzip compression
        response = @http_client.get(
          uri: url,
          headers: { "Range" => "" }
        )

        body           = response.body
        last_modified  = parse_last_modified(response["Last-Modified"])
        content_length = body.length
      end

      {
        body:           body,
        content_length: content_length,
        full_file:      redownload,
        last_modified:  last_modified
      }
    end

    # Convert Time object to ISO8601 string with fractional seconds
    def to_iso8601(time)
      time.utc.strftime("%FT%T.%LZ")
    end

    # Convert an ISO8601 string to an ISO8601 string in UTC.
    # e.g. "2019-08-19T17:00:00.000-0600" to "2019-08-19T23:00:00.000Z"
    def to_utc_iso8601(iso8601)
      to_iso8601(Time.iso8601(iso8601))
    end

    # Use the Ontology to look up the unit of measurement attributes.
    # If unavailable in the Ontology, then use `source_units`.
    def uom_for_datastream(datastream_name, source_units)
      # Look up UOM, observationType in ontology;
      # if nil, then use default attributes
      uom = ontology.unit_of_measurement(datastream_name)

      if uom.nil?
        logger.warn "No Unit of Measurement found in Ontology for #{self.class::PROVIDER_ID}:#{datastream_name} (#{source_units})"
        uom = {
          name:       source_units,
          symbol:     source_units,
          definition: ""
        }
      else
        uom
      end
    end
  end
end