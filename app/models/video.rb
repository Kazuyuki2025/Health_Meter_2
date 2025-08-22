class Video < ApplicationRecord
  has_one_attached :video_file

  validates :title, presence: true

  enum :analysis_status, {
    pending: "pending",
    analyzing: "analyzing",
    completed: "completed",
    failed: "failed"
  }, validate: true
end
