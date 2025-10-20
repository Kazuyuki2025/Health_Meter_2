class Video < ApplicationRecord
  has_one_attached :content
  validates :content, presence: { message: "を選択してください" }
  has_one_attached :thumbnail

  has_many :detections, dependent: :destroy
  has_many :performances, dependent: :destroy

  validates :title, presence: true

  enum :analysis_status, {
    pending: "pending",
    analyzing: "analyzing",
    completed: "completed",
    failed: "failed"
  }, validate: true

  def get_detected_ids
    # 既存のパフォーマンスから推測
    if performances.any?
      performances.pluck(:id)
    else
      # デフォルト値またはnil
      []
    end
  end

  def get_all_activities
    performances.includes(:performer, :activities).map do |performance|
      activities = performance.activities
      next if activities.blank?

      {
        performance_id: performance.id,
        performer: performance.performer,
        activities: activities,
        average: activities.map(&:value).sum.to_f / activities.size,
        total_segments: activities.size
      }
    end.compact
  end

  def calculate_overall_stats
    activity_data = get_all_activities
    return {} if activity_data.empty?

    all_activities = activity_data.flat_map { |data| data[:activities] }
    {
      total_performers: performances.size,
      total_segments: all_activities.size,
      overall_average: all_activities.map(&:value).sum.to_f / all_activities.size
    }
  end

  def assign_performer(detected_id, performer_id)
    return if performer_id.blank?
    Rails.logger.info "Assigning performer_id #{performer_id} to detected_id #{detected_id} in video #{id}"

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
