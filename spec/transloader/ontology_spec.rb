require 'transloader'
require 'rspec'

RSpec.describe Transloader::Ontology do

  it "returns an O&M Observation Type for a source property" do
    ontology = Transloader::Ontology.new(:EnvironmentCanada)
    type = ontology.observation_type("dwpt_temp")

    expect(type).to eq("http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement")
  end

  it "returns nil for an undefined O&M Observation Type for a source property" do
    ontology = Transloader::Ontology.new(:data_avail)
    type = ontology.observation_type("dwpt_temp")

    expect(type).to be_nil
  end

  it "returns an Observed Property for a source property" do
    ontology = Transloader::Ontology.new(:EnvironmentCanada)
    property = ontology.observed_property("dwpt_temp")

    expect(property[:name]).to eq("Dew Point Temperature")
    expect(property[:definition]).to eq("http://mmisw.org/ont/cf/parameter/dew_point_temperature")
  end

  # This test may need to be updated if "Ux_Avg" has a match added later
  it "returns nil for an unmatched Observed Property for a source property" do
    ontology = Transloader::Ontology.new(:CampbellScientific)
    property = ontology.observed_property("Ux_Avg")

    expect(property).to be_nil
  end

  it "returns a Unit of Measurement for a source property" do
    ontology = Transloader::Ontology.new(:EnvironmentCanada)
    unit = ontology.unit_of_measurement("dwpt_temp")

    expect(unit[:name]).to eq("degree Celsius")
    expect(unit[:definition]).to eq("http://purl.obolibrary.org/obo/UO_0000027")
  end

  # This test may need to be updated if "Ux_Avg" has a match added later
  it "returns nil for an unmatched Unit of Measurement for a source property" do
    ontology = Transloader::Ontology.new(:CampbellScientific)
    unit = ontology.unit_of_measurement("Ux_Avg")

    expect(unit).to be_nil
  end
end
