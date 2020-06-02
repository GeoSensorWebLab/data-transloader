require "time"

module Transloader
  # Parse an ISO8601 time interval in "<start>/<end>" format into two
  # `Time` instances.
  class TimeInterval
    include SemanticLogger::Loggable

    attr_reader :end, :start

    class InvalidIntervalFormat < StandardError; end

    # Parse an ISO8601 interval time string.
    def initialize(interval)
      logger.trace %Q[Creating interval from "#{interval}"]
      @start = nil
      @end   = nil

      dates = interval.split("/").collect do |time|
        Time.parse(time)
      end

      if dates.length != 2
        error = "Invalid ISO8601 interval format"
        logger.error error
        raise InvalidIntervalFormat, error
      end

      @start = dates[0]
      @end   = dates[1]

      if @start > @end
        error = "Start date cannot be after end date"
        logger.error error
        raise InvalidIntervalFormat, error
      end
    end
  end
end
