# lib/tasks/analyze_bbox.rake
namespace :video do
  desc "Analyze bounding box coordinates and sizes frame by frame"
  task analyze_bbox: :environment do
    video = Video.find(226)
    puts "=== Bounding Box分析 ==="
    puts "Video: #{video.title} (ID: #{video.id})"
    puts ""

    # 各person_idごとに分析
    person_ids = video.detections.distinct.pluck(:person_id).compact.sort

    person_ids.each do |person_id|
      puts "【Person ID: #{person_id}】"

      detections = video.detections.where(person_id: person_id)
                        .order(:frame_number)

      if detections.empty?
        puts "  検出データなし"
        next
      end

      puts "  総フレーム数: #{detections.count}"
      puts "  フレーム範囲: #{detections.first.frame_number} - #{detections.last.frame_number}"
      puts ""

      # 統計情報を計算
      bbox_data = detections.map do |d|
        width = (d.x2 - d.x1).abs
        height = (d.y2 - d.y1).abs
        center_x = (d.x1 + d.x2) / 2.0
        center_y = (d.y1 + d.y2) / 2.0
        area = width * height

        {
          frame: d.frame_number,
          x1: d.x1, y1: d.y1, x2: d.x2, y2: d.y2,
          width: width, height: height,
          center_x: center_x, center_y: center_y,
          area: area
        }
      end

      # 統計計算
      widths = bbox_data.map { |d| d[:width] }
      heights = bbox_data.map { |d| d[:height] }
      areas = bbox_data.map { |d| d[:area] }
      center_xs = bbox_data.map { |d| d[:center_x] }
      center_ys = bbox_data.map { |d| d[:center_y] }

      puts "  【サイズ統計】"
      puts "    幅: 平均=#{(widths.sum/widths.size).round(1)}px, 最小=#{widths.min.round(1)}px, 最大=#{widths.max.round(1)}px"
      puts "    高さ: 平均=#{(heights.sum/heights.size).round(1)}px, 最小=#{heights.min.round(1)}px, 最大=#{heights.max.round(1)}px"
      puts "    面積: 平均=#{(areas.sum/areas.size).round(0)}px², 最小=#{areas.min.round(0)}px², 最大=#{areas.max.round(0)}px²"
      puts ""

      puts "  【位置統計】"
      puts "    中心X: 平均=#{(center_xs.sum/center_xs.size).round(1)}px, 範囲=#{center_xs.min.round(1)}-#{center_xs.max.round(1)}px"
      puts "    中心Y: 平均=#{(center_ys.sum/center_ys.size).round(1)}px, 範囲=#{center_ys.min.round(1)}-#{center_ys.max.round(1)}px"
      puts ""

      # 最初の10フレームの詳細
      puts "  【最初の10フレーム詳細】"
      puts "    Frame | x1     | y1     | x2     | y2     | Width  | Height | Area"
      puts "    ------|--------|--------|--------|--------|--------|--------|--------"
      bbox_data.first(10).each do |data|
        printf "    %5d | %6.1f | %6.1f | %6.1f | %6.1f | %6.1f | %6.1f | %6.0f\n",
               data[:frame], data[:x1], data[:y1], data[:x2], data[:y2],
               data[:width], data[:height], data[:area]
      end

      if bbox_data.size > 10
        puts "    ... (#{bbox_data.size - 10}フレーム省略)"
      end
      puts ""

      # 変動の大きいフレームを特定
      width_changes = []
      height_changes = []

      (1...bbox_data.size).each do |i|
        width_change = (bbox_data[i][:width] - bbox_data[i-1][:width]).abs
        height_change = (bbox_data[i][:height] - bbox_data[i-1][:height]).abs

        width_changes << { frame: bbox_data[i][:frame], change: width_change }
        height_changes << { frame: bbox_data[i][:frame], change: height_change }
      end

      # 大きな変動（5%以上）を表示
      avg_width = widths.sum / widths.size
      avg_height = heights.sum / heights.size

      large_width_changes = width_changes.select { |wc| wc[:change] > avg_width * 0.05 }
      large_height_changes = height_changes.select { |hc| hc[:change] > avg_height * 0.05 }

      if large_width_changes.any?
        puts "  【大きな幅変動 (>5%)】"
        large_width_changes.first(5).each do |wc|
          puts "    フレーム #{wc[:frame]}: #{wc[:change].round(1)}px変動"
        end
        puts ""
      end

      if large_height_changes.any?
        puts "  【大きな高さ変動 (>5%)】"
        large_height_changes.first(5).each do |hc|
          puts "    フレーム #{hc[:frame]}: #{hc[:change].round(1)}px変動"
        end
        puts ""
      end

      puts "=" * 50
    end
  end

  desc "Export detailed bbox analysis to JSON"
  task export_bbox_analysis: :environment do
    video = Video.find(248)
    puts "Exporting detailed bbox analysis for video: #{video.title}"

    analysis_data = {
      video_id: video.id,
      video_name: video.title,
      analysis_timestamp: Time.current.iso8601,
      persons: []
    }

    person_ids = video.detections.distinct.pluck(:person_id).compact.sort

    person_ids.each do |person_id|
      detections = video.detections.where(person_id: person_id)
                        .order(:frame_number)

      next if detections.empty?

      # 各フレームのbbox詳細データ
      frame_data = detections.map do |d|
        width = (d.x2 - d.x1).abs
        height = (d.y2 - d.y1).abs
        center_x = (d.x1 + d.x2) / 2.0
        center_y = (d.y1 + d.y2) / 2.0
        area = width * height
        aspect_ratio = width / height if height > 0

        {
          frame_number: d.frame_number,
          coordinates: {
            x1: d.x1.round(2), y1: d.y1.round(2),
            x2: d.x2.round(2), y2: d.y2.round(2)
          },
          dimensions: {
            width: width.round(2),
            height: height.round(2),
            area: area.round(0),
            aspect_ratio: aspect_ratio&.round(3)
          },
          center: {
            x: center_x.round(2),
            y: center_y.round(2)
          },
          activity: d.activity
        }
      end

      # 統計情報
      widths = frame_data.map { |d| d[:dimensions][:width] }
      heights = frame_data.map { |d| d[:dimensions][:height] }
      areas = frame_data.map { |d| d[:dimensions][:area] }

      person_analysis = {
        person_id: person_id,
        total_frames: frame_data.size,
        frame_range: {
          start: frame_data.first[:frame_number],
          end: frame_data.last[:frame_number]
        },
        statistics: {
          width: {
            min: widths.min.round(2),
            max: widths.max.round(2),
            avg: (widths.sum / widths.size).round(2),
            std_dev: calculate_std_dev(widths).round(2)
          },
          height: {
            min: heights.min.round(2),
            max: heights.max.round(2),
            avg: (heights.sum / heights.size).round(2),
            std_dev: calculate_std_dev(heights).round(2)
          },
          area: {
            min: areas.min.round(0),
            max: areas.max.round(0),
            avg: (areas.sum / areas.size).round(0),
            std_dev: calculate_std_dev(areas).round(0)
          }
        },
        frame_data: frame_data
      }

      analysis_data[:persons] << person_analysis
    end

    # ファイル出力
    file_path = Rails.root.join("public", "bbox_analysis_video_#{video.id}.json")
    File.open(file_path, "w") do |f|
      f.write(JSON.pretty_generate(analysis_data))
    end

    puts "Export completed: #{file_path}"
    puts "Analysis includes #{analysis_data[:persons].size} persons"
    analysis_data[:persons].each do |person|
      puts "  Person #{person[:person_id]}: #{person[:total_frames]} frames"
    end
  end

  private

  def calculate_std_dev(values)
    return 0.0 if values.size < 2

    mean = values.sum.to_f / values.size
    variance = values.map { |v| (v - mean) ** 2 }.sum / values.size
    Math.sqrt(variance)
  end
end
