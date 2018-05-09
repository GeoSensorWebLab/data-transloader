require 'json'
require 'net/http'
require 'uri'

module Transloader
  # Base class for SensorThings API entities. Do not instantiate directly,
  # instead use subclasses.
  class Entity
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
      puts "#{request.method} #{request.uri}"
      puts ''

      response = Net::HTTP.start(url.hostname, url.port) do |http|
        http.request(request)
      end

      # Force encoding on response body
      # See https://bugs.ruby-lang.org/issues/2567
      response.body = response.body.force_encoding('UTF-8')

      # Log output of response
      puts "HTTP/#{response.http_version} #{response.message} #{response.code}"
      response.each do |header, value|
        puts "#{header}: #{value}"
      end
      puts response.body
      puts ''

      response
    end

    def patch_to_path(url)
      request = Net::HTTP::Patch.new(url)
      request.body = self.to_json
      request.content_type = 'application/json'

      # Log output of request
      puts "#{request.method} #{request.uri}"
      puts "Content-Type: #{request.content_type}"
      puts self.to_json
      puts ''

      response = Net::HTTP.start(url.hostname, url.port) do |http|
        http.request(request)
      end

      # Force encoding on response body
      # See https://bugs.ruby-lang.org/issues/2567
      response.body = response.body.force_encoding('UTF-8')

      # Log output of response
      puts "HTTP/#{response.http_version} #{response.message} #{response.code}"
      response.each do |header, value|
        puts "#{header}: #{value}"
      end
      puts response.body
      puts ''

      if response.class != Net::HTTPOK && response.class != Net::HTTPNoContent
        raise "Error: Could not PATCH entity. #{url}\n #{response.body}\n #{request.body}"
        exit 2
      end
    end

    def post_to_path(url)
      request = Net::HTTP::Post.new(url)
      request.body = self.to_json
      request.content_type = 'application/json'

      # Log output of request
      puts "#{request.method} #{request.uri}"
      puts "Content-Type: #{request.content_type}"
      puts self.to_json
      puts ''

      response = Net::HTTP.start(url.hostname, url.port) do |http|
        http.request(request)
      end

      # Force encoding on response body
      # See https://bugs.ruby-lang.org/issues/2567
      response.body = response.body.force_encoding('UTF-8')

      # Log output of response
      puts "HTTP/#{response.http_version} #{response.message} #{response.code}"
      response.each do |header, value|
        puts "#{header}: #{value}"
      end
      puts response.body
      puts ''

      if response.class != Net::HTTPCreated
        raise "Error: Could not POST entity. #{url}\n #{response.body}\n #{request.body}"
        exit 2
      end

      @link = response['Location']
      @id = JSON.parse(response.body)['@iot.id']
    end
  end
end