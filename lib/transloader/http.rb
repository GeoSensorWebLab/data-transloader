require 'base64'
require 'deep_merge'
require 'net/http'
require 'uri'

module Transloader
  # Wrapper class for delegating HTTP request/response logic to either
  # the stdlib 'net/http' or an external library.
  class HTTP
    include SemanticLogger::Loggable

    def initialize(options = {})
      @default_options = {
        body: nil,
        headers: {
          "User-Agent": "GeoSensorWebLab/data-transloader/#{Transloader.version}"
        },
        open_timeout: 30,
        read_timeout: 30
      }

      if options[:auth]
        @default_options[:headers][:"Authorization"] = "Basic #{Base64.strict_encode64(options[:auth])}"
      end
    end

    # For GET requests.
    # options:
    #  uri: URL to get
    #  headers: Hash of HTTP headers to send with request
    def get(options = {})
      options = default_options(options)
      options[:uri] = URI(options[:uri])
      request = Net::HTTP::Get.new(options[:uri])
      send_request(request, options)
    end

    # For HEAD requests.
    # options:
    #  uri: URL to get
    #  headers: Hash of HTTP headers to send with request
    def head(options = {})
      options = default_options(options)
      options[:uri] = URI(options[:uri])
      request = Net::HTTP::Head.new(options[:uri])
      send_request(request, options)
    end

    # For PATCH requests.
    # options:
    #  body: Request body to send to server
    #  uri: URL to get
    #  headers: Hash of HTTP headers to send with request
    def patch(options = {})
      options = default_options(options)
      options[:uri] = URI(options[:uri])
      request = Net::HTTP::Patch.new(options[:uri])
      send_request(request, options)
    end

    # For POST requests.
    # options:
    #  body: Request body to send to server
    #  uri: URL to get
    #  headers: Hash of HTTP headers to send with request
    def post(options = {})
      options = default_options(options)
      options[:uri] = URI(options[:uri])
      request = Net::HTTP::Post.new(options[:uri])
      send_request(request, options)
    end

    # For PUT requests.
    # options:
    #  body: Request body to send to server
    #  uri: URL to get
    #  headers: Hash of HTTP headers to send with request
    def put(options = {})
      options = default_options(options)
      options[:uri] = URI(options[:uri])
      request = Net::HTTP::Put.new(options[:uri])
      send_request(request, options)
    end

    private

    # Define the default options for the requests. Options passed into
    # the API will overwrite the default options.
    def default_options(options)
      @default_options.deep_merge(options)
    end

    def log_response(response)
      logger.debug "HTTP/#{response.http_version} #{response.message} #{response.code}"
      response.each do |header, value|
        logger.debug "#{header}: #{value}"
      end
      logger.debug response.body
      logger.debug ''
    end

    # Most of the requests have the same methods, so we can re-use 
    # them here.
    def send_request(request, options)
      options[:headers].each do |header, value|
        request[header.to_s] = value
      end

      request.body = options[:body]

      # Log output of request
      logger.debug "#{request.method} #{request.uri}"
      logger.debug request.to_hash.inspect
      logger.debug ''

      response = Net::HTTP.start(options[:uri].hostname, options[:uri].port, {
        use_ssl: (options[:uri].scheme == "https")
      }) do |http|
        http.open_timeout = options[:open_timeout]
        http.read_timeout = options[:read_timeout]
        http.request(request)
      end
      log_response(response)
      response

    end

    # All of these methods are CLASS methods, not instance methods.
    class << self
      # For GET requests.
      # options:
      #  uri: URL to get
      #  headers: Hash of HTTP headers to send with request
      def get(options = {})
        options = default_options(options)
        options[:uri] = URI(options[:uri])
        request = Net::HTTP::Get.new(options[:uri])
        send_request(request, options)
      end

      # For HEAD requests.
      # options:
      #  uri: URL to get
      #  headers: Hash of HTTP headers to send with request
      def head(options = {})
        options = default_options(options)
        options[:uri] = URI(options[:uri])
        request = Net::HTTP::Head.new(options[:uri])
        send_request(request, options)
      end

      # For PATCH requests.
      # options:
      #  body: Request body to send to server
      #  uri: URL to get
      #  headers: Hash of HTTP headers to send with request
      def patch(options = {})
        options = default_options(options)
        options[:uri] = URI(options[:uri])
        request = Net::HTTP::Patch.new(options[:uri])
        send_request(request, options)
      end

      # For POST requests.
      # options:
      #  body: Request body to send to server
      #  uri: URL to get
      #  headers: Hash of HTTP headers to send with request
      def post(options = {})
        options = default_options(options)
        options[:uri] = URI(options[:uri])
        request = Net::HTTP::Post.new(options[:uri])
        send_request(request, options)
      end

      # For PUT requests.
      # options:
      #  body: Request body to send to server
      #  uri: URL to get
      #  headers: Hash of HTTP headers to send with request
      def put(options = {})
        options = default_options(options)
        options[:uri] = URI(options[:uri])
        request = Net::HTTP::Put.new(options[:uri])
        send_request(request, options)
      end

      private

      # Define the default options for the requests. Options passed into
      # the API will overwrite the default options.
      def default_options(options)
        {
          body: nil,
          headers: {
            "User-Agent": "GeoSensorWebLab/data-transloader/#{Transloader.version}"
          },
          open_timeout: 30,
          read_timeout: 30
        }.deep_merge(options)
      end

      def log_response(response)
        logger.debug "HTTP/#{response.http_version} #{response.message} #{response.code}"
        response.each do |header, value|
          logger.debug "#{header}: #{value}"
        end
        logger.debug response.body
        logger.debug ''
      end

      # Most of the requests have the same methods, so we can re-use 
      # them here.
      def send_request(request, options)
        options[:headers].each do |header, value|
          request[header.to_s] = value
        end

        request.body = options[:body]

        # Log output of request
        logger.debug "#{request.method} #{request.uri}"
        logger.debug request.to_hash.inspect
        logger.debug ''

        response = Net::HTTP.start(options[:uri].hostname, options[:uri].port, {
          use_ssl: (options[:uri].scheme == "https")
        }) do |http|
          http.open_timeout = options[:open_timeout]
          http.read_timeout = options[:read_timeout]
          http.request(request)
        end
        log_response(response)
        response

      end
    end
  end
end