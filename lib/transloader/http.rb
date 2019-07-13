require 'http'
require 'net/http'
require 'uri'

module Transloader
  # Wrapper class for delegating HTTP request/response logic to either
  # the stdlib 'net/http' or an external library.
  class HTTP
    include SemanticLogger::Loggable

    # All of these methods are CLASS methods, not instance methods.
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

        # Log output of request
        logger.debug "#{request.method} #{request.uri}"
        logger.debug ''

        response = Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.open_timeout = options[:open_timeout]
          http.read_timeout = options[:read_timeout]
          http.request(request)
        end
        log_response(response)
        response
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

        # Log output of request
        logger.debug "#{request.method} #{request.uri}"
        logger.debug ''

        response = Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.open_timeout = options[:open_timeout]
          http.read_timeout = options[:read_timeout]
          http.request(request)
        end
        log_response(response)
        response
      end

      def patch(options = {})
        options = default_options(options)

        uri = URI(options[:uri])
        request = Net::HTTP::Patch.new(uri)

        options[:headers].each do |header, value|
          request[header.to_s] = value
        end

        request.body = options[:body]

        # Log output of request
        logger.debug "#{request.method} #{request.uri}"
        logger.debug ''

        response = Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.open_timeout = options[:open_timeout]
          http.read_timeout = options[:read_timeout]
          http.request(request)
        end
        log_response(response)
        response
      end

      def post(options = {})
        options = default_options(options)

        uri = URI(options[:uri])
        request = Net::HTTP::Post.new(uri)

        options[:headers].each do |header, value|
          request[header.to_s] = value
        end

        request.body = options[:body]

        # Log output of request
        logger.debug "#{request.method} #{request.uri}"
        logger.debug ''

        response = Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.open_timeout = options[:open_timeout]
          http.read_timeout = options[:read_timeout]
          http.request(request)
        end
        log_response(response)
        response
      end

      def put(options = {})
        options = default_options(options)

        uri = URI(options[:uri])
        request = Net::HTTP::Put.new(uri)

        options[:headers].each do |header, value|
          request[header.to_s] = value
        end

        request.body = options[:body]

        # Log output of request
        logger.debug "#{request.method} #{request.uri}"
        logger.debug ''

        response = Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.open_timeout = options[:open_timeout]
          http.read_timeout = options[:read_timeout]
          http.request(request)
        end
        log_response(response)
        response
      end

      private

      # Define the default options for the requests. Options passed into
      # the API will overwrite the default options.
      def default_options(options)
        {
          headers: {},
          open_timeout: 30,
          read_timeout: 30
        }.merge(options)
      end

      def log_response(response)
        logger.debug "HTTP/#{response.http_version} #{response.message} #{response.code}"
        response.each do |header, value|
          logger.debug "#{header}: #{value}"
        end
        logger.debug response.body
        logger.debug ''
      end
    end
  end
end