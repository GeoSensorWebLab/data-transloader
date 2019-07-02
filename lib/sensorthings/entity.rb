require 'json'
require 'net/http'
require 'uri'

module SensorThings
  # Base class for SensorThings API entities. Do not instantiate directly,
  # instead use subclasses.
  class Entity
    include SemanticLogger::Loggable

    # These accessors are inherited by subclasses.
    attr_accessor :attributes, :id, :link

    def initialize(attributes)
      @attributes = attributes
    end

    # Override URI join function to handle OData style parenthesis properly
    def join_uris(*uris)
      uris.reduce("") do |memo, uri|
        if memo.to_s[-1] == ")"
          URI.join(memo.to_s + '/', uri)
        else
          URI.join(memo, uri)
        end
      end
    end

    # Subclasses must override this.
    def to_json
      JSON.generate({})
    end

    def get(url)
      request = Net::HTTP::Get.new(url)

      # Log output of request
      logger.debug "#{request.method} #{request.uri}"
      logger.debug ''

      uri = URI(url)
      response = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.open_timeout = 1800
        http.read_timeout = 1800
        http.request(request)
      end

      # Force encoding on response body
      # See https://bugs.ruby-lang.org/issues/2567
      response.body = response.body.force_encoding('UTF-8')

      # Log output of response
      logger.debug "HTTP/#{response.http_version} #{response.message} #{response.code}"
      response.each do |header, value|
        logger.debug "#{header}: #{value}"
      end
      logger.debug response.body
      logger.debug ''

      response
    end

    def patch_to_path(url)
      request = Net::HTTP::Patch.new(url)
      response = send_request(url, request)

      if response.class != Net::HTTPOK && response.class != Net::HTTPNoContent
        raise "Error: Could not PATCH entity. #{url}\n #{response.body}\n #{request.body}"
        exit 2
      end
    end

    def post_to_path(url)
      request = Net::HTTP::Post.new(url)
      response = send_request(url, request)

      if response.class != Net::HTTPCreated
        raise "Error: Could not POST entity. #{url}\n #{response.body}\n #{request.body}"
      end

      entity = nil

      # Some STA implementations return an empty body, others return the
      # entity. If the response body is nil, then we need to fetch the 
      # entity to get its true self link and id.
      if response.body.empty?
        if response['Location'].empty?
          raise "Cannot retrieve entity details without body or Location"
        end

        response = get(response['Location'])
        entity = JSON.parse(response.body)
      else
        entity = JSON.parse(response.body)
      end

      @link = entity['@iot.selfLink']
      @id = entity['@iot.id']
    end

    def put_to_path(url)
      request = Net::HTTP::Put.new(url)
      response = send_request(url, request)

      if response.class != Net::HTTPCreated
        raise "Error: Could not PUT entity. #{url}\n #{response.body}\n #{request.body}"
        exit 2
      end

      @link = response['Location']
      @id = JSON.parse(response.body)['@iot.id']
    end

    # PATCH/POST/PUT all use the same behaviour for sending data, so it
    # can be re-used in this method.
    def send_request(url, request)
      request.body = self.to_json
      request.content_type = 'application/json'

      # Log output of request
      logger.debug "#{request.method} #{request.uri}"
      logger.debug "Content-Type: #{request.content_type}"
      logger.debug self.to_json
      logger.debug ''

      uri = URI(url)
      response = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.open_timeout = 1800
        http.read_timeout = 1800
        http.request(request)
      end

      # Force encoding on response body
      # See https://bugs.ruby-lang.org/issues/2567
      response.body = response.body.force_encoding('UTF-8')

      # Log output of response
      logger.debug "HTTP/#{response.http_version} #{response.message} #{response.code}"
      response.each do |header, value|
        logger.debug "#{header}: #{value}"
      end
      logger.debug response.body
      logger.debug ''

      response
    end
  end
end
