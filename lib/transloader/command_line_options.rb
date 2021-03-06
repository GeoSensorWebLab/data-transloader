require "uri"

module Transloader
  # Specify which command line options are passed from the command line
  # to the library, as well as the descriptive help messages.
  class CommandLineOptions
    attr_reader :allowed, :blocked, :database_url, :data_paths,
                :data_urls, :date, :destination, :http_auth,
                :http_headers, :keys, :overwrite, :provider,
                :station_id, :user_id, :value

    # Set default values
    def initialize
      @allowed      = nil
      @blocked      = nil
      @database_url = nil
      @data_paths   = []
      @data_urls    = []
      @date         = nil
      @destination  = nil
      @http_auth    = nil
      @http_headers = []
      @keys         = []
      @overwrite    = false
      @provider     = nil
      @station_id   = nil
      @user_id      = nil
      @value        = nil
    end

    def define_options(parser)
      parser.banner = "Usage: transloader <verb> <noun> [options]"
      parser.separator "See Data Transloader DOCUMENTATION for detailed usage instructions."
      parser.separator ""
      parser.separator "Available subcommands:"
      parser.separator "transload get metadata [options]"
      parser.separator "transload put metadata [options]"
      parser.separator "transload set metadata [options]"
      parser.separator "transload show metadata [options]"
      parser.separator "transload get observations [options]"
      parser.separator "transload put observations [options]"
      parser.separator ""
      parser.separator "Specific options:"

      allowed_option(parser)
      blocked_option(parser)
      database_url_option(parser)
      data_path_option(parser)
      data_url_option(parser)
      date_interval_option(parser)
      destination_option(parser)
      http_auth_option(parser)
      http_header_option(parser)
      key_option(parser)
      overwrite_option(parser)
      provider_option(parser)
      station_id_option(parser)
      user_id_option(parser)
      value_option(parser)

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

    # Allowed source property list
    def allowed_option(parser)
      parser.on("--allowed [A,B,C]",
        <<-EOH
        Comma separated list of exclusive properties for upload.
        Exact matches only. Use quotes for spaces/special characters.
        EOH
        ) do |value|
        @allowed = value.split(",").map { |i| i.strip }
      end
    end

    # Blocked source property list
    def blocked_option(parser)
      parser.on("--blocked [D,E,F]",
        <<-EOH
        Comma separated list of properties to omit on upload.
        Exact matches only. Use quotes for spaces/special characters.
        EOH
        ) do |value|
        @blocked = value.split(",").map { |i| i.strip }
      end
    end

    # Parse Database URL
    def database_url_option(parser)
      parser.on("--database_url [URL]",
        "URL for file or database for local storage.") do |value|
        @database_url = value
      end
    end

    # Parse local Data Paths.
    # Specifying multiple times will add each item to an array.
    def data_path_option(parser)
      parser.on("--data_path [PATH]",
        "Data file to parse for data/metadata.") do |value|
        @data_paths.push(value)

        if !File.exists?(value)
          puts %Q[ERROR: Path "#{value}" is not a valid file.]
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
        @data_urls.push(value)

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
        @date = value

        begin
          Transloader::TimeInterval.new(value)
        rescue
          puts %Q[ERROR: Date Interval "#{value}" is not a valid ISO8601 <start>/<end> time interval.]
          puts parser
          exit 1
        end
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

    # Specify BASIC username:password for requests
    def http_auth_option(parser)
      parser.on("--user <USERNAME>:<PASSWORD>",
        "Specify HTTP BASIC username:password for requests.") do |value|
        @http_auth = value
      end
    end

    # Specify additional HTTP headers for requests
    def http_header_option(parser)
      parser.on("--header \"Header: Value\"",
        "Specify additional HTTP headers for requests.") do |value|
        @http_headers.push(value)
      end
    end

    # Specify key for metadata show method
    def key_option(parser)
      parser.on("--key <KEY>",
        "Specify key to lookup in metadata. Use multiple times for sub-keys.") do |value|
        @keys.push(value)
      end
    end

    # Overwrite option.
    # If true, downloaded metadata will overwrite any existing metadata.
    def overwrite_option(parser)
      parser.on("--overwrite",
        "Ovewrite existing metadata if true (default false)") do |value|
        @overwrite = true
      end
    end

    # Parser Data Provider.
    # Determines which Station class is used.
    def provider_option(parser)
      parser.on("--provider [PROVIDER]",
        "Data provider to use: environment_canada, data_garrison, campbell_scientific, klrs_h_energy, klrs_h_weather.") do |value|
        @provider = value

        if !["environment_canada", "data_garrison",
             "campbell_scientific", "klrs_h_energy",
             "klrs_h_weather"].include?(value)
          puts %Q[ERROR: Provider "#{value}" is not a valid provider.]
          puts parser
          exit 1
        end
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

    # Specify value for metadata set method
    def value_option(parser)
      parser.on("--value <VALUE>",
        "Specify value to set in metadata (with --key).") do |value|
        @value = value
      end
    end
  end
end
