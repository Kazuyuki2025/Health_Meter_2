class Activity < ApplicationRecord
  belongs_to :performance

  validates :category, presence: true
  validates :value, presence: true, numericality: true
end
