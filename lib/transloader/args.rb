require 'date'

module Transloader
  class Args
    attr_reader :cache, :date, :object, :source, :station, :verb

    def initialize(args)
      if args.count == 0
        puts "ERROR: Missing arguments"
        print_help
        exit 1
      end

      if args.include?("--help")
        print_help
        exit 0
      end

      verb_arg = args.shift

      if verb_arg.casecmp?("get")
        @verb = :get
      elsif verb_arg.casecmp?("put")
        @verb = :put
      else
        puts "ERROR: invalid verb"
        print_help
        exit 1
      end

      object_arg = args.shift

      if object_arg.casecmp?("metadata")
        @object = :metadata
      elsif object_arg.casecmp?("observations")
        @object = :observations
      else
        puts "ERROR: invalid target"
        print_help
        exit 1
      end

      while args.count > 0
        arg = args.shift
        case arg
        when "--source"
          @source = args.shift
        when "--station"
          @station = args.shift
        when "--cache"
          @cache = args.shift
        when "--date"
          @date = args.shift
        else
          puts "ERROR: unknown argument: #{arg}"
          print_help
          exit 1
        end
      end

      validate_args
    end

    def validate_args
      validate_verb
      validate_object
      validate_source
      validate_cache
      validate_date
    end

    def validate_cache
      if @cache.nil? || !Dir.exist?(@cache)
        puts "Error: cache directory does not exist"
        print_help
        exit 1
      end
    end

    def validate_date
      if @verb == :put && @object == :observations
        begin
          DateTime.iso8601(@date)
        rescue ArgumentError
          if @date.nil? || !@date.casecmp?("latest")
            puts "Error: Invalid date `#{@date}`"
            print_help
            exit 1
          end
        end
      end
    end

    def validate_object
      if @object.nil?
        puts "Error: Unknown target"
        print_help
        exit 1
      end
    end

    def validate_source
      case @source
      when "environment_canada"
        # okay
      else
        puts "Error: invalid source '#{@source}'"
        print_help
        exit 1
      end
    end

    def validate_verb
      if @verb.nil?
        puts "Error: Unknown verb"
        print_help
        exit 1
      end
    end

    def print_help
      puts "Usage: transload <get|put> <metadata|observations> <arguments>"
      puts "--source SOURCE             Data source; allowed: 'environment_canada'"
      puts "--station STATION           Station identifier"
      puts "--cache CACHE               Path for filesystem storage cache"
      puts "--date DATE                 ISO8601 date for 'put observations'. Also supports 'latest'"
      puts "--help                      Print this help message"
    end
  end
end
