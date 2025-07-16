class Video < ApplicationRecord
  validates :path, presence: true
end
