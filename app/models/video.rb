class Video < ApplicationRecord
  has_one_attached :video_file
  validates :title, presence: true
  validates :video_file, presence: true
  enum analysis_status: {
    pending: "pending",
    detected: "detected",
    completed: "completed",
    failed: "failed" }
end
