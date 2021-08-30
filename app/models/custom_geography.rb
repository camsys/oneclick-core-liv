class CustomGeography < GeographyRecord
  validates_presence_of :name
  acts_as_geo_ingredient attributes: [:name]
  has_one :agency
end
