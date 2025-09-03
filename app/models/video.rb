class Video < ApplicationRecord
  has_one_attached :content
  has_one_attached :thumbnail

  has_many :performances, dependent: :destroy

  validates :title, presence: true

  enum :analysis_status, {
    pending: "pending",
    analyzing: "analyzing",
    completed: "completed",
    failed: "failed"
  }, validate: true

  def get_all_activities
    performances.includes(:activities, :performer).map do |performance|
      {
        performer: performance.performer,
        activities: performance.activities.order(:category),
        average: performance.average_activity
      }
    end
  end

  def thumbnail_url
    return nil unless thumbnail.attached?
      Rails.application.routes.url_helpers.rails_blob_path(thumbnail, only_path: true)
  end
end
