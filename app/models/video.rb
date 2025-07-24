class Video < ApplicationRecord
  has_one_attached :video_file
  validates :video_file, presence: true
end
