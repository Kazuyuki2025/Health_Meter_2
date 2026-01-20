class CalculateActivity
  attr_reader :video, :num_segments

  def initialize(video, num_segments: 13)
    @video = video
    @num_segments = num_segments
  end

  def calculate_and_save!
    Rails.logger.info "活動量計算開始: video_id=#{video.id}, セグメント数=#{num_segments}"

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
    performer_height = performer.height

    if performer_height.blank? || performer_height <= 0
      Rails.logger.info "演者 #{performer.name}: 身長が登録されていません"
      return
    end

    Rails.logger.info "演者 #{performer.name} 身長 #{performer_height} 正規化して計算"
    calculate_with_normalization(performance, detections, performer_height)
  end

  # 方針:
  # - フレームごとのactivityを detections.activity に保存（BBox表示用）
  # - セグメントごとのactivityを activities.value に保存（集計/グラフ用）
  # - 計算は二重にせず、フレームごとの値からセグメント値(平均)を作る
  def calculate_with_normalization(performance, detections, performer_height)
    performance.activities.delete_all
    segments = divide_into_segments(detections.to_a, num_segments)

    segments.each_with_index do |segment_detections, index|
      next if segment_detections.empty?

      start_frame = segment_detections.first.frame_number
      end_frame   = segment_detections.last.frame_number

      # 1回だけ：フレームごとのactivityを計算
      frame_activity = calculate_framewise_activity_map(segment_detections, performer_height)

      # セグメント値：フレーム値の平均（先頭フレームは0.0固定なので除外）
      values_for_segment = frame_activity
                             .reject { |frame, _| frame == start_frame }
                             .values
                             .compact

      segment_activity = if values_for_segment.empty?
        0.0
      else
        values_for_segment.sum / values_for_segment.size
      end

      Activity.create!(
        performance: performance,
        value: segment_activity,
        start_frame: start_frame,
        end_frame: end_frame
      )

      # フレームごとの値を detections.activity に保存（BBox表示用）
      # ※まず動く版（11582件程度なら許容の可能性）。重い場合は upsert_all に最適化する。
      segment_detections.each do |d|
        v = frame_activity[d.frame_number]
        next if v.nil?
        d.update_columns(activity: v)
      end

      Rails.logger.info "  セグメント#{index + 1}: 活動量(avg)=#{segment_activity.round(2)}（framewise→segment平均）"
    end
  end

  # フレームごとの activity（cm/sec相当をscale_divisorで割った値）を作る
  # 戻り値: { frame_number(Integer) => activity(Float) }
  def calculate_framewise_activity_map(detections, performer_height)
    return {} if detections.count < 2

    # --- BBox高さの推定は冒頭5秒(150 frames)のみをキャリブレーションとして使用 ---
    calibration_frames = 150
    calibration_detections = detections.first(calibration_frames)

    heights = calibration_detections
                .map { |d| (d.y2 - d.y1).abs.to_f }
                .reject(&:zero?)
    return {} if heights.empty?

    bbox_height_px = heights.sort[heights.length / 2] # median
    min_bbox_height_px = 20.0
    bbox_height_px = [bbox_height_px, min_bbox_height_px].max

    cm_per_px = performer_height.to_f / bbox_height_px.to_f

    ema_alpha = 0.25
    deadband_cm = 0.8
    max_move_cm_per_frame = 30.0

    fps = 30.0
    scale_divisor = 3.0

    first = detections.first
    cx = (first.x1 + first.x2) / 2.0
    cy = (first.y1 + first.y2) / 2.0

    ema_cx = cx
    ema_cy = cy

    frame_to_activity = {}
    frame_to_activity[first.frame_number] = 0.0

    detections.each_with_index do |d, i|
      next if i == 0

      cx = (d.x1 + d.x2) / 2.0
      cy = (d.y1 + d.y2) / 2.0

      prev_ema_cx = ema_cx
      prev_ema_cy = ema_cy

      ema_cx = ema_alpha * cx + (1.0 - ema_alpha) * ema_cx
      ema_cy = ema_alpha * cy + (1.0 - ema_alpha) * ema_cy

      dx_cm = (ema_cx - prev_ema_cx).abs * cm_per_px
      dy_cm = (ema_cy - prev_ema_cy).abs * cm_per_px
      move_cm = dx_cm + dy_cm

      move_cm = 0.0 if move_cm < deadband_cm
      move_cm = [move_cm, max_move_cm_per_frame].min

      cm_per_sec = move_cm * fps
      activity_value = (cm_per_sec / scale_divisor)

      frame_to_activity[d.frame_number] = activity_value
    end

    frame_to_activity
  end

  def divide_into_segments(detections, num_segments)
    total = detections.size
    return [] if total == 0

    segment_size = (total.to_f / num_segments).ceil

    num_segments.times.map do |i|
      start_idx = i * segment_size
      end_idx = [ (i + 1) * segment_size, total ].min
      detections[start_idx...end_idx] || []
    end
  end

  # 旧: セグメント平均を直接計算する実装。
  # 現方針（フレームごとの値を採用）では二重計算になるため呼び出していないが、
  # 比較・検証用として残す。
  def calculate_normalized_activity(detections, performer_height)
    return 0.0 if detections.count < 3

    heights = detections.map { |d| (d.y2 - d.y1).abs.to_f }.reject(&:zero?)
    return 0.0 if heights.empty?

    bbox_height_px = heights.sort[heights.length / 2] # median
    min_bbox_height_px = 20.0
    bbox_height_px = [ bbox_height_px, min_bbox_height_px ].max

    cm_per_px = performer_height.to_f / bbox_height_px.to_f

    ema_alpha = 0.25
    deadband_cm = 1.0
    max_move_cm_per_frame = 10.0

    first = detections.first
    cx = (first.x1 + first.x2) / 2.0
    cy = (first.y1 + first.y2) / 2.0

    ema_cx = cx
    ema_cy = cy

    total = 0.0
    steps = 0

    detections.each_with_index do |d, i|
      next if i == 0

      cx = (d.x1 + d.x2) / 2.0
      cy = (d.y1 + d.y2) / 2.0

      prev_ema_cx = ema_cx
      prev_ema_cy = ema_cy

      ema_cx = ema_alpha * cx + (1.0 - ema_alpha) * ema_cx
      ema_cy = ema_alpha * cy + (1.0 - ema_alpha) * ema_cy

      dx_cm = (ema_cx - prev_ema_cx).abs * cm_per_px
      dy_cm = (ema_cy - prev_ema_cy).abs * cm_per_px
      move_cm = dx_cm + dy_cm

      move_cm = 0.0 if move_cm < deadband_cm
      move_cm = [ move_cm, max_move_cm_per_frame ].min

      total += move_cm
      steps += 1
    end

    avg_cm_per_frame = steps > 0 ? (total / steps) : 0.0

    fps = 30.0
    cm_per_sec = avg_cm_per_frame * fps # cm/sec

    scale_divisor = 3.0
    (cm_per_sec / scale_divisor)
  end
end
