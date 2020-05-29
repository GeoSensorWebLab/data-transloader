require 'active_record'

module ARModels
  class Observation < ActiveRecord::Base
    belongs_to :station
  end
end
