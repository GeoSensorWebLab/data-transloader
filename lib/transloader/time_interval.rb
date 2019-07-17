require 'time'

module Transloader
  # Parse an ISO8601 time interval in "<start>/<end>" format into two 
  # `Time` instances.
  class TimeInterval
    attr_reader :end, :start

    class InvalidIntervalFormat < StandardError; end

    # Parse an ISO8601 interval time string.
    def initialize(interval)
      @start = nil
      @end   = nil

      dates = interval.split("/").collect do |time|
        Time.parse(time)
      end

      if dates.length != 2
        raise InvalidIntervalFormat, "Invalid ISO8601 interval format"
      end

      @start = dates[0]
      @end = dates[1]

      if @start > @end
        raise InvalidIntervalFormat, "Start date cannot be after end date"
      end
    end
  end
end
