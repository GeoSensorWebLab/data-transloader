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
      verb = parse_verb(args)
      noun = parse_noun(args)

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
    # Verb may be `get` or `put`; if missing then an error is raised.
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
      else
        puts "ERROR: Invalid first argument for VERB"
        puts @parser
        exit 1
      end
    end

    # Validate that the required options are available for the verb and
    # noun. Exits if options are invalid, otherwise returns an array 
    # of [verb, noun, options].
    def validate(verb, noun, options)
      [verb, noun, options]
    end
  end
end
