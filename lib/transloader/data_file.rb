module Transloader
  # Class to serialize information about remote data files for use in
  # partial downloads. This is a class so that different providers will
  # use the same interface.
  class DataFile
    attr_reader :datafileindex, :datafilename, :data_url, :filename, :last_modified, :length

    def initialize(datafileindex: nil, datafilename: nil, url:, last_modified:, length:)
      @data_url      = url
      @datafileindex = datafileindex
      @datafilename  = datafilename
      @filename      = File.basename(url)
      @last_modified = last_modified
      @length        = length
    end

    def to_h
      {
        datafileindex:  @datafileindex,
        datafilename:   @datafilename,
        filename:       @filename,
        url:            @data_url,
        last_modified:  @last_modified,
        initial_length: @length
      }
    end

    def to_json(*a)
      to_h.to_json(*a)
    end
  end
end