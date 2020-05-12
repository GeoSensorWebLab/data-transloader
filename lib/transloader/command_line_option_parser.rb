require 'optparse'

module Transloader
  # Parse commands and options from ARGV.
  # 
  # Parsing of options is passed to CommandLineOptions class, and this
  # class will handle determining if the correct options have been
  # specified for the commands.
  class CommandLineOptionParser
    attr_reader :noun, :options, :parser, :verb

    # Parse an ARGV array into commands and options.
    # See CommandLineOptions for detailed usage of options.
    # Returns an array of [verb, noun, options].
    def parse(args)
      @options = parse_options!(args)
      verb     = parse_verb(args)
      noun     = parse_noun(args)

      validate(verb, noun, @options)
    end

    # Parse noun from args.
    # Noun may be `metadata` or `observations`; if missing then an 
    # error is raised.
    def parse_noun(args)
      if args.nil? || args[1].nil?
        puts "ERROR: Missing NOUN from arguments"
        puts @parser
        exit 1
      end

      case args[1]
      when /metadata/i
        return :metadata
      when /observations/i
        return :observations
      else
        puts "ERROR: Invalid second argument for NOUN"
        puts @parser
        exit 1
      end
    end

    # Return the options parsed from the args, and modify args in-place.
    # Note that the VERB and NOUN are not parsed, and left inside
    # `args` after `parse!`.
    def parse_options!(args)
      options = CommandLineOptions.new
      # Link the OptionParser from stdlib to the CommandLineOptions
      # instance, then parse the args into the options instance
      @parser = OptionParser.new do |parser|
        options.define_options(parser)
        parser.parse!(args)
      end
      options
    end

    # Parse verb from args.
    # Verb may be `get`, `put`, `set`, or `show`; if missing then an 
    # error is raised.
    def parse_verb(args)
      if args.nil? || args[0].nil?
        puts "ERROR: Missing VERB from arguments"
        puts @parser
        exit 1
      end

      case args[0]
      when /get/i
        return :get
      when /put/i
        return :put
      when /set/i
        return :set
      when /show/i
        return :show
      else
        puts "ERROR: Invalid first argument for VERB"
        puts @parser
        exit 1
      end
    end

    # Check that the `options` object has non-null and non-empty values
    # for attributes in `required_list` array.
    def require_options(options, required_list)
      required_list.each do |attribute|
        value = options.instance_variable_get("@#{attribute.to_s}")
        if value.nil? || (value.is_a?(Array) && value.empty?)
          puts "ERROR: Missing option: #{attribute.to_s}"
          puts @parser
          exit 1
        end
      end
    end

    # Validate that the required options are available for the verb and
    # noun. Exits if options are invalid, otherwise returns an array 
    # of [verb, noun, options].
    def validate(verb, noun, options)
      if verb == :get && noun == :metadata
        validate_get_metadata(options)
      elsif verb == :put && noun == :metadata
        validate_put_metadata(options)
      elsif verb == :set && noun == :metadata
        validate_set_metadata(options)
      elsif verb == :show && noun == :metadata
        validate_show_metadata(options)
      elsif verb == :get && noun == :observations
        validate_get_observations(options)
      elsif verb == :put && noun == :observations
        validate_put_observations(options)
      end

      [verb, noun, options]
    end

    # Options validation for "get metadata" command
    def validate_get_metadata(options)
      require_options(options, [:provider, :station_id, :cache])

      case options.provider
      when "campbell_scientific"
        require_options(options, [:data_urls])
      when "klrs_historical_energy", "klrs_historical_weather"
        require_options(options, [:data_paths])
      when "data_garrison"
        require_options(options, [:user_id])
      end
    end

    # Options validation for "get observations" command
    def validate_get_observations(options)
      require_options(options, [:provider, :station_id, :cache])

      case options.provider
      when "data_garrison"
        require_options(options, [:user_id])
      end
    end

    # Options validation for "put metadata" command
    def validate_put_metadata(options)
      require_options(options, [:provider, :station_id, :cache, :destination])

      case options.provider
      when "data_garrison"
        require_options(options, [:user_id])
      end
    end

    # Options validation for "put observations" command
    def validate_put_observations(options)
      require_options(options, [:provider, :station_id, :cache, :date, :destination])

      case options.provider
      when "data_garrison"
        require_options(options, [:user_id])
      end
    end

    # Options validation for "set metadata" command
    def validate_set_metadata(options)
      require_options(options, [:provider, :station_id, :cache, :keys, :value])

      case options.provider
      when "data_garrison"
        require_options(options, [:user_id])
      end
    end

    # Options validation for "show metadata" command
    def validate_show_metadata(options)
      require_options(options, [:provider, :station_id, :cache, :keys])

      case options.provider
      when "data_garrison"
        require_options(options, [:user_id])
      end
    end
  end
end
