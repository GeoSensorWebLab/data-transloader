require 'transloader'

require 'rspec'

RSpec.describe Transloader::TimeInterval do
  it "parses a valid time interval without error" do
    expect {
      Transloader::TimeInterval.new("2007-03-01T13:00:00Z/2008-05-11T15:30:00Z")
    }.to_not raise_error
  end

  it "raises an error if the interval is malformed" do
    expect {
      Transloader::TimeInterval.new("2007-03-01T13:00:00Z")
    }.to raise_error(Transloader::TimeInterval::InvalidIntervalFormat)
  end

  it "raises an error if one of the dates is malformed" do
    expect {
      Transloader::TimeInterval.new("2007-00-01T13:00:00Z/2008-05-11T15:30:00Z")
    }.to raise_error(ArgumentError)
  end

  it "raises an error if the end date is before the start date" do
    expect {
      Transloader::TimeInterval.new("2017-03-01T13:00:00Z/2008-05-11T15:30:00Z")
    }.to raise_error(Transloader::TimeInterval::InvalidIntervalFormat)
  end

  it "Returns Time objects" do
    interval = Transloader::TimeInterval.new("2007-03-01T13:00:00Z/2008-05-11T15:30:00Z")
    expect(interval.start).to be_a(Time)
    expect(interval.end).to be_a(Time)
  end

  it "Correctly parses into the correct Times" do
    interval = Transloader::TimeInterval.new("2007-03-01T13:00:00Z/2008-05-11T15:30:00Z")
    expect(interval.start.iso8601).to eq("2007-03-01T13:00:00Z")
    expect(interval.end.iso8601).to eq("2008-05-11T15:30:00Z")
  end
end
