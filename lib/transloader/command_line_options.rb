module Transloader
  class CommandLineOptions
    # Set default values
    def initialize
      @cache         = nil
      @data_urls     = []
      @date_interval = nil
      @destination   = nil
      @provider      = nil
      @station_id    = nil
      @user_id       = nil
    end

    def define_options(parser)
      parser.banner = "Usage: transloader <verb> <noun> [options]"
      parser.separator ""
      parser.separator "Available subcommands:"
      parser.separator "transload get metadata [options]"
      parser.separator "transload put metadata [options]"
      parser.separator "transload get observations [options]"
      parser.separator "transload put observations [options]"
      parser.separator ""
      parser.separator "Specific options:"

      # Parse Cache Directory Path
      parser.on("--cache PATH",
        "Path to data and metadata cache directory.") do |value|
        @cache = value
        # TODO: Validate path
      end
      
      # Parse Data URLs.
      # Specifying multiple times will add each item to an array.
      parser.on("--data-url [URL]", 
        "Data URL to monitor for observations.") do |value|
        @data_urls.push(value)
        # TODO: Validate URL
      end

      # Parse ISO8601 Date Interval
      parser.on("--date [DATE INTERVAL]",
        "ISO8601 date interval for observation upload.") do |value|
        @date_interval = value
        # TODO: Validate date interval
      end

      # Parse SensorThings API Destination URL
      parser.on("--destination [URL]",
        "SensorThings API Service base URL.") do |value|
        @destination = value
        # TODO: Validate URL
      end

      # Parser Data Provider.
      # Determines which Provider and Station classes are used.
      parser.on("--provider PROVIDER",
        "Data provider to use: environment_canada, data_garrison, campbell_scientific.") do |value|
        @provider = value
        # TODO: Validate provider
      end

      # Parse Station ID
      parser.on("--station-id ID",
        "Station ID (string or number) for ETL.") do |value|
        @station_id = value
      end

      # Parse User ID
      parser.on("--user-id [ID]",
        "User ID (string or number) for ETL.") do |value|
        @user_id = value
      end

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
  end
end
