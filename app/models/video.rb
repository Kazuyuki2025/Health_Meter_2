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
    # Detectionテーブルから実際に検出されたperson_idを取得
    detections.distinct.pluck(:person_id).compact.sort
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

    person_id = detected_id.to_i
    Rails.logger.info "Assigning performer_id #{performer_id} to person_id #{person_id} in video #{id}"

    # person_idとperformer_idの両方を保存
    performance = performances.find_or_create_by(performer_id: performer_id) do |p|
      p.person_id = person_id
      p.date = Date.current.to_s
    end

    # 既存のperformanceの場合もperson_idを更新
    performance.update!(person_id: person_id) if performance.person_id != person_id

    # # 紐付け後、基準BBoxサイズを計算
    # calculate_reference_bbox_for_performance(performance)

    # performance
  end

  # # 特定のperformanceに対して基準BBoxサイズを計算
  # def calculate_reference_bbox_for_performance(performance)
  #   return unless performance.person_id

  #   Rails.logger.info "Performance #{performance.id} の基準BBox高さを計算中..."

  #   # このperson_idのDetectionデータを取得
  #   person_detections = detections.where(person_id: performance.person_id)
  #                                 .order(:frame_number)
  #                                 .limit(100)

  #   if person_detections.empty?
  #     Rails.logger.warn "Person #{performance.person_id} の検出データがありません"
  #     return
  #   end

  #   # BBox高さの平均を計算
  #   heights = person_detections.map { |d| d.y2 - d.y1 }
  #   avg_height = heights.sum / heights.size.to_f

  #   # performanceに常に保存（この動画でのBBox高さ）
  #   performance.update!(
  #     reference_bbox_height: avg_height,
  #     reference_bbox_updated_at: Time.current
  #   )

  #   Rails.logger.info "Performance #{performance.id}: BBox高さ=#{avg_height.round(2)} を保存"

  #   performer = performance.performer

  #   # performerに基準値がない場合のみ保存（初回のみ）
  #   if performer.reference_bbox_height.blank? || performer.reference_bbox_height <= 0
  #     performer.update!(reference_bbox_height: avg_height)
  #     Rails.logger.info "Performer #{performer.name}: 基準BBox高さ=#{avg_height.round(2)} を初回登録"
  #   else
  #     Rails.logger.info "Performer #{performer.name}: 既存の基準値=#{performer.reference_bbox_height.round(2)} を使用（更新なし）"
  #   end
  # end

  # # 全てのperformanceに対して基準BBoxサイズを再計算
  # def recalculate_all_reference_bboxes
  #   performances.each do |performance|
  #     next unless performance.person_id
  #     calculate_reference_bbox_for_performance(performance)
  #   end
  # end

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
