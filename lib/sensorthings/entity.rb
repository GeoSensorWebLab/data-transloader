require 'json'
require 'uri'

module SensorThings
  # Base class for SensorThings API entities. Do not instantiate 
  # directly, instead use subclasses.
  class Entity
    include SemanticLogger::Loggable

    # These accessors are inherited by subclasses.
    attr_accessor :attributes, :id, :link

    def initialize(attributes, http_client)
      @attributes  = attributes
      @http_client = http_client

      warn_long_attributes(@attributes)
    end

    # Override URI join function to handle OData style parenthesis 
    # properly
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
      response = @http_client.get({
        uri:          url,
        open_timeout: 1800,
        read_timeout: 1800
      })

      response.body = fix_encoding(response.body)
      response
    end

    def patch_to_path(url)
      response = send_request(url, :PATCH)

      if response.code != "200" && response.code != "204"
        raise HTTPError.new(response, "Error: Could not PATCH entity.")
      end
    end

    def post_to_path(url)
      response = send_request(url, :POST)

      if response.code != "201"
        raise HTTPError.new(response, "Error: Could not POST entity.")
      end

      entity = nil

      # Some STA implementations return an empty body, others return the
      # entity. If the response body is nil, then we need to fetch the 
      # entity to get its true self link and id.
      if response.body.empty?
        if response['Location'].empty?
          raise HTTPError.new(response, "Cannot retrieve entity details without body or Location")
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
      response = send_request(url, :PUT)

      if response.code != "201"
        raise HTTPError.new(response, "Error: Could not PUT entity.")
      end

      @link = response['Location']
      @id   = JSON.parse(response.body)['@iot.id']
    end

    # PATCH/POST/PUT all use the same behaviour for sending data, so it
    # can be re-used in this method.
    def send_request(url, method_name)
      options = {
        body: self.to_json,
        headers: {
          "Content-Type" => "application/json"
        },
        uri: url
      }

      response = case method_name
        when :PATCH
          @http_client.patch(options)
        when :POST
          @http_client.post(options)
        when :PUT
          @http_client.put(options)
        else
          raise SensorThings::Error.new("Unknown HTTP method: #{method_name}")
      end

      response.body = fix_encoding(response.body)
      response
    end

    private

    # Force encoding on response body
    # See https://bugs.ruby-lang.org/issues/2567
    def fix_encoding(body)
      body.force_encoding('UTF-8')
    end

    # Print out warning for attributes that may be too long for some
    # SensorThings API implementations.
    def warn_long_attributes(attributes)
      attributes.each do |key, value|
        if value.is_a?(String) && value.length > 255
          logger.warn %Q[The value for the "#{key}" attribute is longer than 255 characters, which may cause an error with some SensorThings API implementations.]
        end
      end
    end
  end
end
