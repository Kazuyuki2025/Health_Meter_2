class Video < ApplicationRecord
  has_one_attached :video_content
  has_one_attached :video_thumbnail
  has_many :performances, dependent: :destroy

  validates :title, presence: true

  enum :analysis_status, {
    pending: "pending",
    analyzing: "analyzing",
    completed: "completed",
    failed: "failed"
  }, validate: true

  def thumbnail_url
    return nil unless video_thumbnail.attached?
      Rails.application.routes.url_helpers.rails_blob_path(video_thumbnail, only_path: true)
  end
end
