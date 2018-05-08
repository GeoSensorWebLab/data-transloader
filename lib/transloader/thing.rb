require 'json'
require 'net/http'
require 'uri'

module Transloader
  class Thing

    attr_accessor :attributes, :description, :id, :link, :name, :properties

    def initialize(attributes)
      @attributes = attributes
      @name = attributes[:name]
      @description = attributes[:description]
      @properties = attributes[:properties]
    end

    def to_json
      JSON.generate({
        name: @name,
        description: @description,
        properties: @properties
      })
    end

    def upload_to(url)
      upload_url = URI.join(url, "Things")

      request = Net::HTTP::Post.new(upload_url)
      request.body = self.to_json
      request.content_type = 'application/json'

      # Log output of request
      puts "#{request.method} #{request.uri}"
      puts "Content-Type: #{request.content_type}"
      puts self.to_json
      puts ''

      response = Net::HTTP.start(upload_url.hostname, upload_url.port) do |http|
        http.request(request)
      end

      # Log output of response
      puts "#{response.http_version} #{response.message} #{response.code}"
      response.each do |header, value|
        puts "#{header}: #{value}"
      end
      puts response.body
      puts ''

      # Force encoding on response body
      # See https://bugs.ruby-lang.org/issues/2567
      response.body = response.body.force_encoding('UTF-8')

      if response.class != Net::HTTPCreated
        raise "Error: Could not upload entity. #{upload_url}\n #{response.body}\n #{request.body}"
        exit 2
      end

      @link = response['Location']
      @id = JSON.parse(response.body)['@iot.id']
    end
  end
end
