require 'time'

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

    # Create a `Thing` entity for SensorThings API based on this station
    # and add custom properties.
    def build_thing(properties)
      @entity_factory.new_thing({
        name:        @metadata[:name],
        description: @metadata[:description],
        properties:  properties
      })
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
    def observation_type_for(property, ontology)
      ontology.observation_type(property) ||
      "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Observation"
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
      Time.strptime(time + "#{zone_offset}", "%F %T%z").utc
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
    #              still include headers.
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
              'Accept-Encoding' => '',
              'Range'           => "bytes=#{offset}-"
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
          headers: { 'Range' => '' }
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
  end
end