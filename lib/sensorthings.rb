require "semantic_logger"

require_relative "sensorthings/entity"
require_relative "sensorthings/entity_factory"
require_relative "sensorthings/datastream"
require_relative "sensorthings/exceptions"
require_relative "sensorthings/location"
require_relative "sensorthings/observation"
require_relative "sensorthings/observed_property"
require_relative "sensorthings/sensor"
require_relative "sensorthings/thing"
require_relative "sensorthings/version"
require_relative "transloader/http"

# Library for uploading data to SensorThings API over HTTP/HTTPS.
# Classes will try to re-use existing matching entities on the remote
# service if possible, and changes to some properties will update remote
# entities in-place.
module SensorThings
end
