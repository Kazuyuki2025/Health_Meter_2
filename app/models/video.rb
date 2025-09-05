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

  def assign_performer(detected_id, performer_id)
    return if performer_id.blank?

    performances.find_or_create_by(performer_id: performer_id) do |p|
      p.date = Date.current.to_s
    end
  end

  def attach_thumbnail_from_file(file_path)
    return unless File.exist?(file_path)

    thumbnail.attach(
      io: File.open(file_path),
      filename: File.basename(file_path),
      content_type: "image/jpeg"
    )

    FileUtils.rm_f(file_path)
    Rails.logger.info "Thumbnail attached and file removed: #{file_path}"
  rescue => e
    Rails.logger.error "Thumbnail attachment failed: #{e.message}"
    false
  end

  def thumbnail_url
    return nil unless thumbnail.attached?
      Rails.application.routes.url_helpers.rails_blob_path(thumbnail, only_path: true)
  end
end
