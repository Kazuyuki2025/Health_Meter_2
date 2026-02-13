namespace :calculation do
  desc "Calculate detections quotient for two videos"
  task detections_quotient: :environment do
    video = Video.find(248)

    # デバッグ情報を追加
    puts "=== デバッグ情報 ==="
    puts "Video ID: #{video.id}"
    puts "Video title: #{video.title}"
    puts "Detections count: #{video.detections.count}"
    puts "Performances count: #{video.performances.count}"

    video.performances.each do |performance|
      puts "Performance #{performance.id}:"
      puts "  person_id: #{performance.person_id}"
      puts "  performer: #{performance.performer&.name}"
      puts "  performer height: #{performance.performer&.height}"
      puts "  detections for this person: #{video.detections.where(person_id: performance.person_id).count}"

      # 詳細なデバッグ情報を追加
      detections = video.detections.where(person_id: performance.person_id).order(:frame_number)
      puts "  最初のdetection: #{detections.first&.attributes}"
      puts "  最後のdetection: #{detections.last&.attributes}"
      puts "  frame_number範囲: #{detections.minimum(:frame_number)} - #{detections.maximum(:frame_number)}"
    end
    puts "==================="

    # Rails.logger をコンソール出力に変更
    original_logger = Rails.logger
    Rails.logger = Logger.new(STDOUT)
    Rails.logger.level = Logger::INFO

    puts "元の座標での活動量計算..."
    original_service = CalculateActivity.new(video)
    original_service.calculate_and_save!

    # データベースをリロードしてから記録
    video.reload
    original_activities = {}
    video.performances.each do |performance|
      performance.reload
      activities_values = performance.activities.pluck(:value)
      original_activities[performance.id] = activities_values
      puts "Performance #{performance.id} - 元の活動量データ数: #{activities_values.size}"
      puts "  Activities in DB: #{Activity.where(performance_id: performance.id).count}"
    end

    puts "座標を2倍に変更中..."
    video.detections.find_each do |detection|
      detection.update!(
        x1: detection.x1 / 2,
        x2: detection.x2 / 2,
        y1: detection.y1 / 2,
        y2: detection.y2 / 2
      )
    end

    puts "2倍座標での活動量計算..."
    doubled_service = CalculateActivity.new(video)
    doubled_service.calculate_and_save!

    # Rails.logger を元に戻す
    Rails.logger = original_logger

    # データベースをリロードしてから比較
    video.reload
    puts "\n活動量比較結果:"
    video.performances.each do |performance|
      performance.reload
      original_values = original_activities[performance.id]
      doubled_values = performance.activities.pluck(:value)

      puts "Performance #{performance.id} (person_id: #{performance.person_id}):"
      puts "  演者: #{performance.performer&.name}"
      puts "  元の値数: #{original_values.size}, 2倍後数: #{doubled_values.size}"
      puts "  Activities in DB after double: #{Activity.where(performance_id: performance.id).count}"
      puts "  元の値: #{original_values.map { |v| v.round(2) }}" if original_values.any?
      puts "  2倍後:  #{doubled_values.map { |v| v.round(2) }}" if doubled_values.any?
      puts "  元の平均: #{original_values.any? ? (original_values.sum / original_values.size).round(2) : "N/A"}"
      puts "  2倍後の平均: #{doubled_values.any? ? (doubled_values.sum / doubled_values.size).round(2) : "N/A"}"

      if original_values.any? && doubled_values.any?
        ratios = doubled_values.zip(original_values).map { |d, o| o != 0 ? (d / o).round(2) : "N/A" }
        puts "  比率:   #{ratios}"
      else
        puts "  ⚠️  活動量データがありません"
      end
      puts ""
    end

    # 座標を元に戻す
    puts "座標を元に戻しています..."
    video.detections.find_each do |detection|
      detection.update!(
        x1: detection.x1 * 2,
        x2: detection.x2 * 2,
        y1: detection.y1 * 2,
        y2: detection.y2 * 2
      )
    end

    puts "完了！"
  end
end
