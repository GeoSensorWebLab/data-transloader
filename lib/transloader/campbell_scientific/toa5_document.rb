require "csv"

module Transloader
  # Parse a TOA5 sensor data document and return the sensor metadata,
  # data columns (i.e. Observed Properties, units), and data rows
  # (Observations).
  #
  # If initialized with a complete TOA5 document, then the metadata and
  # column headers will be available. **If a partial document** is used,
  # then only the data rows will be available. The latter case means
  # that you will need to have the metadata and headers cached elsewhere
  # to create SensorThings API entities.
  #
  # `options` can be used to pass configuration to the CSV library, such
  # as the column separator or file encoding.
  #
  # Currently the class will check if the first cell is "TOA5" to
  # determine if it is a full document. If you try to access metadata
  # or headers while only providing a partial document, an Exception
  # **will** be raised.
  class TOA5Document
    def initialize(document, options = {})
      @document = document
      @options = options
    end

    # Returns the raw parsed CSV document. The document won't be parsed
    # until a method asks for data. This may raise
    # `CSV::MalformedCSVError`.
    def data
      @data ||= CSV.parse(@document, @options)
    end

    # Return the sensor/station metadata value for a given key. If key
    # is nil, then a Hash of all the metadata is returned. Possible
    # keys:
    # * file_format
    # * station_name
    # * datalogger_model
    # * datalogger_serial_number
    # * datalogger_os_version
    # * datalogger_program_name
    # * datalogger_program_signature
    # * table_name
    #
    # Note: If a partial document is being used, then an Exception is
    # raised.
    def metadata(key = nil)
      if !is_full_document?
        raise Exception, "Cannot get metadata on a partial document"
      else
        @metadata ||= parse_metadata
        if !key.nil?
          @metadata[key]
        else
          @metadata
        end
      end
    end

    # Return an array of column headers. Each item will be a Hash with
    # the property name, units, and measurement type. Some of the values
    # *may* be blank.
    #
    # Note: If a partial document is being used, then an Exception is
    # raised.
    def headers
      if !is_full_document?
        raise Exception, "Cannot get headers on a partial document"
      else
        @headers ||= parse_headers
      end
    end

    # Return an array of rows with the observation data. This will be
    # similar to the Ruby CSV class `#read` method.
    def rows
      if is_full_document?
        data.slice(4..-1)
      else
        data
      end
    end

    private

    # Returns true if the document starts with "TOA5".
    def is_full_document?
      data[0][0] == "TOA5"
    end

    # Parse CSV column headers for datastreams, units
    #
    # Row 2:
    # 1. Timestamp
    # 2+ (Observed Property)
    # Row 3:
    # Unit or Data Type
    # Row 4:
    # Observation Type (peak value, average value)
    def parse_headers
      data[1].map.with_index do |col, index|
        {
          name:  col,
          units: data[2][index],
          type:  data[3][index]
        }
      end
    end

    def parse_metadata
      metadata_row = data[0]
      {
        file_format:                  metadata_row[0],
        station_name:                 metadata_row[1],
        datalogger_model:             metadata_row[2],
        datalogger_serial_number:     metadata_row[3],
        datalogger_os_version:        metadata_row[4],
        datalogger_program_name:      metadata_row[5],
        datalogger_program_signature: metadata_row[6],
        table_name:                   metadata_row[7]
      }
    end
  end
end
