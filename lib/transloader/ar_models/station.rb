require "active_record"

module ARModels
  class Station < ActiveRecord::Base
    has_many :observations
  end
end
