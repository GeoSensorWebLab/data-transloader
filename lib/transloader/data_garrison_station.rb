require 'date'
require 'fileutils'
require 'json'
require 'nokogiri'

module Transloader
  class DataGarrisonStation

    attr_accessor :id, :properties, :provider

    def initialize(id, provider, properties)
      @id = id
      @provider = provider
      @properties = properties
      @user_id = @properties[:user_id]
      @metadata = {}
      @metadata_path = "#{@provider.cache_path}/#{DataGarrisonProvider::CACHE_DIRECTORY}/metadata/#{@user_id}/#{@id}.json"
      @observations_path = "#{@provider.cache_path}/#{DataGarrisonProvider::CACHE_DIRECTORY}/#{@user_id}/#{@id}"
    end

    # Parse metadata from the Provider properties and the SWOB-ML file for a
    # metadata hash.
    def download_metadata
      # TODO
    end

    # Load the metadata for a station.
    # If the station data is already cached, use that. If not, download and
    # save to a cache file.
    def get_metadata
    end

    # Connect to Environment Canada and download SWOB-ML
    def get_observations
    end

    # Return the XML document object for the SWOB-ML file. Will cache the
    # object.
    def observation_xml
    end

    # Upload metadata to SensorThings API
    def put_metadata(server_url)
    end

    # Upload station observations for `date` to the SensorThings API server at
    # `destination`. If `date` is "latest", then the most recent SWOB-ML file
    # is used.
    def put_observations(destination, date)
    end

    # Save the Station metadata to the metadata cache file
    def save_metadata
      # TODO
    end

    # Save the SWOB-ML file to file cache
    def save_observations
    end
  end
end
