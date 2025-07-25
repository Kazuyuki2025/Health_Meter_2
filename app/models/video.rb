class Video < ApplicationRecord
  has_one_attached :video_file
  after_create_commit :analyze_first_frame
  validates :video_file, presence: true

  def analyze_first_frame
    ExtractFirstFrameJob.perform_later(id)
  end
end
