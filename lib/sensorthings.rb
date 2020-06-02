require "semantic_logger"

require "sensorthings/entity"
require "sensorthings/entity_factory"
require "sensorthings/datastream"
require "sensorthings/exceptions"
require "sensorthings/location"
require "sensorthings/observation"
require "sensorthings/observed_property"
require "sensorthings/sensor"
require "sensorthings/thing"
require "sensorthings/version"
require "transloader/http"

# Library for uploading data to SensorThings API over HTTP/HTTPS.
# Classes will try to re-use existing matching entities on the remote
# service if possible, and changes to some properties will update remote
# entities in-place.
module SensorThings
end
