require 'uri'

module Transloader
  class CommandLineOptions
    attr_reader :cache, :data_urls, :date_interval, :destination,
                :provider, :station_id, :user_id
    # Set default values
    def initialize
      @cache         = nil
      @data_url      = []
      @date_interval = nil
      @destination   = nil
      @provider      = nil
      @station_id    = nil
      @user_id       = nil
    end

    def define_options(parser)
      parser.banner = "Usage: transloader <verb> <noun> [options]"
      parser.separator "See Data Transloader DOCUMENTATION for detailed usage instructions."
      parser.separator ""
      parser.separator "Available subcommands:"
      parser.separator "transload get metadata [options]"
      parser.separator "transload put metadata [options]"
      parser.separator "transload get observations [options]"
      parser.separator "transload put observations [options]"
      parser.separator ""
      parser.separator "Specific options:"

      cache_directory_option(parser)
      data_url_option(parser)
      date_interval_option(parser)
      destination_option(parser)
      provider_option(parser)
      station_id_option(parser)      
      user_id_option(parser)

      parser.separator ""
      parser.separator "Common options:"

      parser.on_tail("-h", "--help", "Show this message") do
        puts parser
        exit
      end

      parser.on_tail("-V", "--version", "Show version") do
        puts Transloader.version
        exit
      end
    end

    # Parse Cache Directory Path
    def cache_directory_option(parser)
      parser.on("--cache [PATH]",
        "Path to data and metadata cache directory.") do |value|
        @cache = value
        
        if !Dir.exist?(value)
          puts %Q[ERROR: Directory "#{value}" does not exist.]
          puts parser
          exit 1
        end
      end
    end

    # Parse Data URLs.
    # Specifying multiple times will add each item to an array.
    def data_url_option(parser)
      parser.on("--data_url [URL]", 
        "Data URL to monitor for observations.") do |value|
        @data_url.push(value)
        
        if !(value =~ /\A#{URI::regexp(["http", "https"])}\z/)
          puts %Q[ERROR: Data URL "#{value}" is not a valid URL.]
          puts parser
          exit 1
        end
      end
    end

    # Parse ISO8601 Date Interval
    def date_interval_option(parser)
      parser.on("--date [DATE INTERVAL]",
        "ISO8601 date interval for observation upload.") do |value|
        @date_interval = value
        # TODO: Validate date interval
      end
    end

    # Parse SensorThings API Destination URL
    def destination_option(parser)
      parser.on("--destination [URL]",
        "SensorThings API Service base URL.") do |value|
        @destination = value
        
        if !(value =~ /\A#{URI::regexp(["http", "https"])}\z/)
          puts %Q[ERROR: Destination URL "#{value}" is not a valid URL.]
          puts parser
          exit 1
        end
      end
    end

    # Parser Data Provider.
    # Determines which Provider and Station classes are used.
    def provider_option(parser)
      parser.on("--provider [PROVIDER]",
        "Data provider to use: environment_canada, data_garrison, campbell_scientific.") do |value|
        @provider = value
        # TODO: Validate provider
      end
    end

    # Parse Station ID
    def station_id_option(parser)
      parser.on("--station_id [ID]",
        "Station ID (string or number) for ETL.") do |value|
        @station_id = value
      end
    end

    # Parse User ID
    def user_id_option(parser)
      parser.on("--user_id [ID]",
        "User ID (string or number) for ETL.") do |value|
        @user_id = value
      end
    end
  end
end
