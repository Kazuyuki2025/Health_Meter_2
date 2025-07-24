class Video < ApplicationRecord
  validates :path, presence: true
  has_one_attached :file
end
