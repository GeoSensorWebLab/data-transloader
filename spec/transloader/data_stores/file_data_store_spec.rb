require 'transloader'

require 'fileutils'
require 'json'
require 'rspec'
require 'time'

RSpec.describe Transloader::FileDataStore do
  before(:each) do
    reset_cache($cache_dir)
    @database_url = "file://#{$cache_dir}"
  end

  it "creates the storage path on initialization" do
    expect(Dir.exists?("#{$cache_dir}/test/unique")).to be false

    Transloader::FileDataStore.new(
      database_url: @database_url,
      provider_key: "test",
      station_key: "unique")

    expect(Dir.exists?("#{$cache_dir}/test/unique")).to be true
  end

  it "returns an empty set of observations if the cache is empty" do
    store = Transloader::FileDataStore.new(
      database_url: @database_url,
      provider_key: "test",
      station_key: "unique")

    expect(store.get_all_in_range(Time.new(2000), Time.now)).to be_empty
  end

  it "will store an empty set of observations" do
    store = Transloader::FileDataStore.new(
      database_url: @database_url,
      provider_key: "test",
      station_key: "unique")

    expect {
      store.store([])
    }.to_not raise_error
  end

  it "will store observations in the file cache" do
    store = Transloader::FileDataStore.new(
      database_url: @database_url,
      provider_key: "test",
      station_key: "unique")
    observation = {
      timestamp: Time.new(2000, 1, 1),
      result: 15,
      property: "air_temperature",
      unit: "degC"
    }
    store.store([observation])
    raw_data = JSON.parse(IO.read("#{$cache_dir}/test/unique/2000/01/01.json"))

    expect(raw_data["data"].keys.length).to be(1)
  end

  it "returns observations from the file cache" do
    store = Transloader::FileDataStore.new(
      database_url: @database_url,
      provider_key: "test",
      station_key: "unique")
    observation = {
      timestamp: Time.new(2000, 1, 1),
      result: 15,
      property: "air_temperature",
      unit: "degC"
    }
    store.store([observation])

    expect(store.get_all_in_range(Time.new(2000,1,1), Time.now)).to_not be_empty
  end
end
