# Custom Exception classes for the Transloader module.
# This allows for more granular catching of errors instead of the 
# generic "RuntimeError".
module Transloader
  # Generic parent error class for this module
  class Error < StandardError; end

  # Exceptions related to usage of the embedded Ontology
  class OntologyError < Error; end

  # Exception when an HTTP request fails
  class HTTPError < Error

    attr_reader :response

    # Store the response in the error for re-use
    def initialize(response, msg = nil)
      @response = response
      super(msg)
    end
  end
end