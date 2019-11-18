#!/usr/bin/env ruby -wKU
#
# A Ruby script for "cleaning" cassettes from the VCR library.
# 
# * Update `Content-Length` header to match body length for non-HEAD
#   requests
#
# USAGE: ruby cassette_cleaner.rb [-i] cassette.yml [-o output.yml]
# 
# * -i: update YAML file in-place (overwrite)
# * -o: output updated YAML in new file
# 
# These options are exclusive and cannot be used together.

require 'optparse'
require 'psych'

# Parse the command line options to adjust the output
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: cassette_cleaner.rb [-i] cassette.yml [-o output.yml]"

  opts.on("-i", "--inplace", "Update in-place") do
    options[:output] = nil
    options[:inplace] = true
  end

  opts.on("-o", "--output FILE", "Output to file") do |output|
    options[:inplace] = false
    options[:output] = output
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

input_file = ARGV[0]

if input_file.nil?
  puts "Input file required"
  exit 1
end

# Read in the input YAML cassette file
input_doc = Psych.load_file(input_file)

# Iterate over the HTTP interactions in the cassette, and filter out
# HEAD requests as we don't want to adjust the body size there.
input_doc["http_interactions"].select { |http|
  http["request"]["method"] != "head"
}.each { |http|
  # Get the *bytesize* of the body, and update the "Content-Length"
  # header to match. If there is no Content-Length header, skip.
  if http["response"]["headers"].keys.include?("Content-Length")
    body_size = http["response"]["body"]["string"].bytesize

    if http["response"]["headers"]["Content-Length"][0].to_i != body_size
      http["response"]["headers"]["Content-Length"] = [body_size.to_s]
      puts "Content-Length updated in cassette."
    else
      puts "Content-Length did not change."
    end
  end
}

if options[:output]
  outfile = File.new(options[:output], "w")
  Psych.dump(input_doc, outfile)
elsif options[:inplace]
  outfile = File.new(input_file, "w")
  Psych.dump(input_doc, outfile)
end
