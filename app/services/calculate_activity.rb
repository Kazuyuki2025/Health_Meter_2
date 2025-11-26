class CalculateActivity
  attr_reader :video, :num_segments, :force_no_normalization, :normalization_method

  def initialize(video, num_segments: 13, force_no_normalization: false, normalization_method: :height)
    @video = video
    @num_segments = num_segments
    @force_no_normalization = force_no_normalization
    @normalization_method = normalization_method  # :height or :area
  end

  def calculate_and_save!
    mode = if force_no_normalization
             "正規化なし（強制）"
    else
             "自動判定（正規化方法: #{normalization_method}）"
    end

    Rails.logger.info "活動量計算開始: video_id=#{video.id}, セグメント数=#{num_segments}, モード=#{mode}"

    video.performances.each do |performance|
      calculate_for_performance(performance)
    end

    Rails.logger.info "活動量計算完了"
  end

  private

  def calculate_for_performance(performance)
    unless performance.person_id
      Rails.logger.warn "Performance #{performance.id} に person_id がありません"
      return
    end

    detections = video.detections.where(person_id: performance.person_id).order(:frame_number)

    if detections.empty?
      Rails.logger.warn "Person #{performance.person_id} の検出データがありません"
      return
    end

    performer = performance.performer

    if force_no_normalization
      Rails.logger.info "演者 #{performer.name}: 正規化なし（強制モード）"
      calculate_without_normalization(performance, detections)
      return
    end

    reference_bbox_size = performer.reference_bbox_size

    if reference_bbox_size.blank? || reference_bbox_size <= 0
      Rails.logger.info "演者 #{performer.name}: 基準BBoxサイズなし（正規化なし）"
      calculate_without_normalization(performance, detections)
    else
      Rails.logger.info "演者 #{performer.name}: " \
                        "基準BBoxサイズ=#{reference_bbox_size.round(2)}（正規化方法: #{normalization_method}）"
      calculate_with_normalization(performance, detections, reference_bbox_size)
    end
  end

  def calculate_without_normalization(performance, detections)
    performance.activities.destroy_all
    segments = divide_into_segments(detections, num_segments)

    segments.each_with_index do |segment_detections, index|
      next if segment_detections.empty?

      avg_activity = calculate_raw_activity(segment_detections)

      Activity.create!(
        performance: performance,
        value: avg_activity,
        start_frame: segment_detections.first.frame_number,
        end_frame: segment_detections.last.frame_number
      )

      Rails.logger.info "  セグメント#{index + 1}: 活動量=#{avg_activity.round(2)}（正規化なし）"
    end
  end

  def calculate_with_normalization(performance, detections, reference_bbox_size)
    performance.activities.destroy_all
    segments = divide_into_segments(detections, num_segments)

    segments.each_with_index do |segment_detections, index|
      next if segment_detections.empty?

      normalized_activity = calculate_normalized_activity(
        segment_detections,
        reference_bbox_size,
        normalization_method
      )

      Activity.create!(
        performance: performance,
        value: normalized_activity,
        start_frame: segment_detections.first.frame_number,
        end_frame: segment_detections.last.frame_number
      )

      Rails.logger.info "  セグメント#{index + 1}: 活動量=#{normalized_activity.round(2)}（正規化済み: #{normalization_method}）"
    end
  end

  def divide_into_segments(detections, num_segments)
    total_frames = detections.count
    segment_size = (total_frames.to_f / num_segments).ceil

    num_segments.times.map do |i|
      start_idx = i * segment_size
      end_idx = [ (i + 1) * segment_size, total_frames ].min
      detections[start_idx...end_idx] || []
    end
  end

  def calculate_raw_activity(detections)
    return 0.0 if detections.count < 3

    total_evaluation = 0.0
    coordinate = [ 0, 0, 0, 0 ]
    velocity = [ 0, 0, 0, 0 ]
    pre_velocity = [ 0, 0, 0, 0 ]

    detections.each do |detection|
      x1, x2, y1, y2 = detection.x1, detection.x2, detection.y1, detection.y2

      vx1 = (x1 - coordinate[0]).abs
      vx2 = (x2 - coordinate[1]).abs
      vy1 = (y1 - coordinate[2]).abs
      vy2 = (y2 - coordinate[3]).abs

      velocity = [ vx1, vx2, vy1, vy2 ]

      evaluation = (velocity[0] - pre_velocity[0]).abs +
                   (velocity[1] - pre_velocity[1]).abs +
                   (velocity[2] - pre_velocity[2]).abs +
                   (velocity[3] - pre_velocity[3]).abs

      evaluation = 0.0 if evaluation > 100

      coordinate = [ x1, x2, y1, y2 ]
      pre_velocity = velocity

      total_evaluation += evaluation
    end

    detections.count > 0 ? total_evaluation / detections.count : 0.0
  end

  def calculate_normalized_activity(detections, reference_bbox_size, method = :height)
    return 0.0 if detections.count < 3

    total_normalized_evaluation = 0.0

    first = detections.first
    coordinate = [ first.x1, first.x2, first.y1, first.y2 ]
    pre_velocity = [ 0, 0, 0, 0 ]

    detections.each_with_index do |detection, i|
      next if i == 0

      x1, x2, y1, y2 = detection.x1, detection.x2, detection.y1, detection.y2

      # 速度
      vx1 = (x1 - coordinate[0]).abs
      vx2 = (x2 - coordinate[1]).abs
      vy1 = (y1 - coordinate[2]).abs
      vy2 = (y2 - coordinate[3]).abs
      velocity = [ vx1, vx2, vy1, vy2 ]

      # 加速度
      evaluation = (velocity[0] - pre_velocity[0]).abs +
                   (velocity[1] - pre_velocity[1]).abs +
                   (velocity[2] - pre_velocity[2]).abs +
                   (velocity[3] - pre_velocity[3]).abs

      evaluation = 0.0 if evaluation > 100

      # 正規化比率を計算（方法により異なる）
      size_ratio = case method
      when :height
                     calculate_height_ratio(x1, x2, y1, y2, reference_bbox_size)
      when :area
                     calculate_area_ratio(x1, x2, y1, y2, reference_bbox_size)
      else
                     1.0
      end

      normalized_evaluation = evaluation * size_ratio

      total_normalized_evaluation += normalized_evaluation

      # 更新
      coordinate = [ x1, x2, y1, y2 ]
      pre_velocity = velocity
    end

    total_normalized_evaluation / (detections.count - 1)
  end

  def calculate_height_ratio(x1, x2, y1, y2)
    reference_height = Math.sqrt(reference_bbox_size)

    current_height = [ (y2 - y1).abs, 1.0 ].max

    reference_height / current_height
  end

  def calculate_area_ratio(x1, x2, y1, y2, reference_bbox_size)
    current_area = [ (x2 - x1).abs * (y2 - y1).abs, 1.0 ].max

    Math.sqrt(reference_bbox_size / current_area)
  end
end
