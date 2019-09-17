# Custom Exception classes for the SensorThings API module.
# This allows for more granular catching of errors instead of the 
# generic "RuntimeError".
module SensorThings

  # Generic parent error class for this module
  class Error < StandardError; end

  # Exception when a PATCH request fails
  class HTTPError < Error

    attr_reader :response

    # Store the response in the error for re-use
    def initialize(response, msg = nil)
      @response = response
      super(msg)
    end
  end
end