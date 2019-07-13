require 'http'
require 'net/http'
require 'uri'

module Transloader
  # Wrapper class for delegating HTTP request/response logic to either
  # the stdlib 'net/http' or an external library.
  class HTTP
    class << self
      # For GET requests.
      # options:
      #  uri: URL to get
      #  headers: Hash of HTTP headers to send with request
      def get(options = {})
        options = default_options(options)

        uri = URI(options[:uri])
        request = Net::HTTP::Get.new(uri)

        options[:headers].each do |header, value|
          request[header.to_s] = value
        end

        Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.request(request)
        end
      end

      # For HEAD requests.
      # options:
      #  uri: URL to get
      #  headers: Hash of HTTP headers to send with request
      def head(options = {})
        options = default_options(options)

        uri = URI(options[:uri])
        request = Net::HTTP::Head.new(uri)

        options[:headers].each do |header, value|
          request[header.to_s] = value
        end

        Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.request(request)
        end
      end

      def patch(options = {})
      end

      def post(options = {})
      end

      def put(options = {})
      end

      private

      # Define the default options for the requests. Options passed into
      # the API will overwrite the default options.
      def default_options(options)
        {
          headers: {}
        }.merge(options)
      end
    end
  end
end