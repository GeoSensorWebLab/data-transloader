require 'transloader'

require 'fileutils'
require 'json'
require 'rspec'
require 'time'

RSpec.describe Transloader::FileMetadataStore do
  before(:each) do
    reset_cache($cache_dir)
    @database_url = "file://#{$cache_dir}"
  end

  it "creates the storage path on initialization" do
    expect(Dir.exists?("#{$cache_dir}/test/metadata")).to be false

    Transloader::FileMetadataStore.new(
      database_url: @database_url,
      provider_key: "test",
      station_key: "unique")

    expect(Dir.exists?("#{$cache_dir}/test/metadata")).to be true
  end

  it "returns empty metadata if the cache is empty" do
    store = Transloader::FileMetadataStore.new(
      database_url: @database_url,
      provider_key: "test",
      station_key: "unique")

    expect(store.metadata).to eq({})
  end

  it "will store metadata in the file cache" do
    store = Transloader::FileMetadataStore.new(
      database_url: @database_url,
      provider_key: "test",
      station_key: "unique")
    store.set("test", "value")
    raw_data = JSON.parse(IO.read("#{$cache_dir}/test/metadata/unique.json"))

    expect(raw_data["metadata"]["test"]).to eq("value")
  end

  it "returns metadata from the file cache" do
    store = Transloader::FileMetadataStore.new(
      database_url: @database_url,
      provider_key: "test",
      station_key: "unique")
    store.set("test", "value")

    expect(store.get("test")).to eq("value")
  end

  it "supports deep merging metadata attributes" do
    store = Transloader::FileMetadataStore.new(
      database_url: @database_url,
      provider_key: "test",
      station_key: "unique")
    store.set(:test, { test2: { test3: "1", test4: "2" } })
    store.merge({
      test: { test2: { test3: "5" } }
    })

    expect(store.metadata[:test][:test2][:test3]).to eq("5")
    expect(store.metadata[:test][:test2][:test4]).to eq("2")
  end
end
